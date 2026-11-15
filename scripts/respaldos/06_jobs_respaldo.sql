/* =====================================================================
   06_jobs_respaldo.sql

   Crea o actualiza el job de respaldo diferencial de GimnasioDB.

   Configuracion:
     - Ruta: /backup/GimnasioDB/
     - Frecuencia: diaria
     - Hora: 16:07
     - CHECKSUM + COMPRESSION
     - RESTORE VERIFYONLY despues del respaldo

   Si el job ya existe, se actualiza el paso sin eliminar su historial.
   ===================================================================== */

USE msdb;
GO
SET NOCOUNT ON;

DECLARE @ruta NVARCHAR(200) = N'/backup/GimnasioDB/';
DECLARE @bd SYSNAME = N'GimnasioDB';
DECLARE @job SYSNAME = N'GimnasioDB - Respaldo Diferencial';

IF DB_ID(@bd) IS NULL
    THROW 50050, N'No existe GimnasioDB.', 1;

IF (SELECT recovery_model_desc
    FROM sys.databases
    WHERE name = @bd) <> N'FULL'
    THROW 50051, N'GimnasioDB debe estar en modelo de recuperacion FULL.', 1;

BEGIN TRY
    EXEC master.dbo.xp_create_subdir @ruta;
END TRY
BEGIN CATCH
    PRINT N'AVISO: no se pudo crear/verificar la carpeta: ' + @ruta;
END CATCH;

DECLARE @cmd NVARCHAR(MAX) = N'
IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.backupset
    WHERE database_name = N''GimnasioDB''
      AND type = ''D''
      AND is_copy_only = 0
)
    THROW 50010,
        N''No existe un respaldo FULL no COPY_ONLY que sirva como base.'',
        1;

DECLARE @archivo NVARCHAR(400) =
    N''' + @ruta + N'GimnasioDB_DIFF_''
    + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
    + N''_''
    + REPLACE(CONVERT(NVARCHAR(8), SYSDATETIME(), 108), N'':'', N'''')
    + N''.bak'';

IF EXISTS (
    SELECT 1
    FROM sys.dm_os_file_exists(@archivo)
    WHERE file_exists = 1
)
    THROW 50061, N''Respaldo cancelado: el archivo ya existe.'', 1;

BACKUP DATABASE [GimnasioDB]
TO DISK = @archivo
WITH DIFFERENTIAL,
     CHECKSUM,
     COMPRESSION,
     INIT,
     STATS = 25,
     NAME = N''GimnasioDB - Diferencial'';

RESTORE VERIFYONLY
FROM DISK = @archivo
WITH CHECKSUM;

PRINT N''Respaldo diferencial generado y verificado: '' + @archivo;
';

IF EXISTS (
    SELECT 1
    FROM msdb.dbo.sysjobs
    WHERE name = @job
)
BEGIN
    EXEC msdb.dbo.sp_update_jobstep
         @job_name = @job,
         @step_id = 1,
         @command = @cmd;

    PRINT N'El job ya existia: se actualizo el paso y se conservo su historial y horario.';
END
ELSE
BEGIN
    EXEC msdb.dbo.sp_add_job
         @job_name = @job,
         @enabled = 1,
         @description = N'Respaldo diferencial diario de GimnasioDB con CHECKSUM y VERIFYONLY.';

    EXEC msdb.dbo.sp_add_jobstep
         @job_name = @job,
         @step_name = N'Backup Diferencial + verificar',
         @subsystem = N'TSQL',
         @database_name = N'master',
         @command = @cmd,
         @on_success_action = 1,
         @on_fail_action = 2;

    EXEC msdb.dbo.sp_add_jobschedule
         @job_name = @job,
         @name = N'Diario 16:07',
         @freq_type = 4,
         @freq_interval = 1,
         @freq_subday_type = 1,
         @freq_subday_interval = 0,
         @active_start_time = 160700;

    EXEC msdb.dbo.sp_add_jobserver
         @job_name = @job,
         @server_name = N'(local)';

    PRINT N'Creado: ' + @job;
END;
GO

SELECT
    j.name AS job,
    j.enabled,
    s.name AS horario,
    s.active_start_time
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysjobschedules AS js
    ON js.job_id = j.job_id
LEFT JOIN msdb.dbo.sysschedules AS s
    ON s.schedule_id = js.schedule_id
WHERE j.name = N'GimnasioDB - Respaldo Diferencial';
GO
