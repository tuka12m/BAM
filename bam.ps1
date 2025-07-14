#  
.SYNOPSIS  
  Lista la información de uso (BAM) junto con la firma digital del ejecutable  
  y muestra la fechahora en UTC y en la hora local del equipo.  

.NOTAS  
  ▸ Ejecuta esta consola como Administrador (BAM está bajo HKLM).  
  ▸ Probado en Windows 1011.  
#

function Convert-FileTime {
    param(
        [byte[]]$Bytes
    )
    # FileTime → Int64 (little‑endian)
    $ticks = [System.BitConverter]ToInt64($Bytes, 0)
    # 100 ns  ticks desde 1601‑01‑01 → DateTime
    return [DateTime]FromFileTimeUtc($ticks)
}

$bamRoot = 'HKLMSYSTEMCurrentControlSetServicesbamUserSettings'

Get-ChildItem -Path $bamRoot -ErrorAction Stop  ForEach-Object {
    $sidPath = $_.PsPath
    $values  = Get-ItemProperty -LiteralPath $sidPath

    # Cada valor (excepto “Version”) representa un EXE
    foreach ($property in $values.PSObject.Properties) {
        if ($property.Name -eq 'Version') { continue }

        $raw = $property.Value -as [byte[]]
        if (-not $raw) { continue }

        # En Windows 1011, los últimos 8 bytes contienen el último TimeStamp en FILETIME
        $timeBytes = $raw[-8..-1]
        $utc       = Convert-FileTime $timeBytes
        $local     = $utc.ToLocalTime()

        # El nombre del valor suele ser la ruta del EXE (puede estar en binarioUTF‑16)
        $exePath = try   { [System.Text.Encoding]Unicode.GetString([byte[]]$property.Name) }
                   catch { $property.Name }  # Ya estaba en texto

        # Saca la firma digital (si la ruta existe)
        $sigResult = if (Test-Path $exePath) {
            (Get-AuthenticodeSignature -FilePath $exePath).Status
        } else { 'Ruta no encontrada' }

        [PSCustomObject]@{
            Application = [IO.Path]GetFileName($exePath)
            Path        = $exePath
            TimeUTC     = $utc.ToString('yyyy-MM-dd HHmmss')
            TimeLocal   = $local.ToString('yyyy-MM-dd HHmmss')
            Signature   = $sigResult
        }
    }
}  Sort-Object TimeUTC -Descending  Format-Table -AutoSize
