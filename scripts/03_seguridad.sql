/* =====================================================================
   GimnasioDB - 03_seguridad.sql
   Seguridad: esquemas, roles, usuarios, permisos, auditoría
   y cálculo del tamaño de la base por tabla.

   Requisito: haber ejecutado antes 01_crear_tablas.sql
   y 02_datos_prueba.sql.

   Este script se puede ejecutar varias veces sin perder nada:
   - crea solo los objetos que todavía no existen;
   - actualiza vistas y trigger con CREATE OR ALTER;
   - NO borra el historial de auditoría, ni usuarios, ni roles,
     ni vistas creadas por otros integrantes en el esquema reportes.
   Para empezar de cero en laboratorio existe un script aparte:
   03r_reinicio_laboratorio.sql.

   ANTES DE EJECUTAR: cambiar la contraseña del login de Power BI
   en la sección 5.2. No subir la contraseña real al repositorio.
   ===================================================================== */

USE GimnasioDB;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 1. ESQUEMAS
   dbo       -> tablas de operación del gimnasio (ya existen).
   reportes  -> vistas de solo lectura para Power BI.
   auditoria -> registro de cambios en pagos.
   CREATE SCHEMA debe ir solo en su bloque; por eso, para poder
   preguntar antes si ya existe, se ejecuta dentro de EXEC.
   --------------------------------------------------------------------- */

IF SCHEMA_ID(N'reportes') IS NULL
    EXEC (N'CREATE SCHEMA reportes AUTHORIZATION dbo;');

IF SCHEMA_ID(N'auditoria') IS NULL
    EXEC (N'CREATE SCHEMA auditoria AUTHORIZATION dbo;');
GO

/* ---------------------------------------------------------------------
   SECCIÓN 2. AUDITORÍA DE PAGOS
   2.1 Tabla del historial. Solo se crea si no existe, así que
       volver a ejecutar el script conserva todas sus filas.
   Alcance: registra INSERT, UPDATE y DELETE sobre dbo.Pago, pero
   los valores antes/después que conserva son solo monto y estado.
   Un intento rechazado por permisos no queda registrado aquí:
   el trigger solo se dispara cuando el cambio sí ocurre.
   --------------------------------------------------------------------- */

IF OBJECT_ID(N'auditoria.CambioPago', N'U') IS NULL
BEGIN
    CREATE TABLE auditoria.CambioPago (
        id_cambio INT IDENTITY(1,1) NOT NULL,
        id_pago INT NOT NULL,
        accion NVARCHAR(10) NOT NULL,
        monto_anterior DECIMAL(10,2) NULL,
        monto_nuevo DECIMAL(10,2) NULL,
        estado_anterior NVARCHAR(10) NULL,
        estado_nuevo NVARCHAR(10) NULL,
        usuario_bd NVARCHAR(128) NOT NULL
            CONSTRAINT DF_CambioPago_Usuario DEFAULT (USER_NAME()),
        fecha_cambio DATETIME2(0) NOT NULL
            CONSTRAINT DF_CambioPago_Fecha DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_CambioPago
            PRIMARY KEY (id_cambio),

        CONSTRAINT CK_CambioPago_Accion
            CHECK (accion IN (N'INSERT', N'UPDATE', N'DELETE'))
    );
END;
GO

/* 2.2 Trigger sobre dbo.Pago.
   CREATE OR ALTER: si ya existe, solo lo actualiza; no toca datos.
   No cambia columnas ni datos de dbo.Pago: copia cada cambio
   a auditoria.CambioPago. Funciona con varias filas a la vez.
   - inserted: filas nuevas (INSERT) o valores nuevos (UPDATE).
   - deleted:  filas borradas (DELETE) o valores anteriores (UPDATE).
   - Si hay fila en ambas, fue UPDATE; solo en inserted, INSERT;
     solo en deleted, DELETE.
   USER_NAME() guarda el usuario de la base que hizo el cambio. */

CREATE OR ALTER TRIGGER dbo.TR_Pago_Auditoria
ON dbo.Pago
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.CambioPago (
        id_pago,
        accion,
        monto_anterior,
        monto_nuevo,
        estado_anterior,
        estado_nuevo,
        usuario_bd
    )
    SELECT
        COALESCE(i.id_pago, d.id_pago),
        CASE
            WHEN i.id_pago IS NOT NULL AND d.id_pago IS NOT NULL THEN N'UPDATE'
            WHEN i.id_pago IS NOT NULL THEN N'INSERT'
            ELSE N'DELETE'
        END,
        d.monto,
        i.monto,
        d.estado,
        i.estado,
        USER_NAME()
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d
        ON i.id_pago = d.id_pago;
END;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 3. VISTAS PARA REPORTES
   Power BI y el rol de reportes leen estas vistas, no las tablas.
   Como las vistas y las tablas tienen el mismo dueño (dbo),
   quien tiene permiso sobre la vista puede leerla sin tener
   permiso sobre las tablas de dbo.
   CREATE OR ALTER: si la vista ya existe, solo se actualiza.
   Otros integrantes pueden agregar sus propias vistas en reportes;
   este script no las borra.
   --------------------------------------------------------------------- */

-- Ocupación de cada sesión: reservas confirmadas y cupos libres.
CREATE OR ALTER VIEW reportes.vw_OcupacionSesion
AS
SELECT
    sc.id_sesion,
    c.nombre AS clase,
    CONCAT(e.nombre, N' ', e.apellido) AS entrenador,
    sc.inicio,
    sc.estado AS estado_sesion,
    sc.cupo_maximo,
    SUM(CASE WHEN r.estado = N'confirmada' THEN 1 ELSE 0 END) AS reservas_confirmadas,
    sc.cupo_maximo
        - SUM(CASE WHEN r.estado = N'confirmada' THEN 1 ELSE 0 END) AS cupos_libres
FROM dbo.SesionClase AS sc
INNER JOIN dbo.Clase AS c
    ON c.id_clase = sc.id_clase
INNER JOIN dbo.Entrenador AS e
    ON e.id_entrenador = sc.id_entrenador
LEFT JOIN dbo.Reserva AS r
    ON r.id_sesion = sc.id_sesion
GROUP BY sc.id_sesion, c.nombre, e.nombre, e.apellido,
         sc.inicio, sc.estado, sc.cupo_maximo;
GO

-- Saldo de cada membresía: precio acordado menos pagos aplicados.
-- No muestra documento, teléfono ni email del socio.
CREATE OR ALTER VIEW reportes.vw_SaldoMembresia
AS
SELECT
    m.id_membresia,
    CONCAT(s.nombre, N' ', s.apellido) AS socio,
    p.nombre AS nombre_plan,
    m.estado AS estado_membresia,
    m.precio_acordado,
    SUM(CASE WHEN pg.estado = N'aplicado' THEN pg.monto ELSE 0 END) AS total_pagado,
    m.precio_acordado
        - SUM(CASE WHEN pg.estado = N'aplicado' THEN pg.monto ELSE 0 END) AS saldo_pendiente
FROM dbo.MembresiaSocio AS m
INNER JOIN dbo.Socio AS s
    ON s.id_socio = m.id_socio
INNER JOIN dbo.PlanMembresia AS p
    ON p.id_plan = m.id_plan
LEFT JOIN dbo.Pago AS pg
    ON pg.id_membresia = m.id_membresia
GROUP BY m.id_membresia, s.nombre, s.apellido, p.nombre,
         m.estado, m.precio_acordado;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 4. ROLES Y PERMISOS
   Los permisos se dan a los roles, nunca directo a los usuarios.
   GRANT = da permiso. DENY = lo prohíbe y gana sobre los GRANT
   de los roles. REVOKE = quita un GRANT o DENY dado antes.
   Excepciones de DENY: no limita a sa, a sysadmin, al usuario dbo
   ni a db_owner; y no se revisa cuando una vista o un trigger usa
   tablas del mismo dueño (por eso el trigger sí escribe en auditoria).
   Repetir un GRANT o DENY que ya existe no da error ni lo duplica.
   --------------------------------------------------------------------- */

IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL
    CREATE ROLE rol_administrador AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_recepcion') IS NULL
    CREATE ROLE rol_recepcion AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_entrenador') IS NULL
    CREATE ROLE rol_entrenador AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_reportes') IS NULL
    CREATE ROLE rol_reportes AUTHORIZATION dbo;
GO

/* 4.1 Administrador de la aplicación
   Maneja todos los datos de dbo y puede leer reportes y auditoría.
   No puede escribir en la auditoría. Ningún rol de la aplicación
   puede hacerlo; solo el administrador del servidor (sa / dbo). */

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_administrador;
GRANT SELECT ON SCHEMA::reportes TO rol_administrador;
GRANT SELECT ON SCHEMA::auditoria TO rol_administrador;
DENY INSERT, UPDATE, DELETE ON SCHEMA::auditoria TO rol_administrador;
GO

/* 4.2 Recepción
   Registra socios, membresías, reservas y pagos.
   Consulta el catálogo (planes, clases, sesiones, entrenadores).
   No borra: un pago se anula cambiando su estado, no se elimina.
   El DENY impide borrar aunque otro rol de la aplicación le diera DELETE. */

GRANT SELECT, INSERT, UPDATE ON dbo.Socio TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON dbo.MembresiaSocio TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON dbo.Reserva TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON dbo.Pago TO rol_recepcion;

GRANT SELECT ON dbo.PlanMembresia TO rol_recepcion;
GRANT SELECT ON dbo.Clase TO rol_recepcion;
GRANT SELECT ON dbo.SesionClase TO rol_recepcion;
GRANT SELECT ON dbo.Entrenador TO rol_recepcion;

DENY DELETE ON SCHEMA::dbo TO rol_recepcion;
GO

/* 4.3 Entrenador
   Lee TODAS las clases, sesiones y reservas (no solo las suyas).
   Del socio solo ve id, nombre y apellido (no documento, teléfono ni email).
   Puede cambiar la columna estado de CUALQUIER sesión.
   Limitarlo a sus propias sesiones requeriría seguridad por filas,
   que no se incluye en este proyecto.
   Tiene prohibido ver pagos. */

GRANT SELECT ON dbo.Clase TO rol_entrenador;
GRANT SELECT ON dbo.SesionClase TO rol_entrenador;
GRANT SELECT ON dbo.Reserva TO rol_entrenador;
GRANT SELECT ON dbo.Socio (id_socio, nombre, apellido) TO rol_entrenador;
GRANT UPDATE ON dbo.SesionClase (estado) TO rol_entrenador;

DENY SELECT ON dbo.Pago TO rol_entrenador;
GO

/* 4.4 Reportes (Power BI)
   SELECT sobre todo el esquema reportes: incluye las vistas actuales
   y las que otros integrantes agreguen después en ese esquema,
   sin tener que dar permisos nuevos. No tiene acceso a dbo. */

GRANT SELECT ON SCHEMA::reportes TO rol_reportes;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 5. USUARIOS
   5.1 Usuarios de prueba WITHOUT LOGIN: existen solo dentro de
       GimnasioDB, sin contraseña. Se usan con EXECUTE AS USER (03b).
       No pueden conectarse desde otro programa.
   --------------------------------------------------------------------- */

IF DATABASE_PRINCIPAL_ID(N'usuario_admin') IS NULL
    CREATE USER usuario_admin WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
IF DATABASE_PRINCIPAL_ID(N'usuario_recepcion') IS NULL
    CREATE USER usuario_recepcion WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
IF DATABASE_PRINCIPAL_ID(N'usuario_entrenador') IS NULL
    CREATE USER usuario_entrenador WITHOUT LOGIN WITH DEFAULT_SCHEMA = dbo;
IF DATABASE_PRINCIPAL_ID(N'usuario_reportes') IS NULL
    CREATE USER usuario_reportes WITHOUT LOGIN WITH DEFAULT_SCHEMA = reportes;
GO

/* 5.2 Identidad real para Power BI.
   Power BI no puede usar un usuario WITHOUT LOGIN, así que se crea
   un login con contraseña (autenticación de SQL Server) y su usuario
   en GimnasioDB, miembro SOLO de rol_reportes: sin db_owner y sin
   acceso a dbo. Así Power BI no se conecta como sa.
   Requiere que el servidor acepte autenticación de SQL Server
   (modo mixto), que es como se conecta el equipo con sa.
   CAMBIAR la contraseña antes de ejecutar. */

IF CONVERT(INT, SERVERPROPERTY('IsIntegratedSecurityOnly')) = 1
    PRINT N'AVISO: el servidor solo acepta Windows Authentication; el login de Power BI no podrá iniciar sesión.';

IF SUSER_ID(N'login_powerbi') IS NULL
    CREATE LOGIN login_powerbi
        WITH PASSWORD = N'Cambiar_Esta_Clave_2026!',
             DEFAULT_DATABASE = GimnasioDB,
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;
GO

IF DATABASE_PRINCIPAL_ID(N'usuario_powerbi') IS NULL
    CREATE USER usuario_powerbi FOR LOGIN login_powerbi WITH DEFAULT_SCHEMA = reportes;
GO

/* 5.3 Cada usuario entra a un solo rol.
   Solo se agrega si todavía no es miembro. */

IF ISNULL(IS_ROLEMEMBER(N'rol_administrador', N'usuario_admin'), 0) = 0
    ALTER ROLE rol_administrador ADD MEMBER usuario_admin;
IF ISNULL(IS_ROLEMEMBER(N'rol_recepcion', N'usuario_recepcion'), 0) = 0
    ALTER ROLE rol_recepcion ADD MEMBER usuario_recepcion;
IF ISNULL(IS_ROLEMEMBER(N'rol_entrenador', N'usuario_entrenador'), 0) = 0
    ALTER ROLE rol_entrenador ADD MEMBER usuario_entrenador;
IF ISNULL(IS_ROLEMEMBER(N'rol_reportes', N'usuario_reportes'), 0) = 0
    ALTER ROLE rol_reportes ADD MEMBER usuario_reportes;
IF ISNULL(IS_ROLEMEMBER(N'rol_reportes', N'usuario_powerbi'), 0) = 0
    ALTER ROLE rol_reportes ADD MEMBER usuario_powerbi;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 6. VERIFICACIÓN (evidencia para el informe)
   6.1 Todos los roles de cada usuario del proyecto.
       usuario_powerbi debe aparecer solo en rol_reportes (sin db_owner).
   --------------------------------------------------------------------- */

SELECT
    u.name AS usuario,
    u.type_desc AS tipo_usuario,
    r.name AS rol
FROM sys.database_role_members AS rm
INNER JOIN sys.database_principals AS r
    ON r.principal_id = rm.role_principal_id
INNER JOIN sys.database_principals AS u
    ON u.principal_id = rm.member_principal_id
WHERE u.name LIKE N'usuario[_]%'
ORDER BY u.name, r.name;
GO

/* 6.2 Permisos de cada rol (base de la matriz de la diapositiva 3).
   tipo = GRANT o DENY; sobre = esquema, tabla o columna. */

SELECT
    pr.name AS rol,
    pe.state_desc AS tipo,
    pe.permission_name AS permiso,
    CASE pe.class
        WHEN 3 THEN N'ESQUEMA ' + SCHEMA_NAME(pe.major_id)
        ELSE OBJECT_SCHEMA_NAME(pe.major_id) + N'.' + OBJECT_NAME(pe.major_id)
    END AS sobre,
    COL_NAME(pe.major_id, pe.minor_id) AS columna
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr
    ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE N'rol[_]%'
ORDER BY pr.name, sobre, pe.permission_name;
GO

/* 6.3 Filas guardadas en la auditoría.
   Al volver a ejecutar este script, el número no debe bajar. */

SELECT COUNT(*) AS filas_auditoria
FROM auditoria.CambioPago;
GO

/* ---------------------------------------------------------------------
   SECCIÓN 7. TAMAÑO DE LA BASE POR TABLA (para el informe)
   7.1 Tamaño actual: filas y KB usados por datos e índices.
       Con estos datos de prueba cada tabla ocupa muy poco
       (en esta instalación se observaron 16 KB de datos por tabla);
       no es una regla fija. Por eso se hace la proyección de 7.2.
   --------------------------------------------------------------------- */

SELECT
    t.name AS tabla,
    SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.row_count ELSE 0 END) AS filas,
    SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.used_page_count ELSE 0 END) * 8 AS kb_datos,
    SUM(CASE WHEN ps.index_id > 1 THEN ps.used_page_count ELSE 0 END) * 8 AS kb_indices,
    SUM(ps.used_page_count) * 8 AS kb_total
FROM sys.dm_db_partition_stats AS ps
INNER JOIN sys.tables AS t
    ON t.object_id = ps.object_id
WHERE SCHEMA_NAME(t.schema_id) IN (N'dbo', N'auditoria')
GROUP BY t.name
ORDER BY kb_total DESC;
GO

/* 7.2 Proyección de crecimiento (estimación con supuestos).
   Supuesto 1: bytes máximos por fila = suma del tamaño de sus columnas
               + 11 bytes aproximados de control interno por fila.
   Supuesto 2: filas en un año (ajustables): 500 socios, 30 sesiones
               por semana (1,560 al año), 15 reservas por sesión,
               6 membresías por socio al año, unos 4,000 pagos,
               1 cambio auditado por pago.
   Paso 3: KB = filas x bytes por fila / 1024.
   Supuesto 4: índices = 30 % extra (factor 1.3). Debe contrastarse
               con los índices finales del script 04.
   Paso 5: a 3 años se multiplica por 3 (mismo ritmo cada año).
   No incluye log de transacciones, respaldos ni espacio libre.
   Es conservadora: supone los textos llenos al máximo. */

WITH TamanoFila AS (
    SELECT
        t.name AS tabla,
        SUM(c.max_length) + 11 AS bytes_por_fila
    FROM sys.tables AS t
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE SCHEMA_NAME(t.schema_id) IN (N'dbo', N'auditoria')
    GROUP BY t.name
),
FilasEstimadas AS (
    SELECT tabla, filas_anio
    FROM (
        VALUES
            (N'Socio', 500),
            (N'Entrenador', 15),
            (N'Clase', 15),
            (N'PlanMembresia', 5),
            (N'SesionClase', 1560),
            (N'Reserva', 23400),
            (N'MembresiaSocio', 3000),
            (N'Pago', 4000),
            (N'CambioPago', 4000)
    ) AS v (tabla, filas_anio)
)
SELECT
    tf.tabla,
    tf.bytes_por_fila,
    fe.filas_anio,
    CAST(fe.filas_anio * tf.bytes_por_fila / 1024.0 AS DECIMAL(12,2)) AS kb_datos_anio1,
    CAST(fe.filas_anio * tf.bytes_por_fila / 1024.0 * 1.3 AS DECIMAL(12,2)) AS kb_con_indices_anio1,
    CAST(fe.filas_anio * tf.bytes_por_fila / 1024.0 * 1.3 * 3 AS DECIMAL(12,2)) AS kb_con_indices_anio3
FROM TamanoFila AS tf
INNER JOIN FilasEstimadas AS fe
    ON fe.tabla = tf.tabla
ORDER BY kb_con_indices_anio1 DESC;
GO
