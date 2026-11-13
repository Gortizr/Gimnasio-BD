
USE GimnasioDB;
GO

INSERT INTO dbo.PlanMembresia (
    nombre,
    duracion_dias,
    precio_referencia
)
VALUES
    (N'Mensual', 30, 25.00),
    (N'Trimestral', 90, 65.00),
    (N'Semestral', 180, 120.00);
GO

SELECT
    id_plan,
    nombre,
    duracion_dias,
    precio_referencia,
    estado
FROM dbo.PlanMembresia
ORDER BY id_plan;
GO


USE GimnasioDB;
GO

-- ENTRENADORES

INSERT INTO dbo.Entrenador (nombre,apellido, telefono,email, especialidad
)
VALUES
    (N'Ana', N'Martínez', N'7000-0001',
     N'ana.martinez@example.com', N'Yoga'),

    (N'Carlos', N'López', N'7000-0002',
     N'carlos.lopez@example.com', N'Spinning'),

    (N'Lucía', N'Hernández', N'7000-0003',
     N'lucia.hernandez@example.com', N'Zumba'),

    (N'Diego', N'Ramírez', N'7000-0004',
     N'diego.ramirez@example.com', N'Entrenamiento funcional'),

    (N'Sofía', N'Castro', N'7000-0005',
     N'sofia.castro@example.com', N'Pilates');
GO

-- CLASES

INSERT INTO dbo.Clase (nombre, descripcion
)
VALUES
    (N'Yoga',
     N'Ejercicios de postura, respiración y flexibilidad.'),

    (N'Spinning',
     N'Entrenamiento cardiovascular en bicicleta estática.'),

    (N'Zumba',
     N'Actividad física mediante baile y movimientos aeróbicos.'),

    (N'Entrenamiento funcional',
     N'Ejercicios de fuerza, equilibrio y coordinación.'),

    (N'Pilates',
     N'Ejercicios de control corporal, postura y fortalecimiento.');
GO

-- COMPROBAR LOS DATOS INSERTADOS

SELECT *
FROM dbo.Entrenador
ORDER BY id_entrenador;

SELECT *
FROM dbo.Clase
ORDER BY id_clase;
GO


-- SOCIOS DE PRUEBA

INSERT INTO dbo.Socio (nombre, apellido, documento, telefono, email, fecha_registro, estado
)
VALUES
    (N'José', N'García', N'PRUEBA-001', N'7000-0101',
     N'jose.garcia@example.com', '20260701', N'activo'),

    (N'María', N'Pérez', N'PRUEBA-002', N'7000-0102',
     N'maria.perez@example.com', '20260701', N'activo'),

    (N'Luis', N'Rodríguez', N'PRUEBA-003', N'7000-0103',
     N'luis.rodriguez@example.com', '20260715', N'activo'),

    (N'Andrea', N'Flores', N'PRUEBA-004', N'7000-0104',
     N'andrea.flores@example.com', '20260801', N'activo'),

    (N'Miguel', N'Torres', N'PRUEBA-005', N'7000-0105',
     N'miguel.torres@example.com', '20260801', N'activo'),

    (N'Valeria', N'Romero', N'PRUEBA-006', N'7000-0106',
     N'valeria.romero@example.com', '20260815', N'activo'),

    (N'Fernando', N'Cruz', N'PRUEBA-007', N'7000-0107',
     N'fernando.cruz@example.com', '20260901', N'activo'),

    (N'Gabriela', N'Reyes', N'PRUEBA-008', N'7000-0108',
     N'gabriela.reyes@example.com', '20260915', N'activo'),

    (N'Ricardo', N'Mendoza', N'PRUEBA-009', N'7000-0109',
     N'ricardo.mendoza@example.com', '20261001', N'activo'),

    (N'Daniela', N'Vega', N'PRUEBA-010', N'7000-0110',
     N'daniela.vega@example.com', '20261015', N'inactivo');
GO



-- SESIONES DE CLASE DE PRUEBA
-- Las fechas son fijas para compartir los mismos datos.

INSERT INTO dbo.SesionClase (id_clase, id_entrenador, inicio, fin, cupo_maximo, estado
)
VALUES
    -- Sesiones realizadas en octubre
    (1, 1, '2026-10-20T07:00:00',
     '2026-10-20T08:00:00', 15, N'finalizada'),

    (2, 2, '2026-10-20T08:00:00',
     '2026-10-20T09:00:00', 20, N'finalizada'),

    (3, 3, '2026-10-21T17:00:00',
     '2026-10-21T18:00:00', 25, N'finalizada'),

    (4, 4, '2026-10-21T18:00:00',
     '2026-10-21T19:00:00', 12, N'finalizada'),

    (5, 5, '2026-10-22T07:00:00',
     '2026-10-22T08:00:00', 10, N'finalizada'),

    -- Sesiones programadas en noviembre
    (1, 1, '2026-11-10T07:00:00',
     '2026-11-10T08:00:00', 15, N'programada'),

    (2, 2, '2026-11-10T08:00:00',
     '2026-11-10T09:00:00', 20, N'programada'),

    (3, 3, '2026-11-11T17:00:00',
     '2026-11-11T18:00:00', 25, N'programada'),

    (4, 4, '2026-11-11T18:00:00',
     '2026-11-11T19:00:00', 3, N'programada'),

    -- Sesión cancelada para probar este escenario
    (5, 5, '2026-11-12T07:00:00',
     '2026-11-12T08:00:00', 10, N'cancelada');
GO

-- VERIFICAR SESIONES CON NOMBRES DE CLASE Y ENTRENADOR

SELECT
    s.id_sesion,
    c.nombre AS clase,
    CONCAT(e.nombre, N' ', e.apellido) AS entrenador,
    s.inicio,
    s.fin,
    s.cupo_maximo,
    s.estado
FROM dbo.SesionClase AS s
INNER JOIN dbo.Clase AS c
    ON s.id_clase = c.id_clase
INNER JOIN dbo.Entrenador AS e
    ON s.id_entrenador = e.id_entrenador
ORDER BY s.inicio, s.id_sesion;
GO


USE GimnasioDB;
GO

-- MEMBRESÍAS DE PRUEBA
-- fecha_fin es el primer día sin cobertura.

INSERT INTO dbo.MembresiaSocio ( id_socio, id_plan, fecha_inicio, fecha_fin, precio_acordado, estado
)
SELECT s.id_socio, p.id_plan, d.fecha_inicio,
 DATEADD(DAY, p.duracion_dias, d.fecha_inicio),
  p.precio_referencia, d.estado
FROM (
    VALUES
        (N'PRUEBA-001', N'Trimestral',
         CONVERT(DATE, '20261001'), N'activa'),

        (N'PRUEBA-002', N'Semestral',
         CONVERT(DATE, '20260701'), N'activa'),

        (N'PRUEBA-003', N'Mensual',
         CONVERT(DATE, '20261015'), N'activa'),

        (N'PRUEBA-004', N'Trimestral',
         CONVERT(DATE, '20260901'), N'activa'),

        (N'PRUEBA-005', N'Mensual',
         CONVERT(DATE, '20261101'), N'activa'),

        (N'PRUEBA-006', N'Semestral',
         CONVERT(DATE, '20260815'), N'activa'),

        (N'PRUEBA-007', N'Mensual',
         CONVERT(DATE, '20260901'), N'activa'),

        (N'PRUEBA-008', N'Mensual',
         CONVERT(DATE, '20260915'), N'activa'),

        (N'PRUEBA-009', N'Trimestral',
         CONVERT(DATE, '20261001'), N'activa'),

        (N'PRUEBA-010', N'Mensual',
         CONVERT(DATE, '20261015'), N'cancelada')
) AS d (documento, nombre_plan, fecha_inicio, estado)
INNER JOIN dbo.Socio AS s
    ON s.documento = d.documento
INNER JOIN dbo.PlanMembresia AS p
    ON p.nombre = d.nombre_plan;
GO

-- COMPROBAR LA VIGENCIA EN UNA FECHA FIJA DE PRUEBA

USE GimnasioDB;
GO

DECLARE @fecha_revision DATE = '20261108';

SELECT
    m.id_membresia,
    CONCAT(s.nombre, N' ', s.apellido) AS socio,
    p.nombre AS nombre_plan,
    m.fecha_inicio,
    m.fecha_fin,
    m.precio_acordado,
    m.estado,
    CASE
        WHEN m.estado = N'cancelada' THEN N'Cancelada'
        WHEN @fecha_revision < m.fecha_inicio THEN N'Por iniciar'
        WHEN @fecha_revision >= m.fecha_fin THEN N'Vencida'
        ELSE N'Vigente'
    END AS vigencia_al_8_noviembre
FROM dbo.MembresiaSocio AS m
INNER JOIN dbo.Socio AS s
    ON s.id_socio = m.id_socio
INNER JOIN dbo.PlanMembresia AS p
    ON p.id_plan = m.id_plan
ORDER BY m.id_membresia;
GO



USE GimnasioDB;
GO

-- RESERVAS DE PRUEBA
-- La fecha de reserva es anterior al inicio de la sesión.

INSERT INTO dbo.Reserva ( id_socio, id_sesion, fecha_reserva, estado
)
VALUES
    -- Sesiones de octubre
    (1, 1, '2026-10-18T09:00:00', N'confirmada'),
    (2, 1, '2026-10-18T10:00:00', N'confirmada'),
    (3, 1, '2026-10-19T11:00:00', N'confirmada'),

    (4, 2, '2026-10-18T09:30:00', N'confirmada'),
    (6, 2, '2026-10-19T10:30:00', N'confirmada'),

    (2, 3, '2026-10-19T08:00:00', N'confirmada'),
    (9, 3, '2026-10-20T09:00:00', N'confirmada'),

    (1, 4, '2026-10-20T10:00:00', N'confirmada'),
    (4, 4, '2026-10-20T11:00:00', N'confirmada'),

    (6, 5, '2026-10-21T08:00:00', N'confirmada'),

    -- Sesiones de noviembre
    (1, 6, '2026-11-07T09:00:00', N'confirmada'),
    (2, 6, '2026-11-07T09:15:00', N'confirmada'),
    (3, 6, '2026-11-07T09:30:00', N'confirmada'),

    (4, 7, '2026-11-07T10:00:00', N'confirmada'),
    (5, 7, '2026-11-07T10:15:00', N'confirmada'),

    (6, 8, '2026-11-07T11:00:00', N'confirmada'),
    (9, 8, '2026-11-07T11:15:00', N'confirmada'),
    (2, 8, '2026-11-07T11:30:00', N'cancelada'),

    -- Sesión 9: sus tres cupos quedan ocupados
    (1, 9, '2026-11-07T12:00:00', N'confirmada'),
    (4, 9, '2026-11-07T12:15:00', N'confirmada'),
    (5, 9, '2026-11-07T12:30:00', N'confirmada');
GO

-- COMPROBAR RESERVAS Y CUPOS POR SESIÓN

SELECT sc.id_sesion, c.nombre AS clase, sc.inicio, sc.estado AS estado_sesion, sc.cupo_maximo,
    SUM(
        CASE WHEN r.estado = N'confirmada'
             THEN 1 ELSE 0 END
    ) AS reservas_confirmadas,
    SUM(
        CASE WHEN r.estado = N'cancelada'
             THEN 1 ELSE 0 END
    ) AS reservas_canceladas,
    sc.cupo_maximo - SUM(
        CASE WHEN r.estado = N'confirmada'
             THEN 1 ELSE 0 END
    ) AS cupos_sin_reserva
FROM dbo.SesionClase AS sc
INNER JOIN dbo.Clase AS c
    ON c.id_clase = sc.id_clase
LEFT JOIN dbo.Reserva AS r
    ON r.id_sesion = sc.id_sesion
GROUP BY sc.id_sesion, c.nombre, sc.inicio, sc.estado, sc.cupo_maximo
ORDER BY sc.id_sesion;
GO


USE GimnasioDB;
GO

-- PAGOS DE PRUEBA
-- Incluimos pagos completos, abonos y un pago anulado.
-- Las referencias son ficticias.

INSERT INTO dbo.Pago ( id_membresia, fecha_pago, monto, metodo_pago, referencia,  estado
)
VALUES
    -- María: membresía semestral, pagada completamente
    (2, '2026-07-01T09:00:00', 120.00,
     N'tarjeta', N'PRUEBA-PAGO-001', N'aplicado'),

    -- Valeria: membresía semestral, pagada en dos abonos
    (6, '2026-08-15T10:00:00', 60.00,
     N'transferencia', N'PRUEBA-PAGO-002', N'aplicado'),

    (6, '2026-09-15T10:00:00', 60.00,
     N'transferencia', N'PRUEBA-PAGO-003', N'aplicado'),

    -- Andrea: membresía trimestral, pagada completamente
    (4, '2026-09-01T08:30:00', 65.00,
     N'efectivo', NULL, N'aplicado'),

    -- Fernando y Gabriela: membresías ya vencidas
    (7, '2026-09-01T11:00:00', 25.00,
     N'efectivo', NULL, N'aplicado'),

    (8, '2026-09-15T12:00:00', 25.00,
     N'tarjeta', N'PRUEBA-PAGO-006', N'aplicado'),

    -- José: membresía trimestral, pagada completamente
    (1, '2026-10-01T09:00:00', 65.00,
     N'transferencia', N'PRUEBA-PAGO-007', N'aplicado'),

    -- Ricardo: abono de 40, quedan 25 pendientes
    (9, '2026-10-01T10:00:00', 40.00,
     N'efectivo', NULL, N'aplicado'),

    -- Luis: pago anulado y luego registrado correctamente
    (3, '2026-10-15T08:00:00', 25.00,
     N'tarjeta', N'PRUEBA-PAGO-009', N'anulado'),

    (3, '2026-10-15T08:15:00', 25.00,
     N'efectivo', NULL, N'aplicado'),

    -- Miguel: membresía mensual, pagada completamente
    (5, '2026-11-01T09:00:00', 25.00,
     N'tarjeta', N'PRUEBA-PAGO-011', N'aplicado');
GO

-- COMPROBAR LOS PAGOS Y SALDOS POR MEMBRESÍA

SELECT m.id_membresia,
 CONCAT(s.nombre, N' ', s.apellido) AS socio,
    m.estado AS estado_membresia,
    m.precio_acordado,
    SUM(
        CASE WHEN p.estado = N'aplicado'
             THEN p.monto ELSE 0 END
    ) AS total_pagado,
    m.precio_acordado - SUM(
        CASE WHEN p.estado = N'aplicado'
             THEN p.monto ELSE 0 END
    ) AS diferencia_precio_pagos
FROM dbo.MembresiaSocio AS m
INNER JOIN dbo.Socio AS s
    ON s.id_socio = m.id_socio
LEFT JOIN dbo.Pago AS p
    ON p.id_membresia = m.id_membresia
GROUP BY m.id_membresia, s.nombre, s.apellido, m.estado, m.precio_acordado
ORDER BY m.id_membresia;
GO

USE GimnasioDB;
GO

SELECT N'PlanMembresia' AS tabla,
       COUNT(*) AS registros, 3 AS esperados
FROM dbo.PlanMembresia
UNION ALL
SELECT N'Entrenador', COUNT(*), 5 FROM dbo.Entrenador
UNION ALL
SELECT N'Clase', COUNT(*), 5 FROM dbo.Clase
UNION ALL
SELECT N'Socio', COUNT(*), 10 FROM dbo.Socio
UNION ALL
SELECT N'SesionClase', COUNT(*), 10 FROM dbo.SesionClase
UNION ALL
SELECT N'MembresiaSocio', COUNT(*), 10 FROM dbo.MembresiaSocio
UNION ALL
SELECT N'Reserva', COUNT(*), 21 FROM dbo.Reserva
UNION ALL
SELECT N'Pago', COUNT(*), 11 FROM dbo.Pago;
GO

SELECT
    estado,
    COUNT(*) AS cantidad_pagos,
    SUM(monto) AS monto_total
FROM dbo.Pago
GROUP BY estado;
GO