/* =====================================================================
   06b_probar_jobs_y_monitoreo.sql

   Pruebas y monitoreo de los respaldos de GimnasioDB.

   La seccion A ejecuta una prueba manual del job diferencial.
   Las demas secciones consultan historial, antiguedad, continuidad
   y existencia fisica de los archivos de respaldo.
   ===================================================================== */

USE msdb;
GO

/* === A) PRUEBA MANUAL DEL JOB DIFERENCIAL ===========================
   Inicia el job, espera el resultado y confirma que se registro un
   nuevo respaldo diferencial en msdb.dbo.backupset.                   */
SET NOCOUNT ON;

DECLARE @job SYSNAME = N'GimnasioDB - Respaldo Diferencial';
DECLARE @id UNIQUEIDENTIFIER =
    (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @job);

IF @id IS NULL
    THROW 50060, N'No existe el job diferencial. Ejecute primero 06_jobs_respaldo.sql.', 1;

DECLARE @ultimo INT =
    ISNULL((SELECT MAX(instance_id)
            FROM msdb.dbo.sysjobhistory
            WHERE job_id = @id), 0);

DECLARE @t0 DATETIME = GETDATE();
DECLARE @estado INT = NULL;
DECLARE @seg INT = 0;
DECLARE @espera_max_seg INT = 900;

EXEC msdb.dbo.sp_start_job @job_name = @job;

WHILE @estado IS NULL AND @seg < @espera_max_seg
BEGIN
    WAITFOR DELAY '00:00:02';
    SET @seg += 2;

    SELECT TOP (1)
        @estado = run_status
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = @id
      AND step_id = 0
      AND instance_id > @ultimo
    ORDER BY instance_id DESC;
END;

IF @estado IS NULL
    THROW 50061, N'Tiempo maximo agotado sin resultado del job diferencial.', 1;

IF @estado <> 1
    THROW 50062, N'El job diferencial termino con error. Revise la seccion B.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.backupset
    WHERE database_name = N'GimnasioDB'
      AND type = 'I'
      AND backup_finish_date >= @t0
)
    THROW 50063, N'El job termino correctamente, pero no se encontro un diferencial nuevo.', 1;

PRINT CONCAT(N'OK: job diferencial ejecutado correctamente (', @seg, N' s de espera).');
GO

/* === B) HISTORIAL DE LOS JOBS ===================================== */
SELECT
    j.name AS job,
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS inicio,
    CASE h.run_status
        WHEN 0 THEN N'FALLO'
        WHEN 1 THEN N'Correcto'
        WHEN 2 THEN N'Reintento'
        WHEN 3 THEN N'Cancelado'
        WHEN 4 THEN N'En curso'
    END AS resultado,
    h.run_duration AS duracion_hhmmss,
    h.message
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobhistory AS h
    ON h.job_id = j.job_id
WHERE j.name IN (
    N'GimnasioDB_Backup_FULL',
    N'GimnasioDB_Backup_LOG',
    N'GimnasioDB - Respaldo Diferencial'
)
  AND h.step_id = 0
ORDER BY inicio DESC;
GO

/* === C) RESPALDOS REGISTRADOS ====================================== */
SELECT
    bs.backup_start_date,
    bs.backup_finish_date,
    CASE bs.type
        WHEN 'D' THEN N'Full'
        WHEN 'I' THEN N'Diferencial'
        WHEN 'L' THEN N'Log'
    END AS tipo,
    bs.is_copy_only,
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS segundos,
    CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS tamano_mb,
    bs.has_backup_checksums AS con_checksum,
    bmf.physical_device_name AS archivo
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS bmf
    ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type IN ('D','I','L')
ORDER BY bs.backup_start_date DESC;
GO

/* === D) MONITOREO DE ANTIGUEDAD ====================================
   Umbrales de control:
     - Full:        26 horas
     - Diferencial: 26 horas
     - Log:         20 minutos (RPO objetivo 15 min + 5 min tolerancia)

   Los FULL COPY_ONLY no cuentan para este monitoreo.                  */
SELECT
    r.requisito,
    u.ultimo_respaldo,
    DATEDIFF(MINUTE, u.ultimo_respaldo, SYSDATETIME()) AS minutos_desde_ultimo,
    r.limite_min,
    CASE
        WHEN u.ultimo_respaldo IS NULL THEN N'ALERTA: nunca existio'
        WHEN DATEDIFF(MINUTE, u.ultimo_respaldo, SYSDATETIME()) > r.limite_min
            THEN N'ALERTA: atrasado'
        ELSE N'OK'
    END AS estado
FROM (VALUES
        (N'Full',        'D', 1560),
        (N'Diferencial', 'I', 1560),
        (N'Log',         'L', 20)
     ) AS r (requisito, tipo, limite_min)
OUTER APPLY (
    SELECT MAX(bs.backup_finish_date) AS ultimo_respaldo
    FROM msdb.dbo.backupset AS bs
    WHERE bs.database_name = N'GimnasioDB'
      AND bs.type = r.tipo
      AND (r.tipo <> 'D' OR bs.is_copy_only = 0)
) AS u;
GO

/* === E) CONTINUIDAD DE LA CADENA DE LOGS =========================== */
WITH Logs AS (
    SELECT
        bs.backup_set_id,
        bs.backup_finish_date,
        bs.first_lsn,
        bs.last_lsn,
        LAG(bs.last_lsn) OVER (
            ORDER BY bs.backup_finish_date, bs.backup_set_id
        ) AS last_lsn_anterior
    FROM msdb.dbo.backupset AS bs
    WHERE bs.database_name = N'GimnasioDB'
      AND bs.type = 'L'
)
SELECT
    backup_finish_date,
    first_lsn,
    last_lsn,
    last_lsn_anterior,
    CASE
        WHEN last_lsn_anterior IS NULL THEN N'Primero'
        WHEN first_lsn = last_lsn_anterior THEN N'Continuo'
        ELSE N'REVISAR'
    END AS continuidad
FROM Logs
ORDER BY backup_finish_date DESC, backup_set_id DESC;
GO

/* === F) EXISTENCIA FISICA DE LOS ULTIMOS 30 RESPALDOS ============== */
SELECT TOP (30)
    CASE bs.type
        WHEN 'D' THEN N'Full'
        WHEN 'I' THEN N'Diferencial'
        WHEN 'L' THEN N'Log'
    END AS tipo,
    bs.backup_finish_date AS fecha,
    bmf.physical_device_name AS archivo,
    CASE
        WHEN f.file_exists = 1 THEN N'Existe en disco'
        ELSE N'NO ENCONTRADO'
    END AS estado_archivo
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS bmf
    ON bmf.media_set_id = bs.media_set_id
OUTER APPLY sys.dm_os_file_exists(bmf.physical_device_name) AS f
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type IN ('D','I','L')
  AND bmf.device_type = 2
ORDER BY bs.backup_finish_date DESC, bs.backup_set_id DESC;
GO
