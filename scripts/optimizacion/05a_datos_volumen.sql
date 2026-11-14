/* =====================================================================
   05a_datos_volumen.sql
   Crea una BASE DESECHABLE (GimnasioDB_Perf) como copia de GimnasioDB y
   le carga volumen: 20,000 socios, 4,000 sesiones, 400,000 reservas,
   20,000 membresias y 60,000 pagos. NO modifica GimnasioDB.

   Por que una base aparte: la carga y su borrado dejarian filas en la
   auditoria de pagos, agotarian identidades y mezclarian datos de prueba
   con la base compartida. La base de prueba puede eliminarse manualmente
   cuando ya no se necesite.

   PASOS
     1) Ajustar @ruta_bak (carpeta existente donde escribe el servicio SQL).
     2) Ejecutar el LOTE 1 (crea la copia) y despues el LOTE 2 (carga).
   Copia con COPY_ONLY: no altera la cadena de respaldos ni la base
   diferencial de GimnasioDB.
   Requiere SQL Server 2025 de pruebas y espacio libre para la copia.
   ===================================================================== */

/* ============================ LOTE 1 ================================ */
USE master;
GO
SET NOCOUNT ON;

DECLARE @origen  SYSNAME = N'GimnasioDB';
DECLARE @destino SYSNAME = N'GimnasioDB_Perf';
DECLARE @ruta_bak NVARCHAR(260) = N'/var/opt/mssql/data/'; -- <-- AJUSTAR

IF DB_ID(@origen) IS NULL
    THROW 50001, N'No existe GimnasioDB.', 1;
IF DB_ID(@destino) IS NOT NULL
    THROW 50002, N'GimnasioDB_Perf ya existe. Elimínela manualmente o reutilícela.', 1;

DECLARE @datos NVARCHAR(260) = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultDataPath'));
DECLARE @logs  NVARCHAR(260) = CONVERT(NVARCHAR(260), SERVERPROPERTY('InstanceDefaultLogPath'));
IF @datos IS NULL OR @logs IS NULL
    THROW 50003, N'No se pudo leer la ruta de datos/log por defecto de la instancia.', 1;

DECLARE @n_dato INT, @n_log INT, @l_dato SYSNAME, @l_log SYSNAME;
SELECT @n_dato = SUM(CASE WHEN type = 0 THEN 1 ELSE 0 END),
       @n_log  = SUM(CASE WHEN type = 1 THEN 1 ELSE 0 END),
       @l_dato = MAX(CASE WHEN type = 0 THEN name END),
       @l_log  = MAX(CASE WHEN type = 1 THEN name END)
FROM sys.master_files
WHERE database_id = DB_ID(@origen);
IF @n_dato <> 1 OR @n_log <> 1
    THROW 50004, N'GimnasioDB tiene mas de un archivo de datos o de log; ajuste los MOVE a mano.', 1;

DECLARE @bak NVARCHAR(400) = @ruta_bak + N'GimnasioDB_PERF_COPYONLY.bak';
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'BACKUP DATABASE ' + QUOTENAME(@origen) + N' TO DISK = N''' + @bak
         + N''' WITH COPY_ONLY, COMPRESSION, CHECKSUM, INIT;';
EXEC (@sql);

SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@destino) + N' FROM DISK = N''' + @bak
         + N''' WITH MOVE N''' + @l_dato + N''' TO N''' + @datos + @destino + N'.mdf'', '
         + N'MOVE N''' + @l_log + N''' TO N''' + @logs + @destino + N'_log.ldf'', RECOVERY, STATS = 25;';
EXEC (@sql);

SET @sql = N'ALTER DATABASE ' + QUOTENAME(@destino) + N' SET RECOVERY SIMPLE;';
EXEC (@sql);

-- Marca que identifica la base como desechable (05b la exige)
EXEC GimnasioDB_Perf.sys.sp_addextendedproperty
     @name = N'proposito', @value = N'PRUEBA_RENDIMIENTO_DESECHABLE';

-- Si la copia trajo especificaciones de auditoria de base de datos, se
-- apagan en la copia para no escribir en la auditoria real.
BEGIN TRY
    DECLARE @apagar NVARCHAR(MAX) = N'USE GimnasioDB_Perf; DECLARE @s NVARCHAR(MAX) = N''''; '
        + N'SELECT @s += N''ALTER DATABASE AUDIT SPECIFICATION '' + QUOTENAME(name) + N'' WITH (STATE = OFF);'' '
        + N'FROM sys.database_audit_specifications; EXEC (@s);';
    EXEC (@apagar);
END TRY
BEGIN CATCH
    PRINT N'AVISO: revise manualmente las auditorias de GimnasioDB_Perf: ' + ERROR_MESSAGE();
END CATCH;

PRINT N'Copia creada: GimnasioDB_Perf. Siga con el LOTE 2.';
GO

/* ============================ LOTE 2 ================================ */
USE GimnasioDB_Perf;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Proteccion: solo corre en la base marcada como desechable
IF DB_NAME() <> N'GimnasioDB_Perf'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties
                  WHERE class = 0 AND name = N'proposito'
                    AND CONVERT(NVARCHAR(100), value) = N'PRUEBA_RENDIMIENTO_DESECHABLE')
    THROW 50010, N'Esta no es la base desechable GimnasioDB_Perf. No se carga nada.', 1;

IF EXISTS (SELECT 1 FROM dbo.Socio WHERE documento LIKE N'CARGA-%')
    THROW 50011, N'GimnasioDB_Perf ya tiene la carga. Elimine la base de prueba y empiece de nuevo.', 1;

DECLARE @base DATE = '20250101';

-- Catalogos REALES de la base (sin suponer ID 1..5)
SELECT ROW_NUMBER() OVER (ORDER BY id_clase) AS rn, id_clase INTO #clases
FROM dbo.Clase WHERE estado = N'activo';
SELECT ROW_NUMBER() OVER (ORDER BY id_entrenador) AS rn, id_entrenador INTO #entrenadores
FROM dbo.Entrenador WHERE estado = N'activo';
SELECT ROW_NUMBER() OVER (ORDER BY id_plan) AS rn, id_plan INTO #planes
FROM dbo.PlanMembresia WHERE estado = N'activo';

DECLARE @nc INT = (SELECT COUNT(*) FROM #clases);
DECLARE @ne INT = (SELECT COUNT(*) FROM #entrenadores);
DECLARE @np INT = (SELECT COUNT(*) FROM #planes);
IF @nc = 0 OR @ne = 0 OR @np = 0
    THROW 50012, N'Faltan clases, entrenadores o planes activos. Cargue datos_prueba.sql antes.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE #numeros (i INT NOT NULL PRIMARY KEY);
    INSERT INTO #numeros (i)
    SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b;

    -- 1) Socios: se guarda el ID realmente insertado (MERGE ... OUTPUT)
    CREATE TABLE #soc (i INT NOT NULL PRIMARY KEY, id_socio INT NOT NULL);
    MERGE dbo.Socio AS t
    USING (
        SELECT i,
               N'Carga' + CAST(i AS NVARCHAR(10)) AS apellido,
               N'CARGA-' + RIGHT(N'000000' + CAST(i AS NVARCHAR(10)), 6) AS documento,
               N'7100-' + RIGHT(N'0000' + CAST(i % 10000 AS NVARCHAR(10)), 4) AS telefono,
               DATEADD(DAY, i % 600, @base) AS fecha_registro
        FROM #numeros WHERE i <= 20000
    ) AS s ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (nombre, apellido, documento, telefono, email, fecha_registro, estado)
        VALUES (N'Socio', s.apellido, s.documento, s.telefono, NULL, s.fecha_registro, N'activo')
    OUTPUT s.i, inserted.id_socio INTO #soc (i, id_socio);

    -- 2) Sesiones (ene-2025 a oct-2026, finalizadas)
    CREATE TABLE #ses (i INT NOT NULL PRIMARY KEY, id_sesion INT NOT NULL);
    MERGE dbo.SesionClase AS t
    USING (
        SELECT n.i, c.id_clase, e.id_entrenador, x.ini
        FROM #numeros AS n
        INNER JOIN #clases AS c ON c.rn = ((n.i - 1) % @nc) + 1
        INNER JOIN #entrenadores AS e ON e.rn = ((n.i * 3) % @ne) + 1
        CROSS APPLY (
            SELECT DATEADD(HOUR, 6 + (n.i % 14),
                           CAST(DATEADD(DAY, n.i % 650, @base) AS DATETIME2(0))) AS ini
        ) AS x
        WHERE n.i <= 4000
    ) AS s ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT (id_clase, id_entrenador, inicio, fin, cupo_maximo, estado)
        VALUES (s.id_clase, s.id_entrenador, s.ini, DATEADD(HOUR, 1, s.ini), 120, N'finalizada')
    OUTPUT s.i, inserted.id_sesion INTO #ses (i, id_sesion);

    IF (SELECT COUNT(*) FROM #soc) <> 20000 OR (SELECT COUNT(*) FROM #ses) <> 4000
        THROW 50013, N'No se insertaron todos los socios o sesiones esperados.', 1;

    -- 3) Reservas: cada socio reserva 20 sesiones distintas (sin pares repetidos)
    INSERT INTO dbo.Reserva (id_socio, id_sesion, fecha_reserva, estado)
    SELECT so.id_socio,
           se.id_sesion,
           DATEADD(DAY, -1, sc.inicio),
           CASE WHEN n.i % 10 = 0 THEN N'cancelada' ELSE N'confirmada' END
    FROM #numeros AS n
    CROSS APPLY (SELECT (n.i - 1) % 20000 AS si, (n.i - 1) / 20000 AS k) AS a
    CROSS APPLY (SELECT (a.si * 7 + a.k * 211) % 4000 AS ses) AS b
    INNER JOIN #soc AS so ON so.i = a.si + 1
    INNER JOIN #ses AS se ON se.i = b.ses + 1
    INNER JOIN dbo.SesionClase AS sc ON sc.id_sesion = se.id_sesion;

    -- 4) Membresias (una por socio de carga)
    CREATE TABLE #mem (id_membresia INT NOT NULL PRIMARY KEY, id_socio INT NOT NULL);
    INSERT INTO dbo.MembresiaSocio (id_socio, id_plan, fecha_inicio, fecha_fin, precio_acordado, estado)
    OUTPUT inserted.id_membresia, inserted.id_socio INTO #mem (id_membresia, id_socio)
    SELECT so.id_socio, p.id_plan, x.fi,
           DATEADD(DAY, pl.duracion_dias, x.fi),
           pl.precio_referencia,
           N'activa'
    FROM #soc AS so
    INNER JOIN #planes AS p ON p.rn = ((so.i - 1) % @np) + 1
    INNER JOIN dbo.PlanMembresia AS pl ON pl.id_plan = p.id_plan
    CROSS APPLY (SELECT DATEADD(DAY, so.i % 600, @base) AS fi) AS x;

    -- 5) Pagos: 3 abonos por membresia (aprox. 5 % anulados)
    INSERT INTO dbo.Pago (id_membresia, fecha_pago, monto, metodo_pago, referencia, estado)
    SELECT m.id_membresia,
           DATEADD(HOUR, 9, DATEADD(DAY, k.k * 30, CAST(m.fecha_inicio AS DATETIME2(0)))),
           CAST(ROUND(m.precio_acordado / 3.0, 2) AS DECIMAL(10,2)),
           CHOOSE((m.id_membresia % 3) + 1, N'efectivo', N'tarjeta', N'transferencia'),
           NULL,
           CASE WHEN (m.id_membresia + k.k) % 20 = 0 THEN N'anulado' ELSE N'aplicado' END
    FROM #mem AS x
    INNER JOIN dbo.MembresiaSocio AS m ON m.id_membresia = x.id_membresia
    CROSS JOIN (VALUES (0), (1), (2)) AS k (k);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

DROP TABLE IF EXISTS #numeros, #soc, #ses, #mem, #clases, #entrenadores, #planes;

-- Comprobacion
SELECT N'Socio' AS tabla, COUNT(*) AS registros FROM dbo.Socio
UNION ALL SELECT N'SesionClase',    COUNT(*) FROM dbo.SesionClase
UNION ALL SELECT N'Reserva',        COUNT(*) FROM dbo.Reserva
UNION ALL SELECT N'MembresiaSocio', COUNT(*) FROM dbo.MembresiaSocio
UNION ALL SELECT N'Pago',           COUNT(*) FROM dbo.Pago;
GO
UPDATE STATISTICS dbo.Socio;
UPDATE STATISTICS dbo.SesionClase;
UPDATE STATISTICS dbo.Reserva;
UPDATE STATISTICS dbo.MembresiaSocio;
UPDATE STATISTICS dbo.Pago;
GO
