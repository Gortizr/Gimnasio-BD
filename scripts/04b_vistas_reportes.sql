/* =====================================================================
   04b_vistas_reportes.sql
   Vistas del esquema reportes que exponen a Power BI las tres
   consultas de 04_consultas.sql, con el rango completo
   '19000101'-'29990101'.

   Requiere: 03_seguridad.sql (crea el esquema reportes y da SELECT
   sobre él a rol_reportes) y 04_consultas.sql (crea las funciones).
   Las vistas y las funciones tienen el mismo dueño (dbo), por lo que
   login_powerbi puede leer las vistas sin permiso sobre dbo.
   Se puede ejecutar varias veces (CREATE OR ALTER).
   ===================================================================== */
USE GimnasioDB;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 50071, N'Falta el esquema reportes: ejecutar primero 03_seguridad.sql.', 1;
IF OBJECT_ID(N'dbo.fn_Consulta1_OcupacionSesiones') IS NULL
    THROW 50072, N'Faltan las funciones: ejecutar primero 04_consultas.sql.', 1;
GO

CREATE OR ALTER VIEW reportes.vw_Consulta1_OcupacionSesiones
AS
SELECT *
FROM dbo.fn_Consulta1_OcupacionSesiones('19000101', '29990101');
GO

CREATE OR ALTER VIEW reportes.vw_Consulta2_IngresosMensuales
AS
SELECT *
FROM dbo.fn_Consulta2_IngresosMensuales('19000101', '29990101');
GO

CREATE OR ALTER VIEW reportes.vw_Consulta3_RankingSocios
AS
SELECT *
FROM dbo.fn_Consulta3_RankingSocios('19000101', '29990101');
GO

/* Verificación */
SELECT N'vw_Consulta1_OcupacionSesiones' AS vista, COUNT(*) AS filas
FROM reportes.vw_Consulta1_OcupacionSesiones
UNION ALL
SELECT N'vw_Consulta2_IngresosMensuales', COUNT(*)
FROM reportes.vw_Consulta2_IngresosMensuales
UNION ALL
SELECT N'vw_Consulta3_RankingSocios', COUNT(*)
FROM reportes.vw_Consulta3_RankingSocios;
GO
