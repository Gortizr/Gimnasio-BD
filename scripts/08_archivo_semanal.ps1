
# ============================================================
# PROYECTO: GIMNASIODB
# SCRIPT 08: ARCHIVADO SEMANAL DE BACKUPS
# ============================================================
#
# OBJETIVO:
# Mover los backups FULL (.bak) y LOG (.trn) de semanas
# anteriores a carpetas organizadas dentro de historico.
#
# EJECUCION:
# Todos los lunes mediante el Programador de tareas.
#
# IMPORTANTE:
# - No elimina backups.
# - No modifica la base de datos.
# - No modifica los jobs FULL ni LOG.
# - No sobrescribe archivos del historial.
# - Utiliza Docker y el usuario mssql.
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1. CONFIGURACION DEL CONTENEDOR
# ------------------------------------------------------------

$Contenedor = "sqlserver-2025"

$Origen = "/backup/GimnasioDB"

$Historico = "/backup/GimnasioDB/historico"

# true  = solo simular el archivado
# false = mover los archivos realmente
$SoloSimulacion = $false


# ------------------------------------------------------------
# 2. CALCULAR EL LUNES DE LA SEMANA ACTUAL
# ------------------------------------------------------------

$Hoy = (Get-Date).Date

$DiasDesdeLunes = ([int]$Hoy.DayOfWeek + 6) % 7

$LunesActual = $Hoy.AddDays(-$DiasDesdeLunes)

Write-Host "======================================"
Write-Host "ARCHIVADO SEMANAL - GIMNASIODB"
Write-Host "======================================"
Write-Host "Fecha actual: $Hoy"
Write-Host "Inicio de semana: $LunesActual"


# ------------------------------------------------------------
# 3. CONSULTAR LOS BACKUPS EXISTENTES
# ------------------------------------------------------------

$Archivos = @(
    docker exec -u mssql $Contenedor ls -1 $Origen
)

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: No se pudieron consultar los backups."
}

$Cantidad = 0
$Movidos = 0


# ------------------------------------------------------------
# 4. IDENTIFICAR BACKUPS DE SEMANAS ANTERIORES
# ------------------------------------------------------------

foreach ($Archivo in $Archivos) {

    $Archivo = $Archivo.Trim()

    # Solo procesar backups FULL y LOG del gimnasio
    if ($Archivo -notmatch '^GimnasioDB_(FULL|LOG)_(\d{8})_\d{6}_\d{3}\.(bak|trn)$') {
        continue
    }

    # Obtener la fecha incluida en el nombre
    $FechaArchivo = [datetime]::ParseExact(
        $Matches[2],
        "yyyyMMdd",
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    # No mover backups de la semana actual
    if ($FechaArchivo -ge $LunesActual) {
        continue
    }

    # Determinar el lunes correspondiente al backup
    $Dias = ([int]$FechaArchivo.DayOfWeek + 6) % 7

    $InicioSemana = $FechaArchivo.AddDays(-$Dias)

    # Nombre de la carpeta de destino
    $Semana = "Semana_" + $InicioSemana.ToString("yyyy-MM-dd")

    $Destino = "$Historico/$Semana"

    $Cantidad++


    # --------------------------------------------------------
    # 5. MODO SIMULACION
    # --------------------------------------------------------

    if ($SoloSimulacion) {

        Write-Host "SIMULACION: $Archivo"
        Write-Host "Destino: $Destino"

        continue
    }


    # --------------------------------------------------------
    # 6. CREAR CARPETA DE LA SEMANA
    # --------------------------------------------------------

    docker exec -u mssql $Contenedor mkdir -p $Destino

    if ($LASTEXITCODE -ne 0) {
        throw "ERROR: No se pudo crear $Destino"
    }


    # --------------------------------------------------------
    # 7. EVITAR SOBRESCRIBIR BACKUPS EXISTENTES
    # --------------------------------------------------------

    docker exec -u mssql $Contenedor test -e "$Destino/$Archivo"

    if ($LASTEXITCODE -eq 0) {

        Write-Warning "Ya existe en historico: $Archivo"

        continue
    }


    # --------------------------------------------------------
    # 8. MOVER EL BACKUP AL HISTORICO
    # --------------------------------------------------------

    docker exec -u mssql $Contenedor mv -n -- "$Origen/$Archivo" "$Destino/$Archivo"

    if ($LASTEXITCODE -ne 0) {
        throw "ERROR: No se pudo archivar $Archivo"
    }

    Write-Host "ARCHIVADO: $Archivo"

    $Movidos++
}


# ------------------------------------------------------------
# 9. MOSTRAR RESULTADOS
# ------------------------------------------------------------

Write-Host "======================================"
Write-Host "RESUMEN DEL ARCHIVADO"
Write-Host "======================================"

Write-Host "Backups identificados: $Cantidad"

if ($SoloSimulacion) {

    Write-Host "MODO SIMULACION ACTIVADO"
    Write-Host "No se movio ningun respaldo."

}
else {

    Write-Host "Backups movidos: $Movidos"
    Write-Host "Archivado semanal finalizado."

}

Write-Host "======================================"


#ejecutar en powershell desde la carpeta de scripts del proyecto:
#.\08_archivo_semanal.ps1


