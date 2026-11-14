/* =====================================================================
   05b_indices_y_planes.sql
   Medicion ANTES / DESPUES de los indices en la base DESECHABLE
   GimnasioDB_Perf, con el mismo volumen y los mismos filtros.

   PREPARACION
     1. 04_consultas.sql ejecutado en GimnasioDB (la copia lo hereda).
     2. 05a_datos_volumen.sql (LOTE 1 y LOTE 2).
     3. SSMS: Query > Include Actual Execution Plan (Ctrl+M) y pestaña
        Messages.
   Registre en el informe, por cada consulta y para ANTES y DESPUES:
     logical reads (tabla con mas lecturas), CPU time, elapsed time,
     numero de filas y la "huella" del resultado (debe ser identica), y
     guarde la captura del plan real. Anote los operadores que realmente
     aparecen (Scan, Seek, Lookup): no se asume ninguno de antemano; un
     Scan no es un error por si mismo.
   DBCC DROPCLEANBUFFERS vacia la cache de TODA la instancia: esta
   comentado. Descomentelo solo en una instancia de pruebas.
   ===================================================================== */

/* === PASO 1: partir sin los indices nuevos (re-ejecutable) ========= */
USE GimnasioDB_Perf;
GO
IF DB_NAME() <> N'GimnasioDB_Perf'
   OR NOT EXISTS (SELECT 1 FROM sys.extended_properties
                  WHERE class = 0 AND name = N'proposito'
                    AND CONVERT(NVARCHAR(100), value) = N'PRUEBA_RENDIMIENTO_DESECHABLE')
    THROW 50040, N'Solo se ejecuta en GimnasioDB_Perf (base desechable).', 1;

DROP INDEX IF EXISTS IX_Reserva_Sesion_Estado ON dbo.Reserva;
DROP INDEX IF EXISTS IX_SesionClase_Inicio    ON dbo.SesionClase;
DROP INDEX IF EXISTS IX_Pago_Estado_FechaPago ON dbo.Pago;
GO
UPDATE STATISTICS dbo.Reserva;
UPDATE STATISTICS dbo.SesionClase;
UPDATE STATISTICS dbo.Pago;
GO

/* === PASO 2: SIN indices - ANTES =================================== */
USE GimnasioDB_Perf;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- solo instancia de pruebas
GO
-- Consulta 1 (un mes)
SELECT * FROM dbo.fn_Consulta1_OcupacionSesiones('20260301', '20260401')
ORDER BY mes, ranking_en_mes, id_sesion;
GO
-- Consulta 2 (siete meses de pagos)
SELECT * FROM dbo.fn_Consulta2_IngresosMensuales('20260101', '20260801')
ORDER BY mes;
GO
-- Consulta 3 (un mes)
SELECT * FROM dbo.fn_Consulta3_RankingSocios('20260301', '20260401')
ORDER BY ranking, id_socio;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
-- Huella del resultado ANTES (anotela; debe coincidir DESPUES)
SELECT N'C1' AS consulta, COUNT(*) AS filas, CHECKSUM_AGG(CHECKSUM(*)) AS huella
FROM dbo.fn_Consulta1_OcupacionSesiones('20260301', '20260401')
UNION ALL
SELECT N'C2', COUNT(*), CHECKSUM_AGG(CHECKSUM(*))
FROM dbo.fn_Consulta2_IngresosMensuales('20260101', '20260801')
UNION ALL
SELECT N'C3', COUNT(*), CHECKSUM_AGG(CHECKSUM(*))
FROM dbo.fn_Consulta3_RankingSocios('20260301', '20260401');
GO

/* === PASO 3: crear los indices ===================================== */
USE GimnasioDB_Perf;
GO
/* Reserva: las FK no crean indice automaticamente. Las consultas 1 y 3
   buscan reservas por sesion y filtran por estado; id_socio se incluye
   para que la consulta 3 pueda leerlo sin ir a la tabla.              */
CREATE NONCLUSTERED INDEX IX_Reserva_Sesion_Estado
    ON dbo.Reserva (id_sesion, estado)
    INCLUDE (id_socio);

/* SesionClase: filtro por rango de fechas (inicio); INCLUDE contiene las
   columnas que leen las consultas.                                    */
CREATE NONCLUSTERED INDEX IX_SesionClase_Inicio
    ON dbo.SesionClase (inicio)
    INCLUDE (id_clase, estado, cupo_maximo);

/* Pago: consulta 2 filtra por estado y rango de fecha_pago y suma monto. */
CREATE NONCLUSTERED INDEX IX_Pago_Estado_FechaPago
    ON dbo.Pago (estado, fecha_pago)
    INCLUDE (monto);
GO
UPDATE STATISTICS dbo.Reserva;
UPDATE STATISTICS dbo.SesionClase;
UPDATE STATISTICS dbo.Pago;
GO

/* === PASO 4: CON indices - DESPUES (mismas consultas y rangos) ===== */
USE GimnasioDB_Perf;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- CHECKPOINT; DBCC DROPCLEANBUFFERS;   -- solo instancia de pruebas
GO
SELECT * FROM dbo.fn_Consulta1_OcupacionSesiones('20260301', '20260401')
ORDER BY mes, ranking_en_mes, id_sesion;
GO
SELECT * FROM dbo.fn_Consulta2_IngresosMensuales('20260101', '20260801')
ORDER BY mes;
GO
SELECT * FROM dbo.fn_Consulta3_RankingSocios('20260301', '20260401')
ORDER BY ranking, id_socio;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
SELECT N'C1' AS consulta, COUNT(*) AS filas, CHECKSUM_AGG(CHECKSUM(*)) AS huella
FROM dbo.fn_Consulta1_OcupacionSesiones('20260301', '20260401')
UNION ALL
SELECT N'C2', COUNT(*), CHECKSUM_AGG(CHECKSUM(*))
FROM dbo.fn_Consulta2_IngresosMensuales('20260101', '20260801')
UNION ALL
SELECT N'C3', COUNT(*), CHECKSUM_AGG(CHECKSUM(*))
FROM dbo.fn_Consulta3_RankingSocios('20260301', '20260401');
GO

/* === PASO 5: tamaño de los indices (para informe y dimensionamiento) = */
USE GimnasioDB_Perf;
GO
SELECT OBJECT_NAME(i.object_id) AS tabla,
       i.name                   AS indice,
       i.type_desc,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(10,2)) AS tamano_mb
FROM sys.indexes AS i
INNER JOIN sys.dm_db_partition_stats AS ps
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.name IN (N'IX_Reserva_Sesion_Estado', N'IX_SesionClase_Inicio',
                 N'IX_Pago_Estado_FechaPago')
GROUP BY i.object_id, i.name, i.type_desc;
GO
