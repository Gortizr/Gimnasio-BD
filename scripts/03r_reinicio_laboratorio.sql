/* =====================================================================
   GimnasioDB - 03r_reinicio_laboratorio.sql
   SOLO PARA LABORATORIO. No forma parte de la ejecución normal.

   Borra los objetos de seguridad creados por 03_seguridad.sql
   para volver a empezar de cero:
   - SE PIERDE el historial de auditoría (auditoria.CambioPago).
   - Se borran usuarios, roles y el login de Power BI.
   - Los esquemas reportes y auditoria solo se borran si quedaron
     vacíos. Si otro integrante creó objetos ahí, se avisa y no se borran.

   Después de ejecutarlo, volver a ejecutar 03_seguridad.sql.
   ===================================================================== */

USE GimnasioDB;
GO

/* PASO 1. Trigger, vistas propias y tabla de auditoría. */

DROP TRIGGER IF EXISTS dbo.TR_Pago_Auditoria;
DROP VIEW IF EXISTS reportes.vw_OcupacionSesion;
DROP VIEW IF EXISTS reportes.vw_SaldoMembresia;
DROP TABLE IF EXISTS auditoria.CambioPago;
GO

/* PASO 2. Sacar a TODOS los miembros de los roles del proyecto,
   incluso usuarios agregados por otros integrantes.
   Un rol con miembros no se puede borrar; sin este paso el
   reinicio podría quedar a medias. */

DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += N'ALTER ROLE ' + QUOTENAME(r.name)
             + N' DROP MEMBER ' + QUOTENAME(m.name) + N';' + CHAR(10)
FROM sys.database_role_members AS rm
INNER JOIN sys.database_principals AS r
    ON r.principal_id = rm.role_principal_id
INNER JOIN sys.database_principals AS m
    ON m.principal_id = rm.member_principal_id
WHERE r.name IN (N'rol_administrador', N'rol_recepcion',
                 N'rol_entrenador', N'rol_reportes');

IF LEN(@sql) > 0
    EXEC sys.sp_executesql @sql;
GO

/* PASO 3. Usuarios, roles y login. */

DROP USER IF EXISTS usuario_admin;
DROP USER IF EXISTS usuario_recepcion;
DROP USER IF EXISTS usuario_entrenador;
DROP USER IF EXISTS usuario_reportes;
DROP USER IF EXISTS usuario_powerbi;

DROP ROLE IF EXISTS rol_administrador;
DROP ROLE IF EXISTS rol_recepcion;
DROP ROLE IF EXISTS rol_entrenador;
DROP ROLE IF EXISTS rol_reportes;

-- Si Power BI está conectado con este login, cerrar Power BI antes.
IF SUSER_ID(N'login_powerbi') IS NOT NULL
    DROP LOGIN login_powerbi;
GO

/* PASO 4. Esquemas: solo si están vacíos. */

IF SCHEMA_ID(N'reportes') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'reportes'))
        PRINT N'AVISO: el esquema reportes tiene objetos de otros integrantes; no se borra.';
    ELSE
        EXEC (N'DROP SCHEMA reportes;');
END;

IF SCHEMA_ID(N'auditoria') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'auditoria'))
        PRINT N'AVISO: el esquema auditoria tiene otros objetos; no se borra.';
    ELSE
        EXEC (N'DROP SCHEMA auditoria;');
END;
GO

/* PASO 5. Comprobar qué quedó. Lo normal es que no salga ninguna fila. */

SELECT name AS principal_que_quedo, type_desc
FROM sys.database_principals
WHERE name LIKE N'usuario[_]%' OR name LIKE N'rol[_]%';
GO
