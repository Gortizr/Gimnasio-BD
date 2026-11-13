USE [msdb]
GO

/****** Objeto: Job [GimnasioDB_Backup_FULL] Fecha de script: 12/11/2026 09:29:01 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Objeto: JobCategory [[Uncategorized (Local)]] Fecha de script: 12/11/2026 09:29:01 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'GimnasioDB_Backup_FULL', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Respaldo completo diario de GimnasioDB con fecha y hora. Aviso por correo en caso de fallo.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Operador_Gym', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Objeto: Step [Crear respaldo FULL] Fecha de script: 12/11/2026 09:29:01 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Crear respaldo FULL', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @ahora DATETIMEOFFSET =
SYSDATETIMEOFFSET()
   
 AT TIME ZONE ''Central America Standard Time'';

DECLARE @marca NVARCHAR(30) =
   
CONVERT(CHAR(8), @ahora, 112)
    
+ N''_''
   
 + REPLACE(CONVERT(CHAR(8), @ahora, 108), 
N'':'', N'''')
    
+ N''_''
    
+ RIGHT(
 
 N''000'' + CONVERT(
            
NVARCHAR(3),
            
DATEPART(MILLISECOND, @ahora)
        
),
       
 3
    
);

DECLARE @archivo NVARCHAR(4000) =
   
 N''/backup/GimnasioDB/GimnasioDB_FULL_''
    
+ @marca
    
+ N''.bak'';



BACKUP DATABASE GimnasioDB

TO DISK = @archivo

WITH
    
COMPRESSION,
    
CHECKSUM,
    
STATS = 10;



RESTORE VERIFYONLY

FROM DISK = @archivo

WITH CHECKSUM;



PRINT N''Respaldo generado: '' + @archivo;

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'FULL_Diario_22h_SV', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20261111, 
		@active_end_date=99991231, 
		@active_start_time=40000, 
		@active_end_time=235959, 
		@schedule_uid=N'f7995316-5473-4154-9a50-892252535d8c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

