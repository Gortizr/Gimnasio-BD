/* =====================================================================
   04_consultas.sql  -  PERSONA 3: Consultas con funciones ventana
   Base: GimnasioDB      Requiere: Crear_base.sql + datos_prueba.sql

   Cada consulta es una funcion de tabla en linea (inline TVF, esquema
   dbo) con un rango de fechas como parametro. Una funcion en linea se
   expande dentro del plan como una vista, asi el filtro por fechas
   puede aprovechar los indices.
   Para Power BI se exponen mediante vistas del esquema reportes
   (04b_vistas_reportes.sql). Se conserva el rango completo
   '19000101'-'29990101'; los segmentadores de Power BI NO recalculan las
   ventanas SQL (LAG, RANK, acumulados...): se calculan en el servidor
   sobre el rango indicado.
   Se puede ejecutar varias veces (CREATE OR ALTER).
   ===================================================================== */
USE GimnasioDB;
GO

/* ---------------------------------------------------------------------
   CONSULTA 1 - Ocupacion de sesiones y ranking dentro de cada mes
   Pregunta de negocio: ¿que sesiones se llenan y cuales quedan vacias?
   Funciones ventana: RANK() y SUM() OVER (PARTITION BY mes)
   Excluye sesiones canceladas y cuenta solo reservas confirmadas.
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_Consulta1_OcupacionSesiones
(
    @desde DATETIME2(0),
    @hasta DATETIME2(0)
)
RETURNS TABLE
AS
RETURN
(
    WITH ocupacion AS (
        SELECT
            sc.id_sesion,
            c.nombre AS clase,
            DATEFROMPARTS(YEAR(sc.inicio), MONTH(sc.inicio), 1) AS mes,
            sc.inicio,
            sc.cupo_maximo,
            COUNT(r.id_reserva) AS reservas_confirmadas
        FROM dbo.SesionClase AS sc
        INNER JOIN dbo.Clase AS c
            ON c.id_clase = sc.id_clase
        LEFT JOIN dbo.Reserva AS r
            ON r.id_sesion = sc.id_sesion
           AND r.estado = N'confirmada'
        WHERE sc.estado <> N'cancelada'
          AND sc.inicio >= @desde
          AND sc.inicio <  @hasta
        GROUP BY sc.id_sesion, c.nombre, sc.inicio, sc.cupo_maximo
    )
    SELECT
        id_sesion,
        clase,
        mes,
        inicio,
        cupo_maximo,
        reservas_confirmadas,
        CAST(100.0 * reservas_confirmadas / cupo_maximo AS DECIMAL(5,1))
            AS pct_ocupacion,
        RANK() OVER (
            PARTITION BY mes
            ORDER BY 100.0 * reservas_confirmadas / cupo_maximo DESC
        ) AS ranking_en_mes,
        CAST(100.0 * reservas_confirmadas
             / NULLIF(SUM(reservas_confirmadas) OVER (PARTITION BY mes), 0)
             AS DECIMAL(5,1)) AS pct_reservas_del_mes
    FROM ocupacion
);
GO

/* ---------------------------------------------------------------------
   CONSULTA 2 - Ingresos mensuales, variacion y acumulado
   Pregunta de negocio: ¿cuanto entra por mes y como evoluciona?
   Funciones ventana: LAG(), SUM() acumulado, AVG() movil de 3 meses
   Solo cuenta pagos 'aplicado' (los 'anulado' no son ingreso).
   Calendario: entre el primer y el ultimo mes CON pagos del rango se
   generan todos los meses; los meses sin pagos aparecen con ingresos 0,
   de modo que LAG y la ventana de 3 filas sean meses consecutivos.
   (Meses anteriores al primer pago o posteriores al ultimo no se crean.)
   ingresos_acumulados es un total corrido: NO se debe sumar en un KPI.
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_Consulta2_IngresosMensuales
(
    @desde DATETIME2(0),
    @hasta DATETIME2(0)
)
RETURNS TABLE
AS
RETURN
(
    WITH mensual AS (
        SELECT
            DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1) AS mes,
            COUNT(*)     AS cantidad_pagos,
            SUM(p.monto) AS ingresos
        FROM dbo.Pago AS p
        WHERE p.estado = N'aplicado'
          AND p.fecha_pago >= @desde
          AND p.fecha_pago <  @hasta
        GROUP BY DATEFROMPARTS(YEAR(p.fecha_pago), MONTH(p.fecha_pago), 1)
    ),
    limites AS (
        SELECT MIN(mes) AS mes_min, MAX(mes) AS mes_max FROM mensual
    ),
    calendario AS (
        SELECT DATEADD(MONTH, t.n, l.mes_min) AS mes
        FROM limites AS l
        CROSS APPLY (
            SELECT TOP (COALESCE(DATEDIFF(MONTH, l.mes_min, l.mes_max) + 1, 0))
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM sys.all_objects AS a
            CROSS JOIN sys.all_objects AS b
        ) AS t
    ),
    completo AS (
        SELECT c.mes,
               COALESCE(m.cantidad_pagos, 0) AS cantidad_pagos,
               COALESCE(m.ingresos, CAST(0 AS DECIMAL(38,2))) AS ingresos
        FROM calendario AS c
        LEFT JOIN mensual AS m
            ON m.mes = c.mes
    )
    SELECT
        mes,
        cantidad_pagos,
        ingresos,
        LAG(ingresos) OVER (ORDER BY mes) AS ingresos_mes_anterior,
        CAST(100.0 * (ingresos - LAG(ingresos) OVER (ORDER BY mes))
             / NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0)
             AS DECIMAL(8,1)) AS variacion_pct,
        SUM(ingresos) OVER (
            ORDER BY mes
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS ingresos_acumulados,
        CAST(AVG(ingresos) OVER (
            ORDER BY mes
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS DECIMAL(12,2)) AS promedio_movil_3m
    FROM completo
);
GO

/* ---------------------------------------------------------------------
   CONSULTA 3 - Ranking de socios por actividad (reservas confirmadas)
   Pregunta de negocio: ¿quienes son los socios mas activos y a quienes
   hay que reactivar (0 reservas)?
   Funciones ventana: DENSE_RANK(), NTILE(3), AVG() OVER ()
   Incluye socios sin reservas (LEFT JOIN). Devuelve la actividad
   AGREGADA del rango @desde/@hasta (no trae fechas por reserva).
   NTILE(3) forma tres grupos RELATIVOS de tamaño casi igual (alta,
   media, baja); puede separar socios con el mismo numero de reservas
   (el desempate es id_socio). El empate real lo muestra 'ranking'.
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_Consulta3_RankingSocios
(
    @desde DATETIME2(0),
    @hasta DATETIME2(0)
)
RETURNS TABLE
AS
RETURN
(
    WITH actividad AS (
        SELECT
            r.id_socio,
            COUNT(*) AS reservas
        FROM dbo.Reserva AS r
        INNER JOIN dbo.SesionClase AS sc
            ON sc.id_sesion = r.id_sesion
        WHERE r.estado = N'confirmada'
          AND sc.estado <> N'cancelada'
          AND sc.inicio >= @desde
          AND sc.inicio <  @hasta
        GROUP BY r.id_socio
    ),
    base AS (
        SELECT
            s.id_socio,
            CONCAT(s.nombre, N' ', s.apellido) AS socio,
            s.estado AS estado_socio,
            COALESCE(a.reservas, 0) AS reservas_confirmadas
        FROM dbo.Socio AS s
        LEFT JOIN actividad AS a
            ON a.id_socio = s.id_socio
    )
    SELECT
        id_socio,
        socio,
        estado_socio,
        reservas_confirmadas,
        DENSE_RANK() OVER (ORDER BY reservas_confirmadas DESC) AS ranking,
        CASE NTILE(3) OVER (ORDER BY reservas_confirmadas DESC, id_socio)
            WHEN 1 THEN N'Alta'
            WHEN 2 THEN N'Media'
            ELSE N'Baja'
        END AS grupo_actividad,
        CAST(AVG(CAST(reservas_confirmadas AS DECIMAL(10,2))) OVER ()
             AS DECIMAL(10,2)) AS promedio_reservas,
        CAST(reservas_confirmadas
             - AVG(CAST(reservas_confirmadas AS DECIMAL(10,2))) OVER ()
             AS DECIMAL(10,2)) AS diferencia_vs_promedio
    FROM base
);
GO

/* ---------------------------------------------------------------------
   EJECUCION (con los datos de prueba: todo el rango 2026)
   --------------------------------------------------------------------- */
SELECT * FROM dbo.fn_Consulta1_OcupacionSesiones('20260101', '20270101')
ORDER BY mes, ranking_en_mes, id_sesion;

SELECT * FROM dbo.fn_Consulta2_IngresosMensuales('20260101', '20270101')
ORDER BY mes;

SELECT * FROM dbo.fn_Consulta3_RankingSocios('20260101', '20270101')
ORDER BY ranking, id_socio;
GO
