<#
.SYNOPSIS
  Lista la información de uso (BAM) junto con la firma digital del ejecutable
  y muestra la fecha/hora en UTC y en la hora local del equipo.

.NOTES
  • Ejecutar como Administrador (BAM está bajo HKLM).
  • Compatible con Windows 10/11.
#>

function Convert-FileTime {
    param([byte[]] $Bytes)
    $ticks = [System.BitConverter]::ToInt64($Bytes, 0)
    return [DateTime]::FromFileTimeUtc($ticks)
}

# Rutas posibles según la versión de Windows
$possiblePaths = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings',
    'HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings'
)

$bamRoot = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $bamRoot) {
    Write-Warning '❌ No se encontró ninguna clave BAM UserSettings en el registro.'
    return
}

Get-ChildItem -Path $bamRoot -ErrorAction Stop | ForEach-Object {
    $sidPath = $_.PsPath
    $values  = Get-ItemProperty -LiteralPath $sidPath

    foreach ($property in $values.PSObject.Properties) {
        if ($property.Name -eq 'Version') { continue }

        $raw = $property.Value -as [byte[]]
        if (-not $raw) { continue }

        $timeBytes = $raw[-8..-1]
        $utc       = Convert-FileTime $timeBytes
        $local     = $utc.ToLocalTime()

        $exePath = try   { [System.Text.Encoding]::Unicode.GetString([byte[]]$property.Name) }
                   catch { $property.Name }

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

