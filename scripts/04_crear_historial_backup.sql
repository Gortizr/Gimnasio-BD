
--desde powerShell
--crear la carpeta para guardar los backups automaticos
docker exec -u mssql sqlserver-2025 mkdir -p /backup/GimnasioDB


--crear la carpeta hisstorial, al finalizar la semana todo los
--FULL Y LOG backups se trasladaran para esta carpeta
docker exec -u mssql sqlserver-2025 mkdir -p /backup/GimnasioDB/historico
