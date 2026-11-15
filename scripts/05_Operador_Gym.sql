USE [msdb]
GO

/****** Objeto: Operator [Operador_Gym] Fecha de script: 14/11/2026 00:13:35 ******/
EXEC msdb.dbo.sp_add_operator @name=N'Operador_Gym', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'encargado@gym.test', 
		@category_name=N'[Uncategorized]'
GO

