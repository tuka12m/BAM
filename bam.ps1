<#
.SYNOPSIS
  Lista la información de uso (BAM) junto con la firma digital del ejecutable
  y muestra la fecha/hora en UTC y en la hora local del equipo.

.NOTES
  • Ejecutar como Administrador (BAM está bajo HKLM).
  • Probado en Windows 10/11.
#>

function Convert-FileTime {
    param(
        [byte[]] $Bytes
    )
    # FILETIME (little‑endian) → Int64 → DateTime (UTC)
    $ticks = [System.BitConverter]::ToInt64($Bytes, 0)
    return [DateTime]::FromFileTimeUtc($ticks)
}

$bamRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings'

Get-ChildItem -Path $bamRoot -ErrorAction Stop | ForEach-Object {
    $sidPath = $_.PsPath
    $values  = Get-ItemProperty -LiteralPath $sidPath

    # Cada valor (excepto “Version”) representa un EXE
    foreach ($property in $values.PSObject.Properties) {
        if ($property.Name -eq 'Version') { continue }

        $raw = $property.Value -as [byte[]]
        if (-not $raw) { continue }

        # En Windows 10/11 los últimos 8 bytes son FILETIME
        $timeBytes = $raw[-8..-1]
        $utc       = Convert-FileTime $timeBytes
        $local     = $utc.ToLocalTime()

                # Nombre del valor → ruta del EXE (puede venir en UTF‑16)
        $exePath = try   { [System.Text.Encoding]::Unicode.GetString([byte[]]$property.Name) }
                   catch { $property.Name }

        # Firma digital
        $sigResult = if (Test-Path $exePath) {
            (Get-AuthenticodeSignature -FilePath $exePath).Status
        } else { 'Ruta no encontrada' }

        [PSCustomObject]@{
            Application = [IO.Path]::GetFileName($exePath)
            Path        = $exePath
            TimeUTC     = $utc.ToString('yyyy-MM-dd HH:mm:ss')
            TimeLocal   = $local.ToString('yyyy-MM-dd HH:mm:ss')
            Signature   = $sigResult
        }
    }
} | Sort-Object TimeUTC -Descending | Format-Table -AutoSize
