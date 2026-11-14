# 07_archivar_respaldos.ps1
# Archivado diario de respaldos antiguos
# Mueve respaldos .bak y .trn con mas de 7 dias desde la carpeta activa
# hacia la carpeta de archivo. No elimina respaldos y no sobrescribe archivos.

$Contenedor = "sqlserver-2025"
$Origen = "/backup/GimnasioDB"
$Destino = "/backup/GimnasioDB_Archivo"
$Dias = 7
$Minutos = $Dias * 24 * 60

Write-Host "=== Archivado de respaldos GimnasioDB ==="
Write-Host "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Origen: $Origen"
Write-Host "Destino: $Destino"
Write-Host "Antiguedad minima: $Dias dias"
Write-Host ""

docker exec $Contenedor bash -lc "mkdir -p '$Destino' && find '$Origen' -maxdepth 1 -type f \( -name '*.bak' -o -name '*.trn' \) -mmin +$Minutos -print -exec mv -n {} '$Destino/' \;"

if ($LASTEXITCODE -ne 0) {
    Write-Error "El archivado termino con error. Codigo: $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Archivado finalizado correctamente."
