-- ============================================================================
-- GIMNASIODB - DATOS ADICIONALES PARA DASHBOARDS DE POWER BI
-- Archivo: datos_adicionales_dashboard.sql
-- PROYECTO: Gimnasio-BD | Version: 2026-11-13
-- ============================================================================
-- FINALIDAD:
--   Agregar exactamente 140 socios, 70 sesiones, 140 membresias,
--   279 reservas y 169 pagos a los datos originales de datos_prueba.sql.
--   Total esperado: Socio=150; SesionClase=80; MembresiaSocio=150;
--                   Reserva=300; Pago=180.
--
-- REQUISITOS:
--   1) Crear_base.sql EJECUTADO UNA VEZ en una base nueva.
--   2) datos_prueba.sql ORIGINAL (10 socios, 10 sesiones, 10 membresias,
--      21 reservas y 11 pagos); NO la copia a la que agregaste otros bloques.
--   3) Ejecutar ESTE archivo; reejecutarlo NO debe duplicar los datos.
--
-- SEGURIDAD:
--   * NO crea, altera ni elimina tablas, columnas, indices, roles ni jobs.
--   * NO modifica los datos ya existentes.
--   * No usa IDENTITY_INSERT, DBCC CHECKIDENT ni presupone IDs consecutivos.
--   * Encuentra socios por documento, planes y clases por nombre,
--     entrenadores por email, sesiones por clase+entrenador+inicio,
--     membresias por socio+fecha_inicio y pagos por referencia.
--   * Si detecta un conflicto o falla una validacion, ROLLBACK completo.
--
-- ATENCION:
--   Se conserva el conjunto original de datos adicionales y sus variaciones.
--   Ejecutar con permisos de insercion en las 5 tablas de operacion.
--   Para probar desde cero, usar una BASE DE PRUEBA separada de GimnasioDB.
-- ============================================================================
USE GimnasioDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ------------------------------------------------------------------------
    -- PRECONDICIONES: las tablas originales deben existir y sus claves
    -- identificables no deben ser ambiguas. El usuario no debe haber ejecutado
    -- datos_prueba.sql completo dos veces sobre la misma base.
    -- ------------------------------------------------------------------------
    IF OBJECT_ID(N'dbo.Socio', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Entrenador', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Clase', N'U') IS NULL
       OR OBJECT_ID(N'dbo.SesionClase', N'U') IS NULL
       OR OBJECT_ID(N'dbo.PlanMembresia', N'U') IS NULL
       OR OBJECT_ID(N'dbo.MembresiaSocio', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Reserva', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Pago', N'U') IS NULL
    BEGIN
        ;THROW 51001, 'Faltan tablas de Crear_base.sql.', 1;
    END;

    IF (SELECT COUNT(*) FROM dbo.PlanMembresia WHERE nombre IN
        (N'Mensual', N'Trimestral', N'Semestral')) <> 3
       OR (SELECT COUNT(*) FROM dbo.Clase WHERE nombre IN
        (N'Yoga', N'Spinning', N'Zumba', N'Entrenamiento funcional', N'Pilates')) <> 5
    BEGIN
        ;THROW 51002, 'Faltan planes o clases originales. Ejecutar primero datos_prueba.sql original.', 1;
    END;

    IF EXISTS (
        SELECT email FROM dbo.Entrenador
        WHERE email IN (N'ana.martinez@example.com', N'carlos.lopez@example.com',
                        N'lucia.hernandez@example.com', N'diego.ramirez@example.com',
                        N'sofia.castro@example.com')
        GROUP BY email HAVING COUNT(*) <> 1
    )
    BEGIN
        ;THROW 51003, 'Entrenadores originales con correo duplicado. No se puede enlazar la sesion.', 1;
    END;

    IF (SELECT COUNT(*) FROM dbo.Entrenador WHERE email IN
        (N'ana.martinez@example.com', N'carlos.lopez@example.com',
         N'lucia.hernandez@example.com', N'diego.ramirez@example.com',
         N'sofia.castro@example.com')) <> 5
    BEGIN
        ;THROW 51004, 'Faltan los entrenadores originales.', 1;
    END;

    -- ------------------------------------------------------------------------
    -- 1. SOCIO: 140 registros adicionales; los 10 originales no se repiten.
    -- Usamos documento ficticio como clave de busqueda (es UNIQUE en dbo.Socio).
    -- ------------------------------------------------------------------------
    CREATE TABLE #SociosExtra (
        nombre NVARCHAR(50) NOT NULL,
        apellido NVARCHAR(50) NOT NULL,
        documento NVARCHAR(20) NOT NULL PRIMARY KEY,
        telefono NVARCHAR(20) NOT NULL,
        email NVARCHAR(100) NULL,
        fecha_registro DATE NOT NULL,
        estado NVARCHAR(10) NOT NULL
    );

    INSERT INTO #SociosExtra (
        nombre, apellido, documento, telefono, email, fecha_registro, estado
    )
    VALUES


        -- Socios ficticios con nombres, fechas y estados variados
        (N'Gabriel', N'Benítez Torres', N'GYM-SOC-0001', N'7029-9711', N'socio001@ejemplo.test', N'2026-03-06', N'activo'),
        (N'Santiago', N'Ibarra López', N'GYM-SOC-0002', N'7049-3642', N'socio002@ejemplo.test', N'2025-08-05', N'inactivo'),
        (N'Lucía', N'Santos Lara', N'GYM-SOC-0003', N'7472-1037', NULL, N'2025-11-24', N'activo'),
        (N'Emilio', N'Molina Aguilar', N'GYM-SOC-0004', N'7971-4024', N'socio004@ejemplo.test', N'2025-12-11', N'activo'),
        (N'Claudia', N'Tejada Mejía', N'GYM-SOC-0005', N'7672-1144', N'socio005@ejemplo.test', N'2026-08-11', N'inactivo'),
        (N'Gabriel', N'Benítez Ortiz', N'GYM-SOC-0006', N'7498-0410', N'socio006@ejemplo.test', N'2025-02-08', N'inactivo'),
        (N'Claudia', N'Santos Aguilar', N'GYM-SOC-0007', N'7667-3569', N'socio007@ejemplo.test', N'2026-08-19', N'inactivo'),
        (N'Víctor', N'Lara Campos', N'GYM-SOC-0008', N'7944-4430', N'socio008@ejemplo.test', N'2025-01-06', N'activo'),
        (N'Emilio', N'Espinoza Lara', N'GYM-SOC-0009', N'7384-8049', N'socio009@ejemplo.test', N'2025-04-21', N'inactivo'),
        (N'Marcos', N'Portillo Rivas', N'GYM-SOC-0010', N'7694-2975', N'socio010@ejemplo.test', N'2026-07-07', N'activo'),
        (N'Emilio', N'Tejada Ortiz', N'GYM-SOC-0011', N'7384-1267', N'socio011@ejemplo.test', N'2026-10-18', N'activo'),
        (N'Camila', N'Ortiz Jiménez', N'GYM-SOC-0012', N'7901-7959', NULL, N'2025-12-16', N'activo'),
        (N'Pablo', N'Santos Benítez', N'GYM-SOC-0013', N'7423-6378', N'socio013@ejemplo.test', N'2025-03-16', N'inactivo'),
        (N'Andrés', N'Espinoza Acosta', N'GYM-SOC-0014', N'7966-8395', N'socio014@ejemplo.test', N'2025-07-25', N'inactivo'),
        (N'Renata', N'Acosta Jiménez', N'GYM-SOC-0015', N'7560-1213', N'socio015@ejemplo.test', N'2026-11-05', N'activo'),
        (N'Karla', N'Santos Espinoza', N'GYM-SOC-0016', N'7164-4719', N'socio016@ejemplo.test', N'2026-01-14', N'activo'),
        (N'Valentina', N'Herrera Ortiz', N'GYM-SOC-0017', N'7127-4667', N'socio017@ejemplo.test', N'2025-12-23', N'activo'),
        (N'Daniela', N'Espinoza Lara', N'GYM-SOC-0018', N'7697-7702', N'socio018@ejemplo.test', N'2025-01-03', N'inactivo'),
        (N'Santiago', N'Barahona Acosta', N'GYM-SOC-0019', N'7643-9770', N'socio019@ejemplo.test', N'2026-10-12', N'activo'),
        (N'Claudia', N'Portillo Escobar', N'GYM-SOC-0020', N'7345-7946', N'socio020@ejemplo.test', N'2025-11-04', N'inactivo'),
        (N'Santiago', N'Acosta Santos', N'GYM-SOC-0021', N'7717-1130', N'socio021@ejemplo.test', N'2026-10-27', N'activo'),
        (N'Nicolás', N'Portillo Acosta', N'GYM-SOC-0022', N'7963-6060', N'socio022@ejemplo.test', N'2026-02-18', N'activo'),
        (N'Gabriela', N'Granados Campos', N'GYM-SOC-0023', N'7433-4654', N'socio023@ejemplo.test', N'2026-07-02', N'activo'),
        (N'Daniela', N'Rivera Ortiz', N'GYM-SOC-0024', N'7779-6032', N'socio024@ejemplo.test', N'2025-09-27', N'activo'),
        (N'Pablo', N'Portillo Tejada', N'GYM-SOC-0025', N'7366-8734', N'socio025@ejemplo.test', N'2025-02-24', N'activo'),
        (N'Isabel', N'Figueroa Castillo', N'GYM-SOC-0026', N'7467-8507', N'socio026@ejemplo.test', N'2025-10-14', N'activo'),
        (N'Nicolás', N'Campos Pineda', N'GYM-SOC-0027', N'7815-9660', N'socio027@ejemplo.test', N'2025-01-14', N'activo'),
        (N'Esteban', N'Barahona Aguilar', N'GYM-SOC-0028', N'7941-3704', N'socio028@ejemplo.test', N'2026-09-03', N'activo'),
        (N'Andrea', N'Tejada Barahona', N'GYM-SOC-0029', N'7271-0965', N'socio029@ejemplo.test', N'2025-02-27', N'activo'),
        (N'Mariana', N'Guzmán Aguilar', N'GYM-SOC-0030', N'7481-6333', N'socio030@ejemplo.test', N'2026-03-12', N'inactivo'),
        (N'Santiago', N'Salazar Rivas', N'GYM-SOC-0031', N'7696-9167', N'socio031@ejemplo.test', N'2025-02-08', N'activo'),
        (N'Fernando', N'Herrera Molina', N'GYM-SOC-0032', N'7523-8844', N'socio032@ejemplo.test', N'2025-11-23', N'activo'),
        (N'Marcos', N'Lara Santos', N'GYM-SOC-0033', N'7054-7101', NULL, N'2026-08-17', N'activo'),
        (N'Javier', N'Herrera Jiménez', N'GYM-SOC-0034', N'7654-0130', N'socio034@ejemplo.test', N'2026-10-19', N'inactivo'),
        (N'Nicolás', N'Castillo Granados', N'GYM-SOC-0035', N'7329-0289', N'socio035@ejemplo.test', N'2025-12-31', N'activo'),
        (N'Leonardo', N'Aguilar Salazar', N'GYM-SOC-0036', N'7715-3404', N'socio036@ejemplo.test', N'2026-09-25', N'inactivo'),
        (N'Emilio', N'Pineda Barahona', N'GYM-SOC-0037', N'7420-1698', N'socio037@ejemplo.test', N'2025-10-26', N'inactivo'),
        (N'Mateo', N'Rivas López', N'GYM-SOC-0038', N'7571-9937', N'socio038@ejemplo.test', N'2025-04-14', N'activo'),
        (N'Mariana', N'Ibarra Tejada', N'GYM-SOC-0039', N'7717-6534', N'socio039@ejemplo.test', N'2026-10-05', N'activo'),
        (N'Sebastián', N'Fuentes Ortiz', N'GYM-SOC-0040', N'7713-7345', N'socio040@ejemplo.test', N'2026-10-21', N'activo'),
        (N'Fernando', N'Fuentes Escobar', N'GYM-SOC-0041', N'7757-5187', N'socio041@ejemplo.test', N'2026-10-02', N'activo'),
        (N'Beatriz', N'Salazar Fuentes', N'GYM-SOC-0042', N'7181-5966', N'socio042@ejemplo.test', N'2026-10-16', N'activo'),
        (N'Beatriz', N'Vásquez Hernández', N'GYM-SOC-0043', N'7138-3569', N'socio043@ejemplo.test', N'2026-11-08', N'activo'),
        (N'Sofía', N'Ibarra Quinteros', N'GYM-SOC-0044', N'7009-5513', N'socio044@ejemplo.test', N'2025-05-17', N'activo'),
        (N'Mariana', N'Figueroa Ortiz', N'GYM-SOC-0045', N'7027-3029', N'socio045@ejemplo.test', N'2025-04-06', N'inactivo'),
        (N'Daniela', N'Quinteros Jiménez', N'GYM-SOC-0046', N'7275-9987', N'socio046@ejemplo.test', N'2025-11-02', N'activo'),
        (N'Santiago', N'Portillo Duarte', N'GYM-SOC-0047', N'7082-2358', N'socio047@ejemplo.test', N'2026-08-02', N'inactivo'),
        (N'Karla', N'Duarte Rivas', N'GYM-SOC-0048', N'7262-5643', N'socio048@ejemplo.test', N'2025-12-15', N'activo'),
        (N'Andrea', N'Herrera Morales', N'GYM-SOC-0049', N'7941-6458', N'socio049@ejemplo.test', N'2026-02-24', N'activo'),
        (N'Sofía', N'Zelaya Espinoza', N'GYM-SOC-0050', N'7757-3504', N'socio050@ejemplo.test', N'2026-08-07', N'activo'),

        -- Continuan socios variados
        (N'Sebastián', N'Valencia Pineda', N'GYM-SOC-0051', N'7595-6209', N'socio051@ejemplo.test', N'2026-07-30', N'activo'),
        (N'Olivia', N'Pineda Castillo', N'GYM-SOC-0052', N'7437-4427', N'socio052@ejemplo.test', N'2026-10-16', N'activo'),
        (N'Diego', N'Molina Zelaya', N'GYM-SOC-0053', N'7540-6217', N'socio053@ejemplo.test', N'2026-09-29', N'activo'),
        (N'Sofía', N'Santos Pineda', N'GYM-SOC-0054', N'7301-7782', N'socio054@ejemplo.test', N'2026-04-01', N'activo'),
        (N'Fabiana', N'Aguilar Fuentes', N'GYM-SOC-0055', N'7179-3571', N'socio055@ejemplo.test', N'2026-04-19', N'activo'),
        (N'Sofía', N'Santos Ibarra', N'GYM-SOC-0056', N'7446-0911', N'socio056@ejemplo.test', N'2026-02-08', N'activo'),
        (N'Andrés', N'Delgado Mejía', N'GYM-SOC-0057', N'7683-7617', N'socio057@ejemplo.test', N'2025-12-15', N'activo'),
        (N'Santiago', N'Acosta Herrera', N'GYM-SOC-0058', N'7551-1353', N'socio058@ejemplo.test', N'2026-10-20', N'inactivo'),
        (N'Tatiana', N'Molina Torres', N'GYM-SOC-0059', N'7317-9683', N'socio059@ejemplo.test', N'2025-10-12', N'activo'),
        (N'Andrea', N'Molina Lara', N'GYM-SOC-0060', N'7910-2024', N'socio060@ejemplo.test', N'2025-06-17', N'activo'),
        (N'Gabriel', N'Pineda Campos', N'GYM-SOC-0061', N'7793-5531', N'socio061@ejemplo.test', N'2025-03-05', N'activo'),
        (N'Valeria', N'Navarro Ibarra', N'GYM-SOC-0062', N'7653-0315', N'socio062@ejemplo.test', N'2026-07-29', N'activo'),
        (N'Víctor', N'Mejía Quinteros', N'GYM-SOC-0063', N'7509-0291', N'socio063@ejemplo.test', N'2026-09-29', N'inactivo'),
        (N'Marcos', N'Rivera Aguilar', N'GYM-SOC-0064', N'7362-0594', N'socio064@ejemplo.test', N'2026-02-28', N'activo'),
        (N'Pablo', N'Zelaya Aguilar', N'GYM-SOC-0065', N'7363-0590', N'socio065@ejemplo.test', N'2026-09-27', N'activo'),
        (N'Mateo', N'Torres Vásquez', N'GYM-SOC-0066', N'7583-0193', N'socio066@ejemplo.test', N'2026-06-08', N'activo'),
        (N'Santiago', N'Santos López', N'GYM-SOC-0067', N'7402-0491', N'socio067@ejemplo.test', N'2025-07-10', N'activo'),
        (N'Marcos', N'Aguilar Figueroa', N'GYM-SOC-0068', N'7861-6085', N'socio068@ejemplo.test', N'2026-02-14', N'activo'),
        (N'Renata', N'Morales Castillo', N'GYM-SOC-0069', N'7030-9002', NULL, N'2025-12-16', N'inactivo'),
        (N'Santiago', N'Morales Escobar', N'GYM-SOC-0070', N'7016-2308', N'socio070@ejemplo.test', N'2025-11-26', N'activo'),
        (N'Gabriel', N'Umanzor Rivas', N'GYM-SOC-0071', N'7995-2691', N'socio071@ejemplo.test', N'2026-11-09', N'inactivo'),
        (N'Nicolás', N'Delgado Guzmán', N'GYM-SOC-0072', N'7130-5840', N'socio072@ejemplo.test', N'2026-07-13', N'activo'),
        (N'Camila', N'Castillo Guzmán', N'GYM-SOC-0073', N'7918-6572', N'socio073@ejemplo.test', N'2025-08-20', N'activo'),
        (N'Esteban', N'Tejada Acosta', N'GYM-SOC-0074', N'7121-1995', N'socio074@ejemplo.test', N'2026-04-10', N'activo'),
        (N'Beatriz', N'Espinoza Santos', N'GYM-SOC-0075', N'7960-8992', N'socio075@ejemplo.test', N'2026-04-27', N'activo'),
        (N'Natalia', N'Tejada Aguilar', N'GYM-SOC-0076', N'7894-9802', NULL, N'2026-04-24', N'activo'),
        (N'David', N'Campos Portillo', N'GYM-SOC-0077', N'7010-5243', N'socio077@ejemplo.test', N'2026-09-09', N'activo'),
        (N'Carlos', N'Zelaya Jiménez', N'GYM-SOC-0078', N'7310-5855', N'socio078@ejemplo.test', N'2026-07-13', N'activo'),
        (N'Fernando', N'Acosta Hernández', N'GYM-SOC-0079', N'7288-6917', N'socio079@ejemplo.test', N'2026-08-07', N'activo'),
        (N'David', N'Mejía Barahona', N'GYM-SOC-0080', N'7992-3407', N'socio080@ejemplo.test', N'2025-06-30', N'inactivo'),
        (N'Olivia', N'Fuentes Portillo', N'GYM-SOC-0081', N'7115-1464', N'socio081@ejemplo.test', N'2026-05-13', N'inactivo'),
        (N'Javier', N'Escobar Portillo', N'GYM-SOC-0082', N'7817-2362', N'socio082@ejemplo.test', N'2025-06-19', N'activo'),
        (N'Isabel', N'Umanzor Zelaya', N'GYM-SOC-0083', N'7541-3837', N'socio083@ejemplo.test', N'2025-11-24', N'activo'),
        (N'Santiago', N'Jiménez Mejía', N'GYM-SOC-0084', N'7581-8450', N'socio084@ejemplo.test', N'2025-06-27', N'activo'),
        (N'Gabriela', N'Castillo Ortiz', N'GYM-SOC-0085', N'7421-6258', N'socio085@ejemplo.test', N'2026-08-31', N'activo'),
        (N'Diego', N'Espinoza Mejía', N'GYM-SOC-0086', N'7063-6686', N'socio086@ejemplo.test', N'2025-08-26', N'activo'),
        (N'Andrea', N'Santos Guzmán', N'GYM-SOC-0087', N'7218-9452', N'socio087@ejemplo.test', N'2025-11-16', N'activo'),
        (N'Fernando', N'Rivera Castillo', N'GYM-SOC-0088', N'7087-6207', N'socio088@ejemplo.test', N'2026-02-02', N'activo'),
        (N'Marcos', N'Aguilar Hernández', N'GYM-SOC-0089', N'7859-1415', N'socio089@ejemplo.test', N'2026-07-25', N'activo'),
        (N'Esteban', N'Rivera Portillo', N'GYM-SOC-0090', N'7733-1876', NULL, N'2026-09-29', N'activo'),
        (N'Renata', N'Hernández Granados', N'GYM-SOC-0091', N'7317-0203', N'socio091@ejemplo.test', N'2026-08-30', N'activo'),
        (N'Mateo', N'Espinoza Molina', N'GYM-SOC-0092', N'7479-9384', N'socio092@ejemplo.test', N'2025-12-19', N'activo'),
        (N'Isabel', N'Ortiz Escobar', N'GYM-SOC-0093', N'7024-4676', N'socio093@ejemplo.test', N'2026-01-06', N'inactivo'),
        (N'Sofía', N'Fuentes Ortiz', N'GYM-SOC-0094', N'7785-7140', N'socio094@ejemplo.test', N'2026-10-01', N'activo'),
        (N'Paola', N'Castillo Espinoza', N'GYM-SOC-0095', N'7193-6949', N'socio095@ejemplo.test', N'2025-11-17', N'activo'),
        (N'Diego', N'Pineda Herrera', N'GYM-SOC-0096', N'7304-0526', N'socio096@ejemplo.test', N'2025-09-17', N'activo'),
        (N'Adriana', N'Benítez Guzmán', N'GYM-SOC-0097', N'7941-6243', N'socio097@ejemplo.test', N'2026-10-13', N'activo'),
        (N'Carlos', N'Aguilar Campos', N'GYM-SOC-0098', N'7614-2190', N'socio098@ejemplo.test', N'2026-03-17', N'activo'),
        (N'Andrea', N'Torres Fuentes', N'GYM-SOC-0099', N'7526-6593', N'socio099@ejemplo.test', N'2026-07-27', N'activo'),
        (N'Paola', N'Ibarra Fuentes', N'GYM-SOC-0100', N'7465-5873', N'socio100@ejemplo.test', N'2026-11-07', N'activo'),

        -- Ultimo grupo de socios
        (N'Olivia', N'Molina Jiménez', N'GYM-SOC-0101', N'7545-4444', NULL, N'2025-12-12', N'inactivo'),
        (N'Natalia', N'Salazar Hernández', N'GYM-SOC-0102', N'7586-1783', N'socio102@ejemplo.test', N'2026-08-12', N'activo'),
        (N'Ricardo', N'Molina Rivera', N'GYM-SOC-0103', N'7844-7366', N'socio103@ejemplo.test', N'2025-08-10', N'activo'),
        (N'Emilio', N'Jiménez Lara', N'GYM-SOC-0104', N'7286-7777', N'socio104@ejemplo.test', N'2026-02-18', N'activo'),
        (N'Santiago', N'López Fuentes', N'GYM-SOC-0105', N'7748-8465', N'socio105@ejemplo.test', N'2026-05-17', N'activo'),
        (N'Fernando', N'Espinoza Fuentes', N'GYM-SOC-0106', N'7139-3844', N'socio106@ejemplo.test', N'2025-01-31', N'activo'),
        (N'Lucía', N'Molina Salazar', N'GYM-SOC-0107', N'7083-4428', N'socio107@ejemplo.test', N'2026-03-17', N'activo'),
        (N'Santiago', N'Umanzor Portillo', N'GYM-SOC-0108', N'7253-2111', N'socio108@ejemplo.test', N'2025-11-07', N'activo'),
        (N'Olivia', N'Valencia Granados', N'GYM-SOC-0109', N'7669-2907', N'socio109@ejemplo.test', N'2025-10-15', N'activo'),
        (N'Diego', N'Zelaya López', N'GYM-SOC-0110', N'7774-7729', N'socio110@ejemplo.test', N'2025-07-06', N'inactivo'),
        (N'Valentina', N'Campos Zelaya', N'GYM-SOC-0111', N'7725-8792', N'socio111@ejemplo.test', N'2026-08-27', N'inactivo'),
        (N'Gabriela', N'Vásquez Espinoza', N'GYM-SOC-0112', N'7148-8599', N'socio112@ejemplo.test', N'2026-11-01', N'activo'),
        (N'Daniela', N'Espinoza Zelaya', N'GYM-SOC-0113', N'7518-1682', NULL, N'2026-06-20', N'activo'),
        (N'Olivia', N'Vásquez Campos', N'GYM-SOC-0114', N'7906-5327', N'socio114@ejemplo.test', N'2026-08-25', N'activo'),
        (N'Fabiana', N'Campos Ibarra', N'GYM-SOC-0115', N'7713-7816', N'socio115@ejemplo.test', N'2026-10-27', N'activo'),
        (N'Víctor', N'Zelaya Aguilar', N'GYM-SOC-0116', N'7446-0657', N'socio116@ejemplo.test', N'2025-11-08', N'inactivo'),
        (N'Karla', N'Fuentes Molina', N'GYM-SOC-0117', N'7756-4661', N'socio117@ejemplo.test', N'2026-08-29', N'activo'),
        (N'Pablo', N'Escobar López', N'GYM-SOC-0118', N'7303-3152', N'socio118@ejemplo.test', N'2025-12-15', N'activo'),
        (N'David', N'Espinoza López', N'GYM-SOC-0119', N'7074-8944', N'socio119@ejemplo.test', N'2026-10-28', N'activo'),
        (N'Javier', N'Portillo Vásquez', N'GYM-SOC-0120', N'7690-3916', N'socio120@ejemplo.test', N'2026-09-26', N'activo'),
        (N'Mateo', N'Guzmán Tejada', N'GYM-SOC-0121', N'7119-9844', N'socio121@ejemplo.test', N'2026-11-09', N'inactivo'),
        (N'Claudia', N'Ibarra Ortiz', N'GYM-SOC-0122', N'7693-3530', N'socio122@ejemplo.test', N'2025-11-11', N'activo'),
        (N'Andrea', N'Quinteros Morales', N'GYM-SOC-0123', N'7535-1817', N'socio123@ejemplo.test', N'2025-06-19', N'inactivo'),
        (N'Camila', N'López Santos', N'GYM-SOC-0124', N'7165-1853', N'socio124@ejemplo.test', N'2025-10-05', N'activo'),
        (N'Marcos', N'Portillo Acosta', N'GYM-SOC-0125', N'7128-1187', N'socio125@ejemplo.test', N'2026-02-10', N'activo'),
        (N'Sofía', N'Portillo Espinoza', N'GYM-SOC-0126', N'7255-4682', N'socio126@ejemplo.test', N'2025-12-21', N'activo'),
        (N'Santiago', N'Delgado Navarro', N'GYM-SOC-0127', N'7291-2144', N'socio127@ejemplo.test', N'2025-04-07', N'activo'),
        (N'Camila', N'López Duarte', N'GYM-SOC-0128', N'7039-5779', N'socio128@ejemplo.test', N'2026-06-17', N'activo'),
        (N'Karla', N'Rivera Tejada', N'GYM-SOC-0129', N'7618-9714', N'socio129@ejemplo.test', N'2026-05-17', N'activo'),
        (N'Esteban', N'Benítez Campos', N'GYM-SOC-0130', N'7896-3544', N'socio130@ejemplo.test', N'2025-01-23', N'activo'),
        (N'Emilio', N'Navarro Quinteros', N'GYM-SOC-0131', N'7430-1798', NULL, N'2026-10-18', N'inactivo'),
        (N'Daniela', N'Barahona Quinteros', N'GYM-SOC-0132', N'7971-7215', N'socio132@ejemplo.test', N'2026-11-01', N'activo'),
        (N'Andrés', N'Herrera López', N'GYM-SOC-0133', N'7067-9424', N'socio133@ejemplo.test', N'2025-10-18', N'activo'),
        (N'Sofía', N'Barahona Figueroa', N'GYM-SOC-0134', N'7280-4510', N'socio134@ejemplo.test', N'2026-09-28', N'inactivo'),
        (N'Santiago', N'Castillo Guzmán', N'GYM-SOC-0135', N'7522-5549', NULL, N'2026-08-27', N'activo'),
        (N'Ricardo', N'Espinoza Ortiz', N'GYM-SOC-0136', N'7435-2425', N'socio136@ejemplo.test', N'2025-09-26', N'activo'),
        (N'Olivia', N'Campos Escobar', N'GYM-SOC-0137', N'7876-9804', N'socio137@ejemplo.test', N'2026-06-20', N'activo'),
        (N'Pablo', N'Granados Navarro', N'GYM-SOC-0138', N'7047-8262', N'socio138@ejemplo.test', N'2025-10-30', N'activo'),
        (N'Beatriz', N'Acosta Portillo', N'GYM-SOC-0139', N'7035-6775', N'socio139@ejemplo.test', N'2025-11-22', N'activo'),
        (N'Isabel', N'Lara Valencia', N'GYM-SOC-0140', N'7106-0322', N'socio140@ejemplo.test', N'2026-10-08', N'activo');


    IF (SELECT COUNT(*) FROM #SociosExtra) <> 140
    BEGIN
        ;THROW 51005, 'El lote de socios debe contener 140 filas.', 1;
    END;

    -- Reejecutable: solo se agregan documentos no existentes.
    INSERT INTO dbo.Socio
        (nombre, apellido, documento, telefono, email, fecha_registro, estado)
    SELECT x.nombre, x.apellido, x.documento, x.telefono, x.email,
           x.fecha_registro, x.estado
    FROM #SociosExtra AS x
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Socio AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.documento = x.documento
    );

    -- Si el documento ya existia, debe corresponder al mismo socio.
    IF EXISTS (
        SELECT 1 FROM #SociosExtra AS x
        JOIN dbo.Socio AS s ON s.documento = x.documento
        WHERE s.nombre <> x.nombre OR s.apellido <> x.apellido
           OR s.telefono <> x.telefono OR s.fecha_registro <> x.fecha_registro
           OR s.estado <> x.estado
           OR ISNULL(s.email, N'') <> ISNULL(x.email, N'')
    )
    BEGIN
        ;THROW 51026, 'Socio existente con datos distintos del lote de Power BI.', 1;
    END;

    -- ------------------------------------------------------------------------
    -- 2. SESIONCLASE: 70 sesiones, enlazadas por nombres de clase
    -- y correo del entrenador, NO por numeros IDENTITY.
    -- Clave natural del lote: clase + entrenador + fecha/hora de inicio.
    -- ------------------------------------------------------------------------
    CREATE TABLE #SesionesExtra (
        nombre_clase NVARCHAR(50) NOT NULL,
        email_entrenador NVARCHAR(100) NOT NULL,
        inicio DATETIME2(0) NOT NULL,
        fin DATETIME2(0) NOT NULL,
        cupo_maximo INT NOT NULL,
        estado NVARCHAR(15) NOT NULL,
        PRIMARY KEY (nombre_clase, email_entrenador, inicio)
    );

    INSERT INTO #SesionesExtra
        (nombre_clase, email_entrenador, inicio, fin, cupo_maximo, estado)
    VALUES


        -- Sesiones de 2026-06
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-06-07T17:00:00', N'2026-06-07T18:15:00', 24, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-10T17:15:00', 6, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-06-11T17:00:00', N'2026-06-11T18:00:00', 10, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-06-13T18:00:00', N'2026-06-13T19:15:00', 20, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-06-15T17:00:00', N'2026-06-15T18:00:00', 24, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-06-19T06:30:00', N'2026-06-19T07:15:00', 14, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-21T07:45:00', 6, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-06-25T16:30:00', N'2026-06-25T17:15:00', 16, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-06-27T16:30:00', N'2026-06-27T17:30:00', 22, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-28T09:15:00', 24, N'finalizada'),

        -- Sesiones de 2026-07
        (N'Spinning', N'carlos.lopez@example.com', N'2026-07-03T09:15:00', N'2026-07-03T10:45:00', 25, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-07-05T17:00:00', N'2026-07-05T18:00:00', 28, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-07-06T09:00:00', 20, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-11T07:30:00', 10, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-07-13T17:30:00', 6, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-07-15T16:30:00', N'2026-07-15T18:00:00', 12, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-07-16T08:00:00', N'2026-07-16T09:30:00', 16, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-07-18T06:30:00', N'2026-07-18T07:45:00', 12, N'cancelada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-07-20T08:00:00', N'2026-07-20T09:00:00', 12, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-21T19:15:00', 28, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-07-28T18:00:00', N'2026-07-28T18:45:00', 6, N'finalizada'),

        -- Sesiones de 2026-08
        (N'Pilates', N'sofia.castro@example.com', N'2026-08-02T16:30:00', N'2026-08-02T17:30:00', 15, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-08-06T19:45:00', 8, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-08-07T08:00:00', N'2026-08-07T09:30:00', 6, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-09T19:00:00', N'2026-08-09T20:15:00', 10, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-11T08:00:00', N'2026-08-11T09:00:00', 28, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-08-12T17:00:00', N'2026-08-12T18:15:00', 22, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-08-16T18:00:00', N'2026-08-16T18:45:00', 8, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-08-17T08:00:00', N'2026-08-17T09:30:00', 20, N'cancelada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-08-20T19:00:00', N'2026-08-20T20:15:00', 6, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-22T09:00:00', 8, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-08-26T09:15:00', N'2026-08-26T10:15:00', 14, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-08-28T08:00:00', N'2026-08-28T09:30:00', 8, N'finalizada'),

        -- Sesiones de 2026-09
        (N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-09-03T17:45:00', 16, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-09-04T09:15:00', N'2026-09-04T10:15:00', 28, N'cancelada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-09-06T19:00:00', N'2026-09-06T19:45:00', 14, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-07T19:00:00', 16, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-09-08T18:00:00', N'2026-09-08T19:30:00', 24, N'cancelada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-09T07:30:00', 10, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-09-12T09:15:00', N'2026-09-12T10:15:00', 15, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-09-14T18:30:00', 6, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-15T17:45:00', 8, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-16T17:00:00', N'2026-09-16T18:30:00', 14, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-09-17T08:00:00', N'2026-09-17T08:45:00', 28, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-21T10:30:00', 22, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-09-28T17:00:00', N'2026-09-28T18:15:00', 18, N'finalizada'),

        -- Sesiones de 2026-10
        (N'Yoga', N'ana.martinez@example.com', N'2026-10-08T17:00:00', N'2026-10-08T18:00:00', 20, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-09T08:00:00', 12, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-11T07:45:00', 25, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-12T06:30:00', N'2026-10-12T08:00:00', 16, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-13T19:30:00', 25, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-14T10:30:00', 24, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-10-16T08:00:00', N'2026-10-16T09:00:00', 25, N'cancelada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-10-19T19:00:00', N'2026-10-19T20:00:00', 14, N'finalizada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-10-21T17:00:00', N'2026-10-21T17:45:00', 12, N'cancelada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-22T10:00:00', 6, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-10-28T19:00:00', N'2026-10-28T20:15:00', 14, N'finalizada'),

        -- Sesiones de 2026-11
        (N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-11-02T10:15:00', 25, N'finalizada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-11-04T08:00:00', N'2026-11-04T09:30:00', 28, N'finalizada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-05T17:00:00', N'2026-11-05T17:45:00', 14, N'cancelada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-08T17:30:00', 22, N'finalizada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-11-10T18:00:00', N'2026-11-10T19:30:00', 18, N'finalizada'),
        (N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-14T17:45:00', 24, N'programada'),
        (N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-11-15T07:30:00', 8, N'programada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-11-18T08:00:00', N'2026-11-18T09:30:00', 14, N'programada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-11-19T19:00:00', N'2026-11-19T19:45:00', 28, N'cancelada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-11-20T17:00:00', N'2026-11-20T18:15:00', 10, N'programada'),
        (N'Yoga', N'ana.martinez@example.com', N'2026-11-21T19:00:00', N'2026-11-21T20:30:00', 16, N'programada'),
        (N'Spinning', N'carlos.lopez@example.com', N'2026-11-24T06:30:00', N'2026-11-24T07:45:00', 18, N'programada'),
        (N'Zumba', N'lucia.hernandez@example.com', N'2026-11-27T16:30:00', N'2026-11-27T17:30:00', 24, N'programada');


    IF (SELECT COUNT(*) FROM #SesionesExtra) <> 70
    BEGIN
        ;THROW 51006, 'El lote de sesiones debe contener 70 filas.', 1;
    END;

    -- Una sesion equivale a una combinacion de clase, entrenador e inicio.
    -- No se modifica la sesion si ya existe.
    IF EXISTS (
        SELECT 1
        FROM #SesionesExtra AS x
        LEFT JOIN dbo.Clase AS c ON c.nombre = x.nombre_clase
        LEFT JOIN dbo.Entrenador AS e ON e.email = x.email_entrenador
        WHERE c.id_clase IS NULL OR e.id_entrenador IS NULL
    )
    BEGIN
        ;THROW 51007, 'Clase o entrenador inexistente en las sesiones adicionales.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM #SesionesExtra AS x
        JOIN dbo.SesionClase AS sc ON sc.inicio = x.inicio
        JOIN dbo.Clase AS c ON c.id_clase = sc.id_clase
        JOIN dbo.Entrenador AS e ON e.id_entrenador = sc.id_entrenador
        WHERE c.nombre = x.nombre_clase AND e.email = x.email_entrenador
        GROUP BY x.nombre_clase, x.email_entrenador, x.inicio
        HAVING COUNT(*) > 1
    )
    BEGIN
        ;THROW 51008, 'Hay sesiones duplicadas con misma clase, entrenador e inicio.', 1;
    END;

    INSERT INTO dbo.SesionClase
        (id_clase, id_entrenador, inicio, fin, cupo_maximo, estado)
    SELECT c.id_clase, e.id_entrenador, x.inicio, x.fin,
           x.cupo_maximo, x.estado
    FROM #SesionesExtra AS x
    JOIN dbo.Clase AS c ON c.nombre = x.nombre_clase
    JOIN dbo.Entrenador AS e ON e.email = x.email_entrenador
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SesionClase AS sc WITH (UPDLOCK, HOLDLOCK)
        WHERE sc.id_clase = c.id_clase AND sc.id_entrenador = e.id_entrenador
          AND sc.inicio = x.inicio
    );

    -- Evitar declarar como correcta una sesion existente con datos distintos.
    IF EXISTS (
        SELECT 1 FROM #SesionesExtra AS x
        JOIN dbo.Clase AS c ON c.nombre = x.nombre_clase
        JOIN dbo.Entrenador AS e ON e.email = x.email_entrenador
        JOIN dbo.SesionClase AS sc ON sc.id_clase = c.id_clase
                                  AND sc.id_entrenador = e.id_entrenador
                                  AND sc.inicio = x.inicio
        WHERE sc.fin <> x.fin OR sc.cupo_maximo <> x.cupo_maximo
           OR sc.estado <> x.estado
    )
    BEGIN
        ;THROW 51027, 'Sesion existente con fin, cupo o estado distinto del lote.', 1;
    END;

    -- ------------------------------------------------------------------------
    -- 3. MEMBRESIASOCIO: 140 filas nuevas; buscan socio por documento y
    -- plan por nombre. Puede haber renovaciones (misma persona, otra fecha).
    -- fecha_fin es el primer dia SIN cobertura, como en datos_prueba.sql.
    -- ------------------------------------------------------------------------
    CREATE TABLE #MembresiasExtra (
        documento NVARCHAR(20) NOT NULL,
        nombre_plan NVARCHAR(50) NOT NULL,
        fecha_inicio DATE NOT NULL,
        fecha_fin DATE NOT NULL,
        precio_acordado DECIMAL(10,2) NOT NULL,
        estado NVARCHAR(10) NOT NULL,
        PRIMARY KEY (documento, fecha_inicio)
    );

    INSERT INTO #MembresiasExtra
        (documento, nombre_plan, fecha_inicio, fecha_fin, precio_acordado, estado)
    VALUES


        -- Membresias de los socios nuevos
        (N'GYM-SOC-0001', N'Mensual', N'2026-11-01', N'2026-12-01', 26.00, N'activa'),
        (N'GYM-SOC-0002', N'Mensual', N'2026-09-08', N'2026-10-08', 25.00, N'activa'),
        (N'GYM-SOC-0003', N'Mensual', N'2026-10-23', N'2026-11-22', 25.00, N'activa'),
        (N'GYM-SOC-0004', N'Semestral', N'2026-10-22', N'2027-04-20', 120.00, N'activa'),
        (N'GYM-SOC-0005', N'Trimestral', N'2026-08-18', N'2026-11-16', 65.00, N'cancelada'),
        (N'GYM-SOC-0006', N'Mensual', N'2026-07-03', N'2026-08-02', 25.00, N'cancelada'),
        (N'GYM-SOC-0007', N'Trimestral', N'2026-08-26', N'2026-11-24', 67.00, N'cancelada'),
        (N'GYM-SOC-0008', N'Mensual', N'2026-10-23', N'2026-11-22', 25.00, N'activa'),
        (N'GYM-SOC-0009', N'Semestral', N'2026-06-05', N'2026-12-02', 110.00, N'activa'),
        (N'GYM-SOC-0010', N'Trimestral', N'2026-10-15', N'2027-01-13', 67.00, N'activa'),
        (N'GYM-SOC-0011', N'Mensual', N'2026-11-01', N'2026-12-01', 25.00, N'activa'),
        (N'GYM-SOC-0012', N'Trimestral', N'2026-08-27', N'2026-11-25', 67.00, N'activa'),
        (N'GYM-SOC-0013', N'Trimestral', N'2026-11-05', N'2027-02-03', 70.00, N'activa'),
        (N'GYM-SOC-0014', N'Mensual', N'2026-08-11', N'2026-09-10', 25.00, N'activa'),
        (N'GYM-SOC-0015', N'Mensual', N'2026-11-10', N'2026-12-10', 27.00, N'activa'),
        (N'GYM-SOC-0016', N'Trimestral', N'2026-08-01', N'2026-10-30', 65.00, N'activa'),
        (N'GYM-SOC-0017', N'Mensual', N'2026-08-26', N'2026-09-25', 24.00, N'activa'),
        (N'GYM-SOC-0018', N'Trimestral', N'2026-07-26', N'2026-10-24', 60.00, N'activa'),
        (N'GYM-SOC-0019', N'Trimestral', N'2026-10-13', N'2027-01-11', 65.00, N'activa'),
        (N'GYM-SOC-0020', N'Semestral', N'2026-08-08', N'2027-02-04', 120.00, N'activa'),
        (N'GYM-SOC-0021', N'Mensual', N'2026-10-30', N'2026-11-29', 25.00, N'activa'),
        (N'GYM-SOC-0022', N'Trimestral', N'2026-07-21', N'2026-10-19', 63.00, N'activa'),
        (N'GYM-SOC-0023', N'Mensual', N'2026-10-19', N'2026-11-18', 25.00, N'activa'),
        (N'GYM-SOC-0024', N'Semestral', N'2026-06-19', N'2026-12-16', 120.00, N'activa'),
        (N'GYM-SOC-0025', N'Semestral', N'2026-08-15', N'2027-02-11', 120.00, N'activa'),
        (N'GYM-SOC-0026', N'Semestral', N'2026-06-08', N'2026-12-05', 115.00, N'activa'),
        (N'GYM-SOC-0027', N'Trimestral', N'2026-07-15', N'2026-10-13', 63.00, N'activa'),
        (N'GYM-SOC-0028', N'Trimestral', N'2026-10-20', N'2027-01-18', 63.00, N'activa'),
        (N'GYM-SOC-0029', N'Semestral', N'2026-11-04', N'2027-05-03', 110.00, N'activa'),
        (N'GYM-SOC-0030', N'Mensual', N'2026-09-11', N'2026-10-11', 25.00, N'activa'),
        (N'GYM-SOC-0031', N'Trimestral', N'2026-08-10', N'2026-11-08', 65.00, N'activa'),
        (N'GYM-SOC-0032', N'Trimestral', N'2026-10-26', N'2027-01-24', 63.00, N'activa'),
        (N'GYM-SOC-0033', N'Trimestral', N'2026-10-10', N'2027-01-08', 65.00, N'activa'),
        (N'GYM-SOC-0034', N'Trimestral', N'2026-10-20', N'2027-01-18', 65.00, N'cancelada'),
        (N'GYM-SOC-0035', N'Mensual', N'2026-10-22', N'2026-11-21', 23.00, N'activa'),
        (N'GYM-SOC-0036', N'Semestral', N'2026-09-28', N'2027-03-27', 110.00, N'activa'),
        (N'GYM-SOC-0037', N'Mensual', N'2026-08-18', N'2026-09-17', 23.00, N'cancelada'),
        (N'GYM-SOC-0038', N'Semestral', N'2026-11-02', N'2027-05-01', 110.00, N'activa'),
        (N'GYM-SOC-0039', N'Mensual', N'2026-10-07', N'2026-11-06', 24.00, N'activa'),
        (N'GYM-SOC-0040', N'Mensual', N'2026-10-29', N'2026-11-28', 25.00, N'activa'),
        (N'GYM-SOC-0041', N'Trimestral', N'2026-10-07', N'2027-01-05', 65.00, N'activa'),
        (N'GYM-SOC-0042', N'Trimestral', N'2026-10-17', N'2027-01-15', 63.00, N'activa'),
        (N'GYM-SOC-0043', N'Mensual', N'2026-11-11', N'2026-12-11', 25.00, N'activa'),
        (N'GYM-SOC-0044', N'Trimestral', N'2026-08-10', N'2026-11-08', 63.00, N'activa'),
        (N'GYM-SOC-0045', N'Mensual', N'2026-09-25', N'2026-10-25', 25.00, N'cancelada'),
        (N'GYM-SOC-0046', N'Mensual', N'2026-07-01', N'2026-07-31', 25.00, N'activa'),
        (N'GYM-SOC-0047', N'Trimestral', N'2026-08-05', N'2026-11-03', 70.00, N'cancelada'),
        (N'GYM-SOC-0048', N'Mensual', N'2026-08-26', N'2026-09-25', 27.00, N'activa'),
        (N'GYM-SOC-0049', N'Trimestral', N'2026-09-21', N'2026-12-20', 67.00, N'activa'),
        (N'GYM-SOC-0050', N'Trimestral', N'2026-10-08', N'2027-01-06', 65.00, N'activa'),

        -- Membresias en meses y planes variados
        (N'GYM-SOC-0051', N'Trimestral', N'2026-08-18', N'2026-11-16', 67.00, N'cancelada'),
        (N'GYM-SOC-0052', N'Trimestral', N'2026-10-24', N'2027-01-22', 70.00, N'activa'),
        (N'GYM-SOC-0053', N'Semestral', N'2026-11-06', N'2027-05-05', 120.00, N'activa'),
        (N'GYM-SOC-0054', N'Semestral', N'2026-10-20', N'2027-04-18', 120.00, N'activa'),
        (N'GYM-SOC-0055', N'Trimestral', N'2026-11-06', N'2027-02-04', 60.00, N'activa'),
        (N'GYM-SOC-0056', N'Mensual', N'2026-06-01', N'2026-07-01', 27.00, N'activa'),
        (N'GYM-SOC-0057', N'Trimestral', N'2026-10-16', N'2027-01-14', 60.00, N'activa'),
        (N'GYM-SOC-0058', N'Mensual', N'2026-10-24', N'2026-11-23', 25.00, N'cancelada'),
        (N'GYM-SOC-0059', N'Mensual', N'2026-09-20', N'2026-10-20', 27.00, N'activa'),
        (N'GYM-SOC-0060', N'Semestral', N'2026-06-20', N'2026-12-17', 125.00, N'cancelada'),
        (N'GYM-SOC-0061', N'Mensual', N'2026-09-05', N'2026-10-05', 25.00, N'activa'),
        (N'GYM-SOC-0062', N'Trimestral', N'2026-10-22', N'2027-01-20', 67.00, N'cancelada'),
        (N'GYM-SOC-0063', N'Mensual', N'2026-10-21', N'2026-11-20', 25.00, N'cancelada'),
        (N'GYM-SOC-0064', N'Mensual', N'2026-09-10', N'2026-10-10', 25.00, N'activa'),
        (N'GYM-SOC-0065', N'Mensual', N'2026-10-03', N'2026-11-02', 27.00, N'cancelada'),
        (N'GYM-SOC-0066', N'Mensual', N'2026-08-03', N'2026-09-02', 25.00, N'activa'),
        (N'GYM-SOC-0067', N'Trimestral', N'2026-06-01', N'2026-08-30', 65.00, N'activa'),
        (N'GYM-SOC-0068', N'Mensual', N'2026-09-26', N'2026-10-26', 27.00, N'activa'),
        (N'GYM-SOC-0069', N'Mensual', N'2026-10-03', N'2026-11-02', 26.00, N'activa'),
        (N'GYM-SOC-0070', N'Mensual', N'2026-10-18', N'2026-11-17', 26.00, N'activa'),
        (N'GYM-SOC-0071', N'Trimestral', N'2026-11-12', N'2027-02-10', 70.00, N'cancelada'),
        (N'GYM-SOC-0072', N'Semestral', N'2026-11-06', N'2027-05-05', 115.00, N'activa'),
        (N'GYM-SOC-0073', N'Mensual', N'2026-09-07', N'2026-10-07', 26.00, N'activa'),
        (N'GYM-SOC-0074', N'Trimestral', N'2026-06-27', N'2026-09-25', 60.00, N'activa'),
        (N'GYM-SOC-0075', N'Trimestral', N'2026-10-16', N'2027-01-14', 65.00, N'activa'),
        (N'GYM-SOC-0076', N'Mensual', N'2026-11-09', N'2026-12-09', 23.00, N'activa'),
        (N'GYM-SOC-0077', N'Trimestral', N'2026-09-13', N'2026-12-12', 60.00, N'activa'),
        (N'GYM-SOC-0078', N'Mensual', N'2026-10-06', N'2026-11-05', 24.00, N'activa'),
        (N'GYM-SOC-0079', N'Trimestral', N'2026-11-01', N'2027-01-30', 67.00, N'cancelada'),
        (N'GYM-SOC-0080', N'Mensual', N'2026-10-09', N'2026-11-08', 27.00, N'cancelada'),
        (N'GYM-SOC-0081', N'Mensual', N'2026-10-13', N'2026-11-12', 27.00, N'cancelada'),
        (N'GYM-SOC-0082', N'Mensual', N'2026-11-07', N'2026-12-07', 24.00, N'activa'),
        (N'GYM-SOC-0083', N'Trimestral', N'2026-08-01', N'2026-10-30', 63.00, N'activa'),
        (N'GYM-SOC-0084', N'Mensual', N'2026-06-22', N'2026-07-22', 24.00, N'activa'),
        (N'GYM-SOC-0085', N'Mensual', N'2026-09-06', N'2026-10-06', 27.00, N'activa'),
        (N'GYM-SOC-0086', N'Trimestral', N'2026-10-20', N'2027-01-18', 65.00, N'activa'),
        (N'GYM-SOC-0087', N'Semestral', N'2026-07-04', N'2026-12-31', 120.00, N'activa'),
        (N'GYM-SOC-0088', N'Semestral', N'2026-07-18', N'2027-01-14', 120.00, N'activa'),
        (N'GYM-SOC-0089', N'Mensual', N'2026-07-29', N'2026-08-28', 23.00, N'activa'),
        (N'GYM-SOC-0090', N'Semestral', N'2026-10-02', N'2027-03-31', 115.00, N'activa'),
        (N'GYM-SOC-0091', N'Mensual', N'2026-08-31', N'2026-09-30', 27.00, N'activa'),
        (N'GYM-SOC-0092', N'Semestral', N'2026-06-27', N'2026-12-24', 120.00, N'activa'),
        (N'GYM-SOC-0093', N'Mensual', N'2026-09-08', N'2026-10-08', 24.00, N'cancelada'),
        (N'GYM-SOC-0094', N'Trimestral', N'2026-10-08', N'2027-01-06', 63.00, N'activa'),
        (N'GYM-SOC-0095', N'Trimestral', N'2026-09-05', N'2026-12-04', 65.00, N'activa'),
        (N'GYM-SOC-0096', N'Trimestral', N'2026-10-21', N'2027-01-19', 65.00, N'activa'),
        (N'GYM-SOC-0097', N'Mensual', N'2026-11-02', N'2026-12-02', 24.00, N'activa'),
        (N'GYM-SOC-0098', N'Semestral', N'2026-10-20', N'2027-04-18', 110.00, N'activa'),
        (N'GYM-SOC-0099', N'Mensual', N'2026-07-29', N'2026-08-28', 25.00, N'activa'),
        (N'GYM-SOC-0100', N'Mensual', N'2026-11-10', N'2026-12-10', 25.00, N'activa'),

        -- Membresias adicionales
        (N'GYM-SOC-0101', N'Trimestral', N'2026-06-18', N'2026-09-16', 65.00, N'cancelada'),
        (N'GYM-SOC-0102', N'Mensual', N'2026-08-20', N'2026-09-19', 24.00, N'activa'),
        (N'GYM-SOC-0103', N'Mensual', N'2026-08-27', N'2026-09-26', 24.00, N'activa'),
        (N'GYM-SOC-0104', N'Trimestral', N'2026-10-07', N'2027-01-05', 60.00, N'activa'),
        (N'GYM-SOC-0105', N'Trimestral', N'2026-06-07', N'2026-09-05', 65.00, N'activa'),
        (N'GYM-SOC-0106', N'Semestral', N'2026-07-13', N'2027-01-09', 120.00, N'activa'),
        (N'GYM-SOC-0107', N'Trimestral', N'2026-10-06', N'2027-01-04', 67.00, N'activa'),
        (N'GYM-SOC-0108', N'Mensual', N'2026-09-14', N'2026-10-14', 25.00, N'activa'),
        (N'GYM-SOC-0109', N'Trimestral', N'2026-09-17', N'2026-12-16', 67.00, N'activa'),
        (N'GYM-SOC-0110', N'Mensual', N'2026-06-06', N'2026-07-06', 25.00, N'cancelada'),
        (N'GYM-SOC-0111', N'Semestral', N'2026-10-24', N'2027-04-22', 120.00, N'cancelada'),
        (N'GYM-SOC-0112', N'Mensual', N'2026-11-07', N'2026-12-07', 25.00, N'activa'),
        (N'GYM-SOC-0113', N'Mensual', N'2026-09-11', N'2026-10-11', 23.00, N'cancelada'),
        (N'GYM-SOC-0114', N'Mensual', N'2026-08-29', N'2026-09-28', 27.00, N'activa'),
        (N'GYM-SOC-0115', N'Mensual', N'2026-10-29', N'2026-11-28', 23.00, N'activa'),
        (N'GYM-SOC-0116', N'Mensual', N'2026-10-02', N'2026-11-01', 27.00, N'activa'),
        (N'GYM-SOC-0117', N'Trimestral', N'2026-09-05', N'2026-12-04', 65.00, N'activa'),
        (N'GYM-SOC-0118', N'Mensual', N'2026-06-01', N'2026-07-01', 25.00, N'activa'),
        (N'GYM-SOC-0119', N'Trimestral', N'2026-11-02', N'2027-01-31', 65.00, N'activa'),
        (N'GYM-SOC-0120', N'Trimestral', N'2026-09-27', N'2026-12-26', 63.00, N'activa'),
        (N'GYM-SOC-0121', N'Mensual', N'2026-11-12', N'2026-12-12', 25.00, N'activa'),
        (N'GYM-SOC-0122', N'Trimestral', N'2026-10-22', N'2027-01-20', 67.00, N'activa'),
        (N'GYM-SOC-0123', N'Mensual', N'2026-08-24', N'2026-09-23', 23.00, N'cancelada'),
        (N'GYM-SOC-0124', N'Mensual', N'2026-08-01', N'2026-08-31', 25.00, N'activa'),
        (N'GYM-SOC-0125', N'Mensual', N'2026-11-09', N'2026-12-09', 23.00, N'activa'),
        (N'GYM-SOC-0126', N'Mensual', N'2026-10-07', N'2026-11-06', 24.00, N'activa'),
        (N'GYM-SOC-0127', N'Mensual', N'2026-10-06', N'2026-11-05', 25.00, N'activa'),
        (N'GYM-SOC-0128', N'Trimestral', N'2026-09-09', N'2026-12-08', 65.00, N'activa'),
        (N'GYM-SOC-0129', N'Mensual', N'2026-09-13', N'2026-10-13', 24.00, N'activa'),
        (N'GYM-SOC-0130', N'Trimestral', N'2026-07-13', N'2026-10-11', 70.00, N'activa'),
        (N'GYM-SOC-0131', N'Mensual', N'2026-10-21', N'2026-11-20', 25.00, N'cancelada'),
        (N'GYM-SOC-0132', N'Mensual', N'2026-11-05', N'2026-12-05', 25.00, N'activa'),
        (N'GYM-SOC-0133', N'Mensual', N'2026-10-14', N'2026-11-13', 25.00, N'activa'),
        (N'GYM-SOC-0134', N'Mensual', N'2026-10-07', N'2026-11-06', 24.00, N'cancelada'),
        (N'GYM-SOC-0135', N'Mensual', N'2026-08-30', N'2026-09-29', 25.00, N'cancelada'),
        (N'GYM-SOC-0136', N'Mensual', N'2026-08-05', N'2026-09-04', 27.00, N'activa'),
        (N'GYM-SOC-0137', N'Semestral', N'2026-10-09', N'2027-04-07', 120.00, N'activa'),
        (N'GYM-SOC-0138', N'Trimestral', N'2026-08-13', N'2026-11-11', 70.00, N'activa'),

        -- Renovaciones de socios originales 7 y 8
        (N'PRUEBA-007', N'Trimestral', N'2026-10-02', N'2026-12-31', 65.00, N'activa'),
        (N'PRUEBA-008', N'Trimestral', N'2026-10-16', N'2027-01-14', 63.00, N'activa');


    IF (SELECT COUNT(*) FROM #MembresiasExtra) <> 140
    BEGIN
        ;THROW 51009, 'El lote de membresias debe contener 140 filas.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM #MembresiasExtra AS x
        LEFT JOIN dbo.Socio AS s ON s.documento = x.documento
        LEFT JOIN dbo.PlanMembresia AS p ON p.nombre = x.nombre_plan
        WHERE s.id_socio IS NULL OR p.id_plan IS NULL
    )
    BEGIN
        ;THROW 51010, 'Documento de socio o plan no encontrado para membresia.', 1;
    END;

    -- Una sola membresia con esa fecha de inicio por socio en este lote.
    IF EXISTS (
        SELECT 1 FROM #MembresiasExtra AS x
        JOIN dbo.Socio AS s ON s.documento = x.documento
        JOIN dbo.MembresiaSocio AS m ON m.id_socio = s.id_socio
                                   AND m.fecha_inicio = x.fecha_inicio
        GROUP BY x.documento, x.fecha_inicio
        HAVING COUNT(*) > 1
    )
    BEGIN
        ;THROW 51011, 'Existen membresias ambiguas: socio y fecha de inicio duplicados.', 1;
    END;

    INSERT INTO dbo.MembresiaSocio
        (id_socio, id_plan, fecha_inicio, fecha_fin, precio_acordado, estado)
    SELECT s.id_socio, p.id_plan, x.fecha_inicio, x.fecha_fin,
           x.precio_acordado, x.estado
    FROM #MembresiasExtra AS x
    JOIN dbo.Socio AS s ON s.documento = x.documento
    JOIN dbo.PlanMembresia AS p ON p.nombre = x.nombre_plan
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.MembresiaSocio AS m WITH (UPDLOCK, HOLDLOCK)
        WHERE m.id_socio = s.id_socio AND m.fecha_inicio = x.fecha_inicio
    );

    -- Comprobar que una membresia preexistente tenga los mismos valores.
    IF EXISTS (
        SELECT 1 FROM #MembresiasExtra AS x
        JOIN dbo.Socio AS s ON s.documento = x.documento
        JOIN dbo.MembresiaSocio AS m ON m.id_socio = s.id_socio
                                      AND m.fecha_inicio = x.fecha_inicio
        JOIN dbo.PlanMembresia AS p ON p.id_plan = m.id_plan
        WHERE p.nombre <> x.nombre_plan OR m.fecha_fin <> x.fecha_fin
           OR m.precio_acordado <> x.precio_acordado OR m.estado <> x.estado
    )
    BEGIN
        ;THROW 51028, 'Membresia existente con datos distintos de este lote.', 1;
    END;

    -- ------------------------------------------------------------------------
    -- 4. RESERVA: 279 registros. Cada sesion se busca por
    -- nombre de clase + email del entrenador + instante de inicio.
    -- Se conservan las 21 reservas de datos_prueba.sql.
    -- ------------------------------------------------------------------------
    CREATE TABLE #ReservasExtra (
        documento NVARCHAR(20) NOT NULL,
        nombre_clase NVARCHAR(50) NOT NULL,
        email_entrenador NVARCHAR(100) NOT NULL,
        inicio_sesion DATETIME2(0) NOT NULL,
        fecha_reserva DATETIME2(0) NOT NULL,
        estado NVARCHAR(15) NOT NULL,
        PRIMARY KEY (documento, nombre_clase, email_entrenador,
                     inicio_sesion, fecha_reserva, estado)
    );

    INSERT INTO #ReservasExtra
        (documento, nombre_clase, email_entrenador,
         inicio_sesion, fecha_reserva, estado)
    VALUES


        -- Reservas de sesiones 2026-06
        (N'GYM-SOC-0067', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-05T09:40:00', N'confirmada'),
        (N'GYM-SOC-0009', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-06T18:05:00', N'confirmada'),
        (N'GYM-SOC-0056', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-07T13:10:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-07T15:30:00', N'cancelada'),
        (N'GYM-SOC-0118', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-08T16:15:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Yoga', N'ana.martinez@example.com', N'2026-06-10T16:30:00', N'2026-06-09T08:40:00', N'confirmada'),
        (N'GYM-SOC-0067', N'Pilates', N'sofia.castro@example.com', N'2026-06-11T17:00:00', N'2026-06-09T08:05:00', N'confirmada'),
        (N'GYM-SOC-0067', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-06-15T17:00:00', N'2026-06-07T12:00:00', N'confirmada'),
        (N'GYM-SOC-0118', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-06-15T17:00:00', N'2026-06-14T11:30:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-09T18:00:00', N'confirmada'),
        (N'GYM-SOC-0118', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-10T11:20:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-11T19:50:00', N'confirmada'),
        (N'GYM-SOC-0056', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-12T17:30:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-19T18:50:00', N'confirmada'),
        (N'GYM-SOC-0067', N'Yoga', N'ana.martinez@example.com', N'2026-06-21T07:00:00', N'2026-06-19T20:05:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Zumba', N'lucia.hernandez@example.com', N'2026-06-25T16:30:00', N'2026-06-08T14:55:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Zumba', N'lucia.hernandez@example.com', N'2026-06-25T16:30:00', N'2026-06-20T17:35:00', N'confirmada'),
        (N'GYM-SOC-0084', N'Zumba', N'lucia.hernandez@example.com', N'2026-06-25T16:30:00', N'2026-06-23T15:50:00', N'cancelada'),
        (N'GYM-SOC-0105', N'Pilates', N'sofia.castro@example.com', N'2026-06-27T16:30:00', N'2026-06-12T20:20:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-12T09:40:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-13T11:50:00', N'confirmada'),
        (N'GYM-SOC-0118', N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-24T19:10:00', N'cancelada'),
        (N'GYM-SOC-0067', N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-25T10:55:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Spinning', N'carlos.lopez@example.com', N'2026-06-28T08:00:00', N'2026-06-27T08:15:00', N'confirmada'),

        -- Reservas de sesiones 2026-07
        (N'GYM-SOC-0024', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-06-21T15:10:00', N'confirmada'),
        (N'GYM-SOC-0084', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-06-25T11:40:00', N'confirmada'),
        (N'GYM-SOC-0074', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-06-27T10:40:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-06-27T16:50:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-06-28T13:30:00', N'confirmada'),
        (N'PRUEBA-002', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-07-01T11:20:00', N'cancelada'),
        (N'GYM-SOC-0046', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-07-04T17:20:00', N'confirmada'),
        (N'GYM-SOC-0067', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-06T08:00:00', N'2026-07-05T15:00:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-06-29T08:45:00', N'confirmada'),
        (N'GYM-SOC-0046', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-01T18:05:00', N'confirmada'),
        (N'PRUEBA-002', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-03T20:45:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-07T13:15:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-07T15:55:00', N'confirmada'),
        (N'GYM-SOC-0084', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-08T20:55:00', N'confirmada'),
        (N'GYM-SOC-0074', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-11T06:30:00', N'2026-07-09T15:20:00', N'confirmada'),
        (N'GYM-SOC-0105', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-06-25T13:50:00', N'confirmada'),
        (N'GYM-SOC-0084', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-06-29T18:50:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-07-04T09:55:00', N'confirmada'),
        (N'GYM-SOC-0046', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-07-06T12:40:00', N'confirmada'),
        (N'PRUEBA-002', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-07-09T13:20:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-07-13T16:30:00', N'2026-07-09T16:20:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Yoga', N'ana.martinez@example.com', N'2026-07-15T16:30:00', N'2026-06-28T15:50:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Yoga', N'ana.martinez@example.com', N'2026-07-15T16:30:00', N'2026-07-05T11:15:00', N'cancelada'),
        (N'GYM-SOC-0130', N'Yoga', N'ana.martinez@example.com', N'2026-07-15T16:30:00', N'2026-07-13T10:40:00', N'cancelada'),
        (N'GYM-SOC-0106', N'Yoga', N'ana.martinez@example.com', N'2026-07-15T16:30:00', N'2026-07-14T17:35:00', N'confirmada'),
        (N'PRUEBA-002', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-16T08:00:00', N'2026-07-03T20:35:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-16T08:00:00', N'2026-07-04T08:50:00', N'confirmada'),
        (N'GYM-SOC-0027', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-16T08:00:00', N'2026-07-15T15:25:00', N'confirmada'),
        (N'GYM-SOC-0106', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-18T06:30:00', N'2026-07-13T15:40:00', N'cancelada'),
        (N'GYM-SOC-0087', N'Zumba', N'lucia.hernandez@example.com', N'2026-07-18T06:30:00', N'2026-07-15T16:40:00', N'cancelada'),
        (N'GYM-SOC-0026', N'Yoga', N'ana.martinez@example.com', N'2026-07-20T08:00:00', N'2026-07-01T10:25:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Yoga', N'ana.martinez@example.com', N'2026-07-20T08:00:00', N'2026-07-15T13:40:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-12T14:30:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-12T18:15:00', N'confirmada'),
        (N'PRUEBA-002', N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-13T18:15:00', N'confirmada'),
        (N'GYM-SOC-0027', N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-17T18:45:00', N'confirmada'),
        (N'GYM-SOC-0046', N'Pilates', N'sofia.castro@example.com', N'2026-07-21T18:00:00', N'2026-07-19T10:00:00', N'cancelada'),

        -- Reservas de sesiones 2026-08
        (N'PRUEBA-002', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-07-24T18:55:00', N'confirmada'),
        (N'GYM-SOC-0106', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-07-25T14:50:00', N'cancelada'),
        (N'GYM-SOC-0067', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-07-29T14:50:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-08-01T18:00:00', N'confirmada'),
        (N'GYM-SOC-0066', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-08-03T15:40:00', N'confirmada'),
        (N'GYM-SOC-0136', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-06T19:00:00', N'2026-08-05T20:00:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-09T19:00:00', N'2026-07-21T10:05:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-09T19:00:00', N'2026-07-21T14:45:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-09T19:00:00', N'2026-08-01T16:25:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-08-09T19:00:00', N'2026-08-01T19:20:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Pilates', N'sofia.castro@example.com', N'2026-08-12T17:00:00', N'2026-07-28T10:05:00', N'confirmada'),
        (N'GYM-SOC-0044', N'Pilates', N'sofia.castro@example.com', N'2026-08-12T17:00:00', N'2026-08-11T20:20:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Spinning', N'carlos.lopez@example.com', N'2026-08-16T18:00:00', N'2026-08-03T08:10:00', N'confirmada'),
        (N'PRUEBA-002', N'Spinning', N'carlos.lopez@example.com', N'2026-08-16T18:00:00', N'2026-08-12T12:45:00', N'confirmada'),
        (N'GYM-SOC-0016', N'Zumba', N'lucia.hernandez@example.com', N'2026-08-17T08:00:00', N'2026-08-01T11:50:00', N'cancelada'),
        (N'GYM-SOC-0087', N'Zumba', N'lucia.hernandez@example.com', N'2026-08-17T08:00:00', N'2026-08-11T10:20:00', N'cancelada'),
        (N'GYM-SOC-0031', N'Zumba', N'lucia.hernandez@example.com', N'2026-08-17T08:00:00', N'2026-08-12T15:45:00', N'cancelada'),
        (N'GYM-SOC-0136', N'Spinning', N'carlos.lopez@example.com', N'2026-08-20T19:00:00', N'2026-08-12T15:50:00', N'confirmada'),
        (N'GYM-SOC-0138', N'Spinning', N'carlos.lopez@example.com', N'2026-08-20T19:00:00', N'2026-08-14T11:00:00', N'confirmada'),
        (N'GYM-SOC-0136', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-09T14:55:00', N'confirmada'),
        (N'GYM-SOC-0124', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-12T20:30:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-14T09:40:00', N'confirmada'),
        (N'GYM-SOC-0027', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-14T14:15:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-14T18:50:00', N'confirmada'),
        (N'PRUEBA-006', N'Yoga', N'ana.martinez@example.com', N'2026-08-22T08:00:00', N'2026-08-15T09:25:00', N'confirmada'),
        (N'GYM-SOC-0074', N'Yoga', N'ana.martinez@example.com', N'2026-08-26T09:15:00', N'2026-08-07T14:00:00', N'cancelada'),
        (N'GYM-SOC-0087', N'Yoga', N'ana.martinez@example.com', N'2026-08-26T09:15:00', N'2026-08-12T18:35:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Yoga', N'ana.martinez@example.com', N'2026-08-26T09:15:00', N'2026-08-14T11:25:00', N'confirmada'),
        (N'GYM-SOC-0124', N'Yoga', N'ana.martinez@example.com', N'2026-08-26T09:15:00', N'2026-08-14T18:35:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Pilates', N'sofia.castro@example.com', N'2026-08-28T08:00:00', N'2026-08-14T20:30:00', N'confirmada'),

        -- Reservas de sesiones 2026-09
        (N'GYM-SOC-0092', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-23T16:00:00', N'confirmada'),
        (N'GYM-SOC-0016', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-25T09:00:00', N'confirmada'),
        (N'GYM-SOC-0088', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-25T13:40:00', N'confirmada'),
        (N'GYM-SOC-0017', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-26T14:10:00', N'confirmada'),
        (N'GYM-SOC-0012', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-27T12:20:00', N'confirmada'),
        (N'GYM-SOC-0136', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-27T12:35:00', N'cancelada'),
        (N'GYM-SOC-0048', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-29T15:25:00', N'confirmada'),
        (N'GYM-SOC-0091', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-08-31T11:00:00', N'confirmada'),
        (N'PRUEBA-004', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-09-01T15:15:00', N'confirmada'),
        (N'PRUEBA-007', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-09-01T16:30:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Yoga', N'ana.martinez@example.com', N'2026-09-03T17:00:00', N'2026-09-01T16:55:00', N'confirmada'),
        (N'GYM-SOC-0048', N'Yoga', N'ana.martinez@example.com', N'2026-09-04T09:15:00', N'2026-08-31T10:45:00', N'cancelada'),
        (N'GYM-SOC-0012', N'Yoga', N'ana.martinez@example.com', N'2026-09-04T09:15:00', N'2026-09-03T15:45:00', N'cancelada'),
        (N'GYM-SOC-0138', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-08-20T11:40:00', N'confirmada'),
        (N'GYM-SOC-0074', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-08-25T19:45:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-08-29T11:45:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-08-30T17:45:00', N'confirmada'),
        (N'PRUEBA-007', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-01T12:25:00', N'confirmada'),
        (N'GYM-SOC-0114', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-01T20:15:00', N'confirmada'),
        (N'GYM-SOC-0048', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-03T19:00:00', N'confirmada'),
        (N'GYM-SOC-0027', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-04T18:50:00', N'confirmada'),
        (N'GYM-SOC-0130', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T08:05:00', N'confirmada'),
        (N'GYM-SOC-0061', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T11:40:00', N'cancelada'),
        (N'GYM-SOC-0092', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T13:55:00', N'confirmada'),
        (N'GYM-SOC-0085', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T16:10:00', N'confirmada'),
        (N'GYM-SOC-0117', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T17:05:00', N'confirmada'),
        (N'GYM-SOC-0095', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-07T18:00:00', N'2026-09-06T18:50:00', N'confirmada'),
        (N'GYM-SOC-0091', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-08T18:00:00', N'2026-08-31T13:55:00', N'cancelada'),
        (N'GYM-SOC-0138', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-08T18:00:00', N'2026-09-01T08:50:00', N'cancelada'),
        (N'GYM-SOC-0102', N'Zumba', N'lucia.hernandez@example.com', N'2026-09-08T18:00:00', N'2026-09-07T15:00:00', N'cancelada'),
        (N'GYM-SOC-0087', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-08-22T10:25:00', N'confirmada'),
        (N'GYM-SOC-0012', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-08-29T08:25:00', N'confirmada'),
        (N'GYM-SOC-0017', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-08-30T16:25:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-04T15:15:00', N'confirmada'),
        (N'GYM-SOC-0031', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-05T08:15:00', N'confirmada'),
        (N'GYM-SOC-0085', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-06T18:50:00', N'confirmada'),
        (N'GYM-SOC-0117', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-06T20:05:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Yoga', N'ana.martinez@example.com', N'2026-09-09T06:30:00', N'2026-09-07T08:40:00', N'confirmada'),
        (N'GYM-SOC-0016', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-08-29T18:05:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-08-30T20:10:00', N'confirmada'),
        (N'PRUEBA-007', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-09-02T09:15:00', N'confirmada'),
        (N'GYM-SOC-0027', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-09-02T11:25:00', N'confirmada'),
        (N'GYM-SOC-0095', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-09-13T16:15:00', N'confirmada'),
        (N'GYM-SOC-0077', N'Pilates', N'sofia.castro@example.com', N'2026-09-14T17:00:00', N'2026-09-13T19:15:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-08-29T19:30:00', N'cancelada'),
        (N'GYM-SOC-0022', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-04T11:30:00', N'confirmada'),
        (N'GYM-SOC-0088', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-09T08:55:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-09T18:00:00', N'confirmada'),
        (N'GYM-SOC-0073', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-11T12:00:00', N'cancelada'),
        (N'GYM-SOC-0108', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-15T16:30:00', N'2026-09-14T09:20:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-16T17:00:00', N'2026-08-31T12:35:00', N'confirmada'),
        (N'PRUEBA-004', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-09-16T17:00:00', N'2026-09-10T14:20:00', N'confirmada'),
        (N'GYM-SOC-0044', N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-07T17:30:00', N'confirmada'),
        (N'PRUEBA-008', N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-16T09:55:00', N'confirmada'),
        (N'PRUEBA-002', N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-18T17:50:00', N'confirmada'),
        (N'GYM-SOC-0109', N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-19T12:40:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Pilates', N'sofia.castro@example.com', N'2026-09-21T09:15:00', N'2026-09-19T15:35:00', N'confirmada'),

        -- Reservas de sesiones 2026-10
        (N'GYM-SOC-0059', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-09-20T11:35:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-09-28T16:25:00', N'confirmada'),
        (N'GYM-SOC-0130', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-09-29T11:05:00', N'confirmada'),
        (N'GYM-SOC-0088', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-09-30T13:00:00', N'confirmada'),
        (N'PRUEBA-008', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-02T19:30:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-04T11:10:00', N'confirmada'),
        (N'GYM-SOC-0041', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-07T20:15:00', N'confirmada'),
        (N'GYM-SOC-0094', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-08T11:10:00', N'cancelada'),
        (N'GYM-SOC-0126', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-08T13:55:00', N'confirmada'),
        (N'GYM-SOC-0104', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-09T07:00:00', N'2026-10-08T20:45:00', N'confirmada'),
        (N'GYM-SOC-0031', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-09-22T20:35:00', N'confirmada'),
        (N'GYM-SOC-0117', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-09-24T18:35:00', N'confirmada'),
        (N'GYM-SOC-0016', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-09-25T13:20:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-09-27T16:50:00', N'confirmada'),
        (N'GYM-SOC-0120', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-09-30T18:10:00', N'confirmada'),
        (N'GYM-SOC-0022', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-01T15:00:00', N'confirmada'),
        (N'GYM-SOC-0044', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-02T14:40:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-05T10:25:00', N'cancelada'),
        (N'GYM-SOC-0088', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-05T11:50:00', N'confirmada'),
        (N'GYM-SOC-0104', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-07T20:10:00', N'confirmada'),
        (N'GYM-SOC-0039', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-07T20:15:00', N'cancelada'),
        (N'PRUEBA-006', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-09T08:30:00', N'confirmada'),
        (N'PRUEBA-009', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-09T10:15:00', N'confirmada'),
        (N'GYM-SOC-0137', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-09T13:20:00', N'confirmada'),
        (N'PRUEBA-002', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-09T14:35:00', N'confirmada'),
        (N'GYM-SOC-0090', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-09T19:40:00', N'confirmada'),
        (N'GYM-SOC-0126', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-10T08:15:00', N'confirmada'),
        (N'GYM-SOC-0107', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-10T13:30:00', N'confirmada'),
        (N'GYM-SOC-0109', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-10T14:20:00', N'confirmada'),
        (N'GYM-SOC-0033', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-10-11T07:00:00', N'2026-10-10T15:15:00', N'confirmada'),
        (N'GYM-SOC-0138', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-09-24T17:35:00', N'confirmada'),
        (N'GYM-SOC-0077', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-09-30T12:50:00', N'confirmada'),
        (N'GYM-SOC-0095', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-09-30T19:05:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-01T19:30:00', N'confirmada'),
        (N'GYM-SOC-0088', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-02T12:10:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-02T18:50:00', N'confirmada'),
        (N'GYM-SOC-0012', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-05T08:55:00', N'confirmada'),
        (N'GYM-SOC-0078', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-06T16:05:00', N'confirmada'),
        (N'PRUEBA-006', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-07T10:40:00', N'confirmada'),
        (N'GYM-SOC-0041', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-08T11:05:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-08T17:40:00', N'confirmada'),
        (N'GYM-SOC-0120', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-09T13:50:00', N'confirmada'),
        (N'GYM-SOC-0094', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-09T17:05:00', N'confirmada'),
        (N'GYM-SOC-0104', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-11T13:40:00', N'confirmada'),
        (N'PRUEBA-001', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-11T16:15:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-11T16:15:00', N'confirmada'),
        (N'GYM-SOC-0033', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-11T19:00:00', N'confirmada'),
        (N'GYM-SOC-0107', N'Spinning', N'carlos.lopez@example.com', N'2026-10-13T18:00:00', N'2026-10-11T20:55:00', N'confirmada'),
        (N'GYM-SOC-0012', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-09-25T13:20:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-09-25T19:30:00', N'confirmada'),
        (N'GYM-SOC-0077', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-09-27T08:15:00', N'confirmada'),
        (N'GYM-SOC-0031', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-09-28T19:40:00', N'confirmada'),
        (N'PRUEBA-006', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-09-30T15:00:00', N'cancelada'),
        (N'GYM-SOC-0022', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-01T17:40:00', N'confirmada'),
        (N'GYM-SOC-0083', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-01T19:10:00', N'confirmada'),
        (N'GYM-SOC-0117', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-01T19:25:00', N'confirmada'),
        (N'GYM-SOC-0092', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-02T09:05:00', N'confirmada'),
        (N'GYM-SOC-0120', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-08T10:50:00', N'cancelada'),
        (N'GYM-SOC-0107', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-08T18:25:00', N'confirmada'),
        (N'GYM-SOC-0095', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-08T19:15:00', N'cancelada'),
        (N'GYM-SOC-0106', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-09T13:45:00', N'confirmada'),
        (N'GYM-SOC-0109', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-11T18:55:00', N'confirmada'),
        (N'PRUEBA-001', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-13T12:50:00', N'confirmada'),
        (N'GYM-SOC-0019', N'Spinning', N'carlos.lopez@example.com', N'2026-10-14T09:15:00', N'2026-10-13T18:40:00', N'confirmada'),
        (N'GYM-SOC-0077', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-16T08:00:00', N'2026-10-06T09:30:00', N'cancelada'),
        (N'GYM-SOC-0107', N'Zumba', N'lucia.hernandez@example.com', N'2026-10-16T08:00:00', N'2026-10-13T11:10:00', N'cancelada'),
        (N'PRUEBA-004', N'Pilates', N'sofia.castro@example.com', N'2026-10-19T19:00:00', N'2026-10-06T18:00:00', N'confirmada'),
        (N'PRUEBA-001', N'Pilates', N'sofia.castro@example.com', N'2026-10-19T19:00:00', N'2026-10-07T14:10:00', N'cancelada'),
        (N'GYM-SOC-0126', N'Pilates', N'sofia.castro@example.com', N'2026-10-19T19:00:00', N'2026-10-13T13:05:00', N'confirmada'),
        (N'GYM-SOC-0127', N'Pilates', N'sofia.castro@example.com', N'2026-10-19T19:00:00', N'2026-10-15T16:55:00', N'confirmada'),
        (N'GYM-SOC-0049', N'Yoga', N'ana.martinez@example.com', N'2026-10-21T17:00:00', N'2026-10-02T10:45:00', N'cancelada'),
        (N'PRUEBA-003', N'Yoga', N'ana.martinez@example.com', N'2026-10-21T17:00:00', N'2026-10-17T11:25:00', N'cancelada'),
        (N'GYM-SOC-0075', N'Yoga', N'ana.martinez@example.com', N'2026-10-21T17:00:00', N'2026-10-18T11:00:00', N'cancelada'),
        (N'GYM-SOC-0090', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-05T16:30:00', N'confirmada'),
        (N'GYM-SOC-0078', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-10T14:10:00', N'confirmada'),
        (N'GYM-SOC-0104', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-12T12:25:00', N'confirmada'),
        (N'GYM-SOC-0024', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-15T11:35:00', N'confirmada'),
        (N'GYM-SOC-0039', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-20T16:10:00', N'confirmada'),
        (N'GYM-SOC-0028', N'Yoga', N'ana.martinez@example.com', N'2026-10-22T09:15:00', N'2026-10-21T10:50:00', N'confirmada'),

        -- Reservas de sesiones 2026-11
        (N'GYM-SOC-0019', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-14T08:30:00', N'confirmada'),
        (N'PRUEBA-008', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-16T11:40:00', N'confirmada'),
        (N'PRUEBA-003', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-21T08:20:00', N'confirmada'),
        (N'GYM-SOC-0050', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-23T09:40:00', N'cancelada'),
        (N'GYM-SOC-0003', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-23T20:35:00', N'confirmada'),
        (N'GYM-SOC-0077', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-10-24T08:25:00', N'confirmada'),
        (N'PRUEBA-005', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-11-01T18:55:00', N'confirmada'),
        (N'GYM-SOC-0001', N'Pilates', N'sofia.castro@example.com', N'2026-11-02T09:15:00', N'2026-11-01T20:30:00', N'confirmada'),
        (N'PRUEBA-007', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-05T17:00:00', N'2026-10-23T13:05:00', N'cancelada'),
        (N'GYM-SOC-0088', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-05T17:00:00', N'2026-10-23T18:40:00', N'cancelada'),
        (N'GYM-SOC-0003', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-23T13:40:00', N'confirmada'),
        (N'GYM-SOC-0008', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-24T11:20:00', N'confirmada'),
        (N'GYM-SOC-0098', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-26T11:00:00', N'confirmada'),
        (N'GYM-SOC-0035', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-27T15:45:00', N'confirmada'),
        (N'GYM-SOC-0104', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-28T15:50:00', N'confirmada'),
        (N'GYM-SOC-0049', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-10-30T09:30:00', N'confirmada'),
        (N'GYM-SOC-0041', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-03T08:05:00', N'cancelada'),
        (N'GYM-SOC-0088', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-05T13:55:00', N'confirmada'),
        (N'GYM-SOC-0029', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-06T12:50:00', N'confirmada'),
        (N'GYM-SOC-0075', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-06T15:10:00', N'confirmada'),
        (N'GYM-SOC-0053', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-06T20:55:00', N'confirmada'),
        (N'GYM-SOC-0055', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-07T10:55:00', N'confirmada'),
        (N'GYM-SOC-0132', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-07T18:20:00', N'confirmada'),
        (N'GYM-SOC-0119', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-08T16:30:00', N'2026-11-07T19:40:00', N'confirmada'),
        (N'GYM-SOC-0122', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-10-26T20:30:00', N'cancelada'),
        (N'GYM-SOC-0086', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-10-27T16:40:00', N'confirmada'),
        (N'GYM-SOC-0109', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-10-28T08:50:00', N'cancelada'),
        (N'GYM-SOC-0010', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-10-29T09:10:00', N'confirmada'),
        (N'GYM-SOC-0026', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-10-29T10:45:00', N'confirmada'),
        (N'PRUEBA-002', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-06T10:55:00', N'confirmada'),
        (N'PRUEBA-001', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-07T13:35:00', N'confirmada'),
        (N'GYM-SOC-0095', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-08T12:55:00', N'cancelada'),
        (N'GYM-SOC-0087', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-08T16:50:00', N'confirmada'),
        (N'GYM-SOC-0049', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-09T13:30:00', N'confirmada'),
        (N'GYM-SOC-0100', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-10T12:35:00', N'confirmada'),
        (N'GYM-SOC-0075', N'Pilates', N'sofia.castro@example.com', N'2026-11-14T16:30:00', N'2026-11-10T17:20:00', N'confirmada'),
        (N'GYM-SOC-0128', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-10-28T09:45:00', N'confirmada'),
        (N'PRUEBA-004', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-10-31T16:40:00', N'confirmada'),
        (N'GYM-SOC-0094', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-11-03T16:20:00', N'confirmada'),
        (N'GYM-SOC-0010', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-11-06T15:40:00', N'confirmada'),
        (N'GYM-SOC-0025', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-11-06T18:55:00', N'confirmada'),
        (N'GYM-SOC-0055', N'Entrenamiento funcional', N'diego.ramirez@example.com', N'2026-11-15T06:30:00', N'2026-11-12T11:35:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Spinning', N'carlos.lopez@example.com', N'2026-11-18T08:00:00', N'2026-11-02T15:45:00', N'confirmada'),
        (N'GYM-SOC-0050', N'Spinning', N'carlos.lopez@example.com', N'2026-11-18T08:00:00', N'2026-11-05T17:30:00', N'confirmada'),
        (N'GYM-SOC-0119', N'Yoga', N'ana.martinez@example.com', N'2026-11-19T19:00:00', N'2026-11-06T13:10:00', N'cancelada'),
        (N'GYM-SOC-0122', N'Zumba', N'lucia.hernandez@example.com', N'2026-11-20T17:00:00', N'2026-11-01T08:40:00', N'confirmada'),
        (N'GYM-SOC-0109', N'Zumba', N'lucia.hernandez@example.com', N'2026-11-20T17:00:00', N'2026-11-05T11:40:00', N'confirmada'),
        (N'GYM-SOC-0035', N'Zumba', N'lucia.hernandez@example.com', N'2026-11-20T17:00:00', N'2026-11-11T14:45:00', N'confirmada'),
        (N'GYM-SOC-0053', N'Zumba', N'lucia.hernandez@example.com', N'2026-11-20T17:00:00', N'2026-11-12T14:45:00', N'confirmada'),
        (N'GYM-SOC-0072', N'Spinning', N'carlos.lopez@example.com', N'2026-11-24T06:30:00', N'2026-11-06T16:55:00', N'confirmada'),
        (N'GYM-SOC-0087', N'Spinning', N'carlos.lopez@example.com', N'2026-11-24T06:30:00', N'2026-11-08T17:15:00', N'confirmada'),
        (N'PRUEBA-007', N'Spinning', N'carlos.lopez@example.com', N'2026-11-24T06:30:00', N'2026-11-12T13:40:00', N'confirmada');


    IF (SELECT COUNT(*) FROM #ReservasExtra) <> 279
    BEGIN
        ;THROW 51012, 'El lote de reservas debe contener 279 filas.', 1;
    END;

    -- Rechazar cualquier socio o sesion sin correspondencia UNICA.
    IF EXISTS (
        SELECT 1
        FROM #ReservasExtra AS x
        LEFT JOIN dbo.Socio AS s ON s.documento = x.documento
        OUTER APPLY (
            SELECT COUNT(*) AS coincidencias
            FROM dbo.SesionClase AS sc
            JOIN dbo.Clase AS c ON c.id_clase = sc.id_clase
            JOIN dbo.Entrenador AS e ON e.id_entrenador = sc.id_entrenador
            WHERE c.nombre = x.nombre_clase
              AND e.email = x.email_entrenador
              AND sc.inicio = x.inicio_sesion
        ) AS busqueda
        WHERE s.id_socio IS NULL OR busqueda.coincidencias <> 1
    )
    BEGIN
        ;THROW 51013, 'Reserva: socio inexistente o sesion no encontrada de forma unica.', 1;
    END;

    -- Se identifica el registro completo, incluso cuando hay cancelaciones.
    INSERT INTO dbo.Reserva
        (id_socio, id_sesion, fecha_reserva, estado)
    SELECT s.id_socio, sc.id_sesion, x.fecha_reserva, x.estado
    FROM #ReservasExtra AS x
    JOIN dbo.Socio AS s ON s.documento = x.documento
    JOIN dbo.Clase AS c ON c.nombre = x.nombre_clase
    JOIN dbo.Entrenador AS e ON e.email = x.email_entrenador
    JOIN dbo.SesionClase AS sc ON sc.id_clase = c.id_clase
                                AND sc.id_entrenador = e.id_entrenador
                                AND sc.inicio = x.inicio_sesion
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Reserva AS r WITH (UPDLOCK, HOLDLOCK)
        WHERE r.id_socio = s.id_socio AND r.id_sesion = sc.id_sesion
          AND r.fecha_reserva = x.fecha_reserva AND r.estado = x.estado
    );

    -- ------------------------------------------------------------------------
    -- 5. PAGO: 169 filas con referencias ficticias PBI26-xxx.
    -- Se identifica su membresia por documento + fecha_inicio del contrato.
    -- No se usa id_membresia ni se presupone una numeracion consecutiva.
    -- ------------------------------------------------------------------------
    CREATE TABLE #PagosExtra (
        documento NVARCHAR(20) NOT NULL,
        inicio_membresia DATE NOT NULL,
        fecha_pago DATETIME2(0) NOT NULL,
        monto DECIMAL(10,2) NOT NULL,
        metodo_pago NVARCHAR(15) NOT NULL,
        referencia NVARCHAR(100) NOT NULL PRIMARY KEY,
        estado NVARCHAR(10) NOT NULL
    );

    INSERT INTO #PagosExtra
        (documento, inicio_membresia, fecha_pago, monto,
         metodo_pago, referencia, estado)
    VALUES


        -- Pagos de 2026-06
        (N'GYM-SOC-0067', N'2026-06-01', N'2026-06-02T07:15:00', 13.00, N'tarjeta', N'PBI26-TAR-0001', N'aplicado'),
        (N'GYM-SOC-0118', N'2026-06-01', N'2026-06-02T08:40:00', 10.00, N'transferencia', N'PBI26-TRF-0002', N'aplicado'),
        (N'GYM-SOC-0056', N'2026-06-01', N'2026-06-06T14:30:00', 9.45, N'efectivo', N'PBI26-EFE-0003', N'aplicado'),
        (N'GYM-SOC-0026', N'2026-06-08', N'2026-06-08T06:10:00', 23.00, N'transferencia', N'PBI26-TRF-0004', N'anulado'),
        (N'GYM-SOC-0026', N'2026-06-08', N'2026-06-08T10:30:00', 23.00, N'efectivo', N'PBI26-EFE-0005', N'aplicado'),
        (N'GYM-SOC-0105', N'2026-06-07', N'2026-06-09T07:20:00', 65.00, N'tarjeta', N'PBI26-TAR-0006', N'aplicado'),
        (N'GYM-SOC-0009', N'2026-06-05', N'2026-06-09T14:00:00', 27.50, N'tarjeta', N'PBI26-TAR-0007', N'aplicado'),
        (N'GYM-SOC-0110', N'2026-06-06', N'2026-06-10T17:15:00', 25.00, N'efectivo', N'PBI26-EFE-0008', N'aplicado'),
        (N'GYM-SOC-0024', N'2026-06-19', N'2026-06-19T11:00:00', 120.00, N'efectivo', N'PBI26-EFE-0009', N'aplicado'),
        (N'GYM-SOC-0067', N'2026-06-01', N'2026-06-22T11:00:00', 22.75, N'tarjeta', N'PBI26-TAR-0010', N'aplicado'),
        (N'GYM-SOC-0084', N'2026-06-22', N'2026-06-27T08:30:00', 9.60, N'transferencia', N'PBI26-TRF-0011', N'aplicado'),
        (N'GYM-SOC-0092', N'2026-06-27', N'2026-06-29T16:50:00', 120.00, N'efectivo', N'PBI26-EFE-0012', N'aplicado'),
        (N'GYM-SOC-0026', N'2026-06-08', N'2026-06-30T14:00:00', 28.75, N'efectivo', N'PBI26-EFE-0013', N'aplicado'),

        -- Pagos de 2026-07
        (N'GYM-SOC-0046', N'2026-07-01', N'2026-07-01T06:10:00', 15.00, N'transferencia', N'PBI26-TRF-0014', N'anulado'),
        (N'GYM-SOC-0118', N'2026-06-01', N'2026-07-01T14:00:00', 15.00, N'efectivo', N'PBI26-EFE-0015', N'aplicado'),
        (N'GYM-SOC-0046', N'2026-07-01', N'2026-07-01T14:20:00', 15.00, N'efectivo', N'PBI26-EFE-0016', N'aplicado'),
        (N'GYM-SOC-0074', N'2026-06-27', N'2026-07-03T12:45:00', 42.00, N'transferencia', N'PBI26-TRF-0017', N'aplicado'),
        (N'GYM-SOC-0009', N'2026-06-05', N'2026-07-03T17:45:00', 38.50, N'tarjeta', N'PBI26-TAR-0018', N'aplicado'),
        (N'GYM-SOC-0067', N'2026-06-01', N'2026-07-06T07:30:00', 29.25, N'tarjeta', N'PBI26-TAR-0019', N'aplicado'),
        (N'GYM-SOC-0087', N'2026-07-04', N'2026-07-06T16:00:00', 120.00, N'efectivo', N'PBI26-EFE-0020', N'aplicado'),
        (N'GYM-SOC-0106', N'2026-07-13', N'2026-07-15T17:20:00', 120.00, N'tarjeta', N'PBI26-TAR-0021', N'aplicado'),
        (N'GYM-SOC-0130', N'2026-07-13', N'2026-07-16T17:10:00', 28.00, N'transferencia', N'PBI26-TRF-0022', N'aplicado'),
        (N'GYM-SOC-0088', N'2026-07-18', N'2026-07-18T14:30:00', 24.00, N'tarjeta', N'PBI26-TAR-0023', N'aplicado'),
        (N'GYM-SOC-0084', N'2026-06-22', N'2026-07-19T11:00:00', 14.40, N'efectivo', N'PBI26-EFE-0024', N'aplicado'),
        (N'GYM-SOC-0027', N'2026-07-15', N'2026-07-20T17:00:00', 34.65, N'transferencia', N'PBI26-TRF-0025', N'aplicado'),
        (N'GYM-SOC-0022', N'2026-07-21', N'2026-07-23T11:30:00', 18.90, N'transferencia', N'PBI26-TRF-0026', N'aplicado'),
        (N'GYM-SOC-0009', N'2026-06-05', N'2026-07-24T14:00:00', 44.00, N'transferencia', N'PBI26-TRF-0027', N'aplicado'),
        (N'GYM-SOC-0018', N'2026-07-26', N'2026-07-30T10:45:00', 12.00, N'transferencia', N'PBI26-TRF-0028', N'aplicado'),
        (N'GYM-SOC-0089', N'2026-07-29', N'2026-07-30T14:20:00', 23.00, N'efectivo', N'PBI26-EFE-0029', N'aplicado'),

        -- Pagos de 2026-08
        (N'GYM-SOC-0016', N'2026-08-01', N'2026-08-01T08:20:00', 13.00, N'transferencia', N'PBI26-TRF-0030', N'aplicado'),
        (N'GYM-SOC-0027', N'2026-07-15', N'2026-08-01T18:20:00', 28.35, N'tarjeta', N'PBI26-TAR-0031', N'aplicado'),
        (N'GYM-SOC-0099', N'2026-07-29', N'2026-08-01T19:45:00', 25.00, N'efectivo', N'PBI26-EFE-0032', N'aplicado'),
        (N'GYM-SOC-0026', N'2026-06-08', N'2026-08-02T18:50:00', 63.25, N'efectivo', N'PBI26-EFE-0033', N'aplicado'),
        (N'GYM-SOC-0083', N'2026-08-01', N'2026-08-03T14:20:00', 34.65, N'efectivo', N'PBI26-EFE-0034', N'aplicado'),
        (N'GYM-SOC-0124', N'2026-08-01', N'2026-08-03T14:45:00', 12.50, N'tarjeta', N'PBI26-TAR-0035', N'aplicado'),
        (N'GYM-SOC-0066', N'2026-08-03', N'2026-08-04T09:30:00', 15.00, N'efectivo', N'PBI26-EFE-0036', N'aplicado'),
        (N'GYM-SOC-0136', N'2026-08-05', N'2026-08-08T10:30:00', 27.00, N'tarjeta', N'PBI26-TAR-0037', N'aplicado'),
        (N'GYM-SOC-0088', N'2026-07-18', N'2026-08-08T17:40:00', 36.00, N'efectivo', N'PBI26-EFE-0038', N'aplicado'),
        (N'GYM-SOC-0047', N'2026-08-05', N'2026-08-10T12:00:00', 24.50, N'transferencia', N'PBI26-TRF-0039', N'aplicado'),
        (N'GYM-SOC-0020', N'2026-08-08', N'2026-08-11T06:10:00', 48.00, N'tarjeta', N'PBI26-TAR-0040', N'anulado'),
        (N'GYM-SOC-0130', N'2026-07-13', N'2026-08-11T08:20:00', 42.00, N'tarjeta', N'PBI26-TAR-0041', N'aplicado'),
        (N'GYM-SOC-0020', N'2026-08-08', N'2026-08-11T17:00:00', 48.00, N'transferencia', N'PBI26-TRF-0042', N'aplicado'),
        (N'GYM-SOC-0044', N'2026-08-10', N'2026-08-11T17:00:00', 63.00, N'tarjeta', N'PBI26-TAR-0043', N'aplicado'),
        (N'GYM-SOC-0014', N'2026-08-11', N'2026-08-12T12:40:00', 25.00, N'transferencia', N'PBI26-TRF-0044', N'aplicado'),
        (N'GYM-SOC-0124', N'2026-08-01', N'2026-08-14T18:20:00', 12.50, N'tarjeta', N'PBI26-TAR-0045', N'aplicado'),
        (N'GYM-SOC-0031', N'2026-08-10', N'2026-08-15T17:15:00', 65.00, N'tarjeta', N'PBI26-TAR-0046', N'aplicado'),
        (N'GYM-SOC-0016', N'2026-08-01', N'2026-08-17T12:10:00', 16.25, N'transferencia', N'PBI26-TRF-0047', N'aplicado'),
        (N'GYM-SOC-0022', N'2026-07-21', N'2026-08-17T14:40:00', 15.75, N'transferencia', N'PBI26-TRF-0048', N'aplicado'),
        (N'GYM-SOC-0025', N'2026-08-15', N'2026-08-19T10:20:00', 42.00, N'tarjeta', N'PBI26-TAR-0049', N'aplicado'),
        (N'GYM-SOC-0051', N'2026-08-18', N'2026-08-21T14:10:00', 53.60, N'efectivo', N'PBI26-EFE-0050', N'aplicado'),
        (N'GYM-SOC-0018', N'2026-07-26', N'2026-08-21T17:00:00', 15.00, N'transferencia', N'PBI26-TRF-0051', N'aplicado'),
        (N'GYM-SOC-0037', N'2026-08-18', N'2026-08-22T14:00:00', 23.00, N'tarjeta', N'PBI26-TAR-0052', N'aplicado'),
        (N'GYM-SOC-0102', N'2026-08-20', N'2026-08-22T19:00:00', 13.20, N'tarjeta', N'PBI26-TAR-0053', N'aplicado'),
        (N'GYM-SOC-0005', N'2026-08-18', N'2026-08-23T09:00:00', 22.75, N'efectivo', N'PBI26-EFE-0054', N'aplicado'),
        (N'GYM-SOC-0123', N'2026-08-24', N'2026-08-26T10:40:00', 9.20, N'transferencia', N'PBI26-TRF-0055', N'aplicado'),
        (N'GYM-SOC-0048', N'2026-08-26', N'2026-08-27T10:45:00', 8.10, N'efectivo', N'PBI26-EFE-0056', N'aplicado'),
        (N'GYM-SOC-0012', N'2026-08-27', N'2026-08-28T08:50:00', 16.75, N'tarjeta', N'PBI26-TAR-0057', N'aplicado'),
        (N'GYM-SOC-0016', N'2026-08-01', N'2026-08-29T10:10:00', 26.81, N'transferencia', N'PBI26-TRF-0058', N'aplicado'),
        (N'GYM-SOC-0017', N'2026-08-26', N'2026-08-31T12:15:00', 24.00, N'efectivo', N'PBI26-EFE-0059', N'aplicado'),
        (N'GYM-SOC-0091', N'2026-08-31', N'2026-08-31T14:00:00', 27.00, N'tarjeta', N'PBI26-TAR-0060', N'aplicado'),
        (N'GYM-SOC-0114', N'2026-08-29', N'2026-08-31T18:40:00', 27.00, N'transferencia', N'PBI26-TRF-0061', N'aplicado'),

        -- Pagos de 2026-09
        (N'GYM-SOC-0088', N'2026-07-18', N'2026-09-01T07:00:00', 45.00, N'efectivo', N'PBI26-EFE-0062', N'aplicado'),
        (N'GYM-SOC-0020', N'2026-08-08', N'2026-09-01T07:50:00', 72.00, N'efectivo', N'PBI26-EFE-0063', N'aplicado'),
        (N'GYM-SOC-0083', N'2026-08-01', N'2026-09-01T08:10:00', 28.35, N'tarjeta', N'PBI26-TAR-0064', N'aplicado'),
        (N'GYM-SOC-0103', N'2026-08-27', N'2026-09-01T18:20:00', 9.60, N'transferencia', N'PBI26-TRF-0065', N'aplicado'),
        (N'GYM-SOC-0025', N'2026-08-15', N'2026-09-05T14:45:00', 78.00, N'tarjeta', N'PBI26-TAR-0066', N'aplicado'),
        (N'GYM-SOC-0061', N'2026-09-05', N'2026-09-05T17:20:00', 8.75, N'transferencia', N'PBI26-TRF-0067', N'aplicado'),
        (N'GYM-SOC-0018', N'2026-07-26', N'2026-09-07T19:20:00', 33.00, N'transferencia', N'PBI26-TRF-0068', N'aplicado'),
        (N'GYM-SOC-0095', N'2026-09-05', N'2026-09-08T16:40:00', 52.00, N'efectivo', N'PBI26-EFE-0069', N'aplicado'),
        (N'GYM-SOC-0073', N'2026-09-07', N'2026-09-08T19:45:00', 26.00, N'tarjeta', N'PBI26-TAR-0070', N'aplicado'),
        (N'GYM-SOC-0002', N'2026-09-08', N'2026-09-09T16:00:00', 25.00, N'efectivo', N'PBI26-EFE-0071', N'aplicado'),
        (N'GYM-SOC-0085', N'2026-09-06', N'2026-09-09T16:45:00', 27.00, N'transferencia', N'PBI26-TRF-0072', N'aplicado'),
        (N'GYM-SOC-0117', N'2026-09-05', N'2026-09-10T19:00:00', 65.00, N'efectivo', N'PBI26-EFE-0073', N'aplicado'),
        (N'GYM-SOC-0129', N'2026-09-13', N'2026-09-14T06:10:00', 9.60, N'transferencia', N'PBI26-TRF-0074', N'anulado'),
        (N'GYM-SOC-0129', N'2026-09-13', N'2026-09-14T09:50:00', 9.60, N'efectivo', N'PBI26-EFE-0075', N'aplicado'),
        (N'GYM-SOC-0022', N'2026-07-21', N'2026-09-15T08:45:00', 21.26, N'transferencia', N'PBI26-TRF-0076', N'aplicado'),
        (N'GYM-SOC-0108', N'2026-09-14', N'2026-09-15T11:50:00', 12.50, N'efectivo', N'PBI26-EFE-0077', N'aplicado'),
        (N'GYM-SOC-0103', N'2026-08-27', N'2026-09-15T16:40:00', 6.48, N'tarjeta', N'PBI26-TAR-0078', N'aplicado'),
        (N'GYM-SOC-0064', N'2026-09-10', N'2026-09-16T10:15:00', 25.00, N'efectivo', N'PBI26-EFE-0079', N'aplicado'),
        (N'GYM-SOC-0113', N'2026-09-11', N'2026-09-16T12:30:00', 9.20, N'efectivo', N'PBI26-EFE-0080', N'aplicado'),
        (N'GYM-SOC-0102', N'2026-08-20', N'2026-09-18T12:15:00', 10.80, N'efectivo', N'PBI26-EFE-0081', N'aplicado'),
        (N'GYM-SOC-0012', N'2026-08-27', N'2026-09-19T08:20:00', 16.75, N'transferencia', N'PBI26-TRF-0082', N'aplicado'),
        (N'GYM-SOC-0077', N'2026-09-13', N'2026-09-19T11:45:00', 60.00, N'efectivo', N'PBI26-EFE-0083', N'aplicado'),
        (N'GYM-SOC-0048', N'2026-08-26', N'2026-09-19T17:00:00', 8.51, N'transferencia', N'PBI26-TRF-0084', N'aplicado'),
        (N'GYM-SOC-0109', N'2026-09-17', N'2026-09-21T17:00:00', 67.00, N'efectivo', N'PBI26-EFE-0085', N'aplicado'),
        (N'GYM-SOC-0059', N'2026-09-20', N'2026-09-23T06:10:00', 27.00, N'tarjeta', N'PBI26-TAR-0086', N'anulado'),
        (N'GYM-SOC-0049', N'2026-09-21', N'2026-09-23T07:50:00', 67.00, N'tarjeta', N'PBI26-TAR-0087', N'aplicado'),
        (N'GYM-SOC-0059', N'2026-09-20', N'2026-09-23T19:45:00', 27.00, N'tarjeta', N'PBI26-TAR-0088', N'aplicado'),
        (N'GYM-SOC-0113', N'2026-09-11', N'2026-09-24T19:40:00', 13.80, N'transferencia', N'PBI26-TRF-0089', N'aplicado'),
        (N'GYM-SOC-0045', N'2026-09-25', N'2026-09-30T06:10:00', 17.50, N'tarjeta', N'PBI26-TAR-0090', N'anulado'),
        (N'GYM-SOC-0120', N'2026-09-27', N'2026-09-30T08:10:00', 63.00, N'transferencia', N'PBI26-TRF-0091', N'aplicado'),
        (N'GYM-SOC-0045', N'2026-09-25', N'2026-09-30T16:20:00', 17.50, N'efectivo', N'PBI26-EFE-0092', N'aplicado'),

        -- Pagos de 2026-10
        (N'GYM-SOC-0068', N'2026-09-26', N'2026-10-01T08:15:00', 27.00, N'transferencia', N'PBI26-TRF-0093', N'aplicado'),
        (N'GYM-SOC-0090', N'2026-10-02', N'2026-10-03T17:00:00', 92.00, N'efectivo', N'PBI26-EFE-0094', N'aplicado'),
        (N'GYM-SOC-0065', N'2026-10-03', N'2026-10-05T06:10:00', 27.00, N'transferencia', N'PBI26-TRF-0095', N'anulado'),
        (N'GYM-SOC-0065', N'2026-10-03', N'2026-10-05T09:10:00', 27.00, N'transferencia', N'PBI26-TRF-0096', N'aplicado'),
        (N'GYM-SOC-0061', N'2026-09-05', N'2026-10-05T16:45:00', 10.56, N'tarjeta', N'PBI26-TAR-0097', N'aplicado'),
        (N'GYM-SOC-0107', N'2026-10-06', N'2026-10-06T12:50:00', 67.00, N'efectivo', N'PBI26-EFE-0098', N'aplicado'),
        (N'GYM-SOC-0069', N'2026-10-03', N'2026-10-07T14:50:00', 26.00, N'efectivo', N'PBI26-EFE-0099', N'aplicado'),
        (N'GYM-SOC-0078', N'2026-10-06', N'2026-10-07T16:40:00', 24.00, N'tarjeta', N'PBI26-TAR-0100', N'aplicado'),
        (N'GYM-SOC-0127', N'2026-10-06', N'2026-10-08T10:00:00', 8.75, N'efectivo', N'PBI26-EFE-0101', N'aplicado'),
        (N'GYM-SOC-0137', N'2026-10-09', N'2026-10-09T10:15:00', 48.00, N'transferencia', N'PBI26-TRF-0102', N'aplicado'),
        (N'GYM-SOC-0104', N'2026-10-07', N'2026-10-09T12:40:00', 60.00, N'tarjeta', N'PBI26-TAR-0103', N'aplicado'),
        (N'GYM-SOC-0126', N'2026-10-07', N'2026-10-10T18:50:00', 24.00, N'tarjeta', N'PBI26-TAR-0104', N'aplicado'),
        (N'GYM-SOC-0041', N'2026-10-07', N'2026-10-11T07:30:00', 19.50, N'efectivo', N'PBI26-EFE-0105', N'aplicado'),
        (N'GYM-SOC-0039', N'2026-10-07', N'2026-10-12T18:00:00', 24.00, N'efectivo', N'PBI26-EFE-0106', N'aplicado'),
        (N'GYM-SOC-0129', N'2026-09-13', N'2026-10-13T08:10:00', 14.40, N'efectivo', N'PBI26-EFE-0107', N'aplicado'),
        (N'GYM-SOC-0050', N'2026-10-08', N'2026-10-13T08:30:00', 32.50, N'tarjeta', N'PBI26-TAR-0108', N'aplicado'),
        (N'GYM-SOC-0033', N'2026-10-10', N'2026-10-13T09:10:00', 26.00, N'efectivo', N'PBI26-EFE-0109', N'aplicado'),
        (N'GYM-SOC-0108', N'2026-09-14', N'2026-10-13T09:10:00', 12.50, N'transferencia', N'PBI26-TRF-0110', N'aplicado'),
        (N'GYM-SOC-0081', N'2026-10-13', N'2026-10-13T09:40:00', 27.00, N'efectivo', N'PBI26-EFE-0111', N'aplicado'),
        (N'GYM-SOC-0134', N'2026-10-07', N'2026-10-13T18:15:00', 24.00, N'tarjeta', N'PBI26-TAR-0112', N'aplicado'),
        (N'GYM-SOC-0094', N'2026-10-08', N'2026-10-14T18:50:00', 44.10, N'efectivo', N'PBI26-EFE-0113', N'aplicado'),
        (N'GYM-SOC-0019', N'2026-10-13', N'2026-10-16T11:30:00', 65.00, N'tarjeta', N'PBI26-TAR-0114', N'aplicado'),
        (N'GYM-SOC-0133', N'2026-10-14', N'2026-10-17T11:45:00', 25.00, N'tarjeta', N'PBI26-TAR-0115', N'aplicado'),
        (N'GYM-SOC-0042', N'2026-10-17', N'2026-10-19T10:30:00', 37.80, N'transferencia', N'PBI26-TRF-0116', N'aplicado'),
        (N'GYM-SOC-0010', N'2026-10-15', N'2026-10-19T12:30:00', 20.10, N'efectivo', N'PBI26-EFE-0117', N'aplicado'),
        (N'GYM-SOC-0070', N'2026-10-18', N'2026-10-19T12:50:00', 13.00, N'efectivo', N'PBI26-EFE-0118', N'aplicado'),
        (N'GYM-SOC-0028', N'2026-10-20', N'2026-10-20T07:10:00', 63.00, N'efectivo', N'PBI26-EFE-0119', N'aplicado'),
        (N'GYM-SOC-0086', N'2026-10-20', N'2026-10-20T07:45:00', 19.50, N'transferencia', N'PBI26-TRF-0120', N'aplicado'),
        (N'GYM-SOC-0075', N'2026-10-16', N'2026-10-20T19:20:00', 65.00, N'efectivo', N'PBI26-EFE-0121', N'aplicado'),
        (N'GYM-SOC-0096', N'2026-10-21', N'2026-10-21T10:40:00', 65.00, N'transferencia', N'PBI26-TRF-0122', N'aplicado'),
        (N'GYM-SOC-0023', N'2026-10-19', N'2026-10-21T11:50:00', 8.75, N'transferencia', N'PBI26-TRF-0123', N'aplicado'),
        (N'GYM-SOC-0012', N'2026-08-27', N'2026-10-21T14:15:00', 33.50, N'tarjeta', N'PBI26-TAR-0124', N'aplicado'),
        (N'GYM-SOC-0054', N'2026-10-20', N'2026-10-21T17:45:00', 120.00, N'transferencia', N'PBI26-TRF-0125', N'aplicado'),
        (N'GYM-SOC-0035', N'2026-10-22', N'2026-10-22T12:30:00', 18.40, N'efectivo', N'PBI26-EFE-0126', N'aplicado'),
        (N'GYM-SOC-0098', N'2026-10-20', N'2026-10-23T09:20:00', 110.00, N'tarjeta', N'PBI26-TAR-0127', N'aplicado'),
        (N'GYM-SOC-0003', N'2026-10-23', N'2026-10-23T11:30:00', 25.00, N'transferencia', N'PBI26-TRF-0128', N'aplicado'),
        (N'GYM-SOC-0131', N'2026-10-21', N'2026-10-24T06:10:00', 25.00, N'transferencia', N'PBI26-TRF-0129', N'anulado'),
        (N'GYM-SOC-0063', N'2026-10-21', N'2026-10-24T09:00:00', 7.50, N'efectivo', N'PBI26-EFE-0130', N'aplicado'),
        (N'GYM-SOC-0034', N'2026-10-20', N'2026-10-24T10:30:00', 22.75, N'tarjeta', N'PBI26-TAR-0131', N'aplicado'),
        (N'GYM-SOC-0122', N'2026-10-22', N'2026-10-24T12:10:00', 67.00, N'efectivo', N'PBI26-EFE-0132', N'aplicado'),
        (N'GYM-SOC-0131', N'2026-10-21', N'2026-10-24T19:20:00', 25.00, N'efectivo', N'PBI26-EFE-0133', N'aplicado'),
        (N'GYM-SOC-0041', N'2026-10-07', N'2026-10-25T07:45:00', 45.50, N'tarjeta', N'PBI26-TAR-0134', N'aplicado'),
        (N'GYM-SOC-0058', N'2026-10-24', N'2026-10-27T11:45:00', 12.50, N'efectivo', N'PBI26-EFE-0135', N'aplicado'),
        (N'GYM-SOC-0008', N'2026-10-23', N'2026-10-27T12:45:00', 10.00, N'tarjeta', N'PBI26-TAR-0136', N'aplicado'),
        (N'GYM-SOC-0004', N'2026-10-22', N'2026-10-28T16:45:00', 120.00, N'transferencia', N'PBI26-TRF-0137', N'aplicado'),
        (N'GYM-SOC-0032', N'2026-10-26', N'2026-10-30T07:45:00', 44.10, N'transferencia', N'PBI26-TRF-0138', N'aplicado'),
        (N'GYM-SOC-0052', N'2026-10-24', N'2026-10-30T12:20:00', 56.00, N'efectivo', N'PBI26-EFE-0139', N'aplicado'),
        (N'GYM-SOC-0010', N'2026-10-15', N'2026-10-31T08:00:00', 30.49, N'tarjeta', N'PBI26-TAR-0140', N'aplicado'),

        -- Pagos de 2026-11
        (N'GYM-SOC-0040', N'2026-10-29', N'2026-11-01T08:10:00', 25.00, N'efectivo', N'PBI26-EFE-0141', N'aplicado'),
        (N'GYM-SOC-0127', N'2026-10-06', N'2026-11-01T12:45:00', 10.56, N'efectivo', N'PBI26-EFE-0142', N'aplicado'),
        (N'GYM-SOC-0001', N'2026-11-01', N'2026-11-01T16:10:00', 26.00, N'efectivo', N'PBI26-EFE-0143', N'aplicado'),
        (N'GYM-SOC-0070', N'2026-10-18', N'2026-11-01T18:30:00', 13.00, N'efectivo', N'PBI26-EFE-0144', N'aplicado'),
        (N'GYM-SOC-0115', N'2026-10-29', N'2026-11-02T08:50:00', 23.00, N'efectivo', N'PBI26-EFE-0145', N'aplicado'),
        (N'GYM-SOC-0086', N'2026-10-20', N'2026-11-02T10:20:00', 45.50, N'tarjeta', N'PBI26-TAR-0146', N'aplicado'),
        (N'GYM-SOC-0119', N'2026-11-02', N'2026-11-03T12:10:00', 65.00, N'efectivo', N'PBI26-EFE-0147', N'aplicado'),
        (N'GYM-SOC-0021', N'2026-10-30', N'2026-11-03T19:20:00', 25.00, N'tarjeta', N'PBI26-TAR-0148', N'aplicado'),
        (N'GYM-SOC-0034', N'2026-10-20', N'2026-11-04T14:30:00', 42.25, N'tarjeta', N'PBI26-TAR-0149', N'aplicado'),
        (N'GYM-SOC-0038', N'2026-11-02', N'2026-11-05T19:30:00', 110.00, N'efectivo', N'PBI26-EFE-0150', N'aplicado'),
        (N'GYM-SOC-0011', N'2026-11-01', N'2026-11-06T08:00:00', 25.00, N'transferencia', N'PBI26-TRF-0151', N'aplicado'),
        (N'GYM-SOC-0132', N'2026-11-05', N'2026-11-06T14:30:00', 10.00, N'transferencia', N'PBI26-TRF-0152', N'aplicado'),
        (N'GYM-SOC-0029', N'2026-11-04', N'2026-11-07T09:45:00', 77.00, N'efectivo', N'PBI26-EFE-0153', N'aplicado'),
        (N'GYM-SOC-0013', N'2026-11-05', N'2026-11-08T08:10:00', 70.00, N'transferencia', N'PBI26-TRF-0154', N'aplicado'),
        (N'GYM-SOC-0097', N'2026-11-02', N'2026-11-08T12:50:00', 12.00, N'tarjeta', N'PBI26-TAR-0155', N'aplicado'),
        (N'GYM-SOC-0053', N'2026-11-06', N'2026-11-08T19:15:00', 72.00, N'transferencia', N'PBI26-TRF-0156', N'aplicado'),
        (N'GYM-SOC-0076', N'2026-11-09', N'2026-11-09T10:20:00', 23.00, N'tarjeta', N'PBI26-TAR-0157', N'aplicado'),
        (N'GYM-SOC-0112', N'2026-11-07', N'2026-11-09T12:40:00', 20.00, N'efectivo', N'PBI26-EFE-0158', N'aplicado'),
        (N'GYM-SOC-0050', N'2026-10-08', N'2026-11-09T14:20:00', 24.38, N'transferencia', N'PBI26-TRF-0159', N'aplicado'),
        (N'GYM-SOC-0063', N'2026-10-21', N'2026-11-09T19:40:00', 17.50, N'tarjeta', N'PBI26-TAR-0160', N'aplicado'),
        (N'GYM-SOC-0055', N'2026-11-06', N'2026-11-10T06:10:00', 42.00, N'tarjeta', N'PBI26-TAR-0161', N'anulado'),
        (N'GYM-SOC-0055', N'2026-11-06', N'2026-11-10T12:00:00', 42.00, N'transferencia', N'PBI26-TRF-0162', N'aplicado'),
        (N'GYM-SOC-0015', N'2026-11-10', N'2026-11-11T08:15:00', 27.00, N'efectivo', N'PBI26-EFE-0163', N'aplicado'),
        (N'GYM-SOC-0043', N'2026-11-11', N'2026-11-11T12:00:00', 25.00, N'transferencia', N'PBI26-TRF-0164', N'aplicado'),
        (N'GYM-SOC-0058', N'2026-10-24', N'2026-11-11T18:15:00', 12.50, N'tarjeta', N'PBI26-TAR-0165', N'aplicado'),
        (N'GYM-SOC-0100', N'2026-11-10', N'2026-11-12T10:30:00', 25.00, N'transferencia', N'PBI26-TRF-0166', N'aplicado'),
        (N'GYM-SOC-0072', N'2026-11-06', N'2026-11-12T10:45:00', 115.00, N'efectivo', N'PBI26-EFE-0167', N'aplicado'),
        (N'GYM-SOC-0071', N'2026-11-12', N'2026-11-12T11:50:00', 70.00, N'efectivo', N'PBI26-EFE-0168', N'aplicado'),
        (N'GYM-SOC-0121', N'2026-11-12', N'2026-11-12T19:40:00', 25.00, N'efectivo', N'PBI26-EFE-0169', N'aplicado');


    IF (SELECT COUNT(*) FROM #PagosExtra) <> 169
    BEGIN
        ;THROW 51014, 'El lote de pagos debe contener 169 filas.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM #PagosExtra AS x
        LEFT JOIN dbo.Socio AS s ON s.documento = x.documento
        OUTER APPLY (
            SELECT COUNT(*) AS coincidencias
            FROM dbo.MembresiaSocio AS m
            WHERE m.id_socio = s.id_socio
              AND m.fecha_inicio = x.inicio_membresia
        ) AS busqueda
        WHERE s.id_socio IS NULL OR busqueda.coincidencias <> 1
    )
    BEGIN
        ;THROW 51015, 'Pago: no se encuentra una unica membresia para el documento y fecha.', 1;
    END;

    -- Si existe una referencia PBI26 que no corresponde a los valores
    -- esperados, detenerse. No sobrescribir ni editar pagos existentes.
    IF EXISTS (
        SELECT 1 FROM #PagosExtra AS x
        JOIN dbo.Pago AS p ON p.referencia = x.referencia
        JOIN dbo.MembresiaSocio AS m ON m.id_membresia = p.id_membresia
        JOIN dbo.Socio AS s ON s.id_socio = m.id_socio
        WHERE s.documento <> x.documento
           OR m.fecha_inicio <> x.inicio_membresia
           OR p.fecha_pago <> x.fecha_pago
           OR p.monto <> x.monto
           OR p.metodo_pago <> x.metodo_pago
           OR p.estado <> x.estado
    )
    BEGIN
        ;THROW 51016, 'Pago: referencia ya utilizada con valores distintos.', 1;
    END;

    -- Pagos nuevos: la referencia es el identificador de negocio del lote.
    INSERT INTO dbo.Pago
        (id_membresia, fecha_pago, monto, metodo_pago, referencia, estado)
    SELECT m.id_membresia, x.fecha_pago, x.monto,
           x.metodo_pago, x.referencia, x.estado
    FROM #PagosExtra AS x
    JOIN dbo.Socio AS s ON s.documento = x.documento
    JOIN dbo.MembresiaSocio AS m ON m.id_socio = s.id_socio
                                  AND m.fecha_inicio = x.inicio_membresia
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Pago AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.referencia = x.referencia
    );

    -- ------------------------------------------------------------------------
    -- VALIDACION INTEGRAL ANTES DE HACER COMMIT
    -- Se valida toda la BD, no solamente los datos de este lote.
    -- ------------------------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM dbo.Reserva AS r
        LEFT JOIN dbo.Socio AS s ON s.id_socio = r.id_socio
        LEFT JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
        WHERE s.id_socio IS NULL OR sc.id_sesion IS NULL
    )
    BEGIN
        ;THROW 51017, 'Validacion: hay reservas con FK de socio o sesion invalidas.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.Pago AS p
        LEFT JOIN dbo.MembresiaSocio AS m ON m.id_membresia = p.id_membresia
        WHERE m.id_membresia IS NULL
    )
    BEGIN
        ;THROW 51018, 'Validacion: hay pagos sin membresia valida.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.Reserva
        WHERE estado = N'confirmada'
        GROUP BY id_socio, id_sesion
        HAVING COUNT(*) > 1
    )
    BEGIN
        ;THROW 51019, 'Validacion: existe mas de una reserva confirmada de un socio en una sesion.', 1;
    END;

    IF EXISTS (
        SELECT 1 FROM dbo.Reserva AS r
        JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
        WHERE r.estado = N'confirmada'
        GROUP BY sc.id_sesion, sc.cupo_maximo
        HAVING COUNT(*) > sc.cupo_maximo
    )
    BEGIN
        ;THROW 51020, 'Validacion: reservas confirmadas superan el cupo.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.MembresiaSocio AS m
        JOIN dbo.Pago AS p ON p.id_membresia = m.id_membresia
        GROUP BY m.id_membresia, m.precio_acordado
        HAVING SUM(CASE WHEN p.estado = N'aplicado' THEN p.monto ELSE 0 END)
               > m.precio_acordado
    )
    BEGIN
        ;THROW 51021, 'Validacion: pagos aplicados superan precio de membresia.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.Reserva AS r
        JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
        WHERE r.fecha_reserva >= sc.inicio
    )
    BEGIN
        ;THROW 51022, 'Validacion: alguna reserva es posterior al inicio de su sesion.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.Reserva AS r
        JOIN dbo.Socio AS s ON s.id_socio = r.id_socio
        WHERE CONVERT(DATE, r.fecha_reserva) < s.fecha_registro
    )
    BEGIN
        ;THROW 51023, 'Validacion: una reserva se realizo antes del registro del socio.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.Reserva AS r
        JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
        WHERE r.estado = N'confirmada' AND sc.estado = N'cancelada'
    )
    BEGIN
        ;THROW 51024, 'Validacion: hay reservas confirmadas en sesiones canceladas.', 1;
    END;

    -- Verificar que TODO el lote este presente (independiente de los IDENTITY).
    IF (SELECT COUNT(*) FROM dbo.Socio AS s
        JOIN #SociosExtra AS x ON x.documento = s.documento) <> 140
       OR (SELECT COUNT(*) FROM dbo.SesionClase AS sc
           JOIN dbo.Clase AS c ON c.id_clase = sc.id_clase
           JOIN dbo.Entrenador AS e ON e.id_entrenador = sc.id_entrenador
           JOIN #SesionesExtra AS x ON x.nombre_clase = c.nombre
                AND x.email_entrenador = e.email AND x.inicio = sc.inicio) <> 70
       OR (SELECT COUNT(*) FROM dbo.MembresiaSocio AS m
           JOIN dbo.Socio AS s ON s.id_socio = m.id_socio
           JOIN #MembresiasExtra AS x ON x.documento = s.documento
                AND x.fecha_inicio = m.fecha_inicio) <> 140
       OR (SELECT COUNT(*) FROM dbo.Reserva AS r
           JOIN dbo.Socio AS s ON s.id_socio = r.id_socio
           JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
           JOIN dbo.Clase AS c ON c.id_clase = sc.id_clase
           JOIN dbo.Entrenador AS e ON e.id_entrenador = sc.id_entrenador
           JOIN #ReservasExtra AS x ON x.documento = s.documento
                AND x.nombre_clase = c.nombre AND x.email_entrenador = e.email
                AND x.inicio_sesion = sc.inicio AND x.fecha_reserva = r.fecha_reserva
                AND x.estado = r.estado) <> 279
       OR (SELECT COUNT(*) FROM dbo.Pago AS p
           JOIN #PagosExtra AS x ON x.referencia = p.referencia) <> 169
    BEGIN
        ;THROW 51025, 'Validacion: no se completo la carga esperada del lote.', 1;
    END;

    -- Totales de la base demostrativa: se requiere solo el lote original y
    -- el conjunto adicional. Si hay otras pruebas mezcladas, no tocar.
    IF (SELECT COUNT(*) FROM dbo.Socio) <> 150
       OR (SELECT COUNT(*) FROM dbo.SesionClase) <> 80
       OR (SELECT COUNT(*) FROM dbo.MembresiaSocio) <> 150
       OR (SELECT COUNT(*) FROM dbo.Reserva) <> 300
       OR (SELECT COUNT(*) FROM dbo.Pago) <> 180
    BEGIN
        ;THROW 51029, 'Totales inesperados: revisar si se mezclaron otros datos o falta carga inicial.', 1;
    END;

    -- Limpieza para permitir una segunda ejecucion en la MISMA ventana SSMS.
    DROP TABLE #PagosExtra;
    DROP TABLE #ReservasExtra;
    DROP TABLE #MembresiasExtra;
    DROP TABLE #SesionesExtra;
    DROP TABLE #SociosExtra;

    COMMIT TRANSACTION;
    PRINT N'Carga correcta: lote adicional completo, sin depender de IDENTITY.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'Carga revertida. No se guardaron cambios parciales del lote.';
    ;THROW;
END CATCH;
GO

-- ============================================================================
-- RESULTADOS Y VALIDACIONES PARA COMPARTIR CON LOS COMPANEROS
-- Todos los valores de la columna incidencias deben dar CERO.
-- Estas consultas son de solo lectura: se pueden ejecutar cuando sea necesario.
-- ============================================================================
SELECT N'Socio' AS Tabla, COUNT(*) AS Registros, 150 AS Esperados FROM dbo.Socio
UNION ALL SELECT N'Entrenador', COUNT(*), 5 FROM dbo.Entrenador
UNION ALL SELECT N'Clase', COUNT(*), 5 FROM dbo.Clase
UNION ALL SELECT N'PlanMembresia', COUNT(*), 3 FROM dbo.PlanMembresia
UNION ALL SELECT N'SesionClase', COUNT(*), 80 FROM dbo.SesionClase
UNION ALL SELECT N'MembresiaSocio', COUNT(*), 150 FROM dbo.MembresiaSocio
UNION ALL SELECT N'Reserva', COUNT(*), 300 FROM dbo.Reserva
UNION ALL SELECT N'Pago', COUNT(*), 180 FROM dbo.Pago;

SELECT N'Reservas sin socio o sesion valida' AS Comprobacion, COUNT(*) AS Incidencias
FROM dbo.Reserva AS r
LEFT JOIN dbo.Socio AS s ON s.id_socio = r.id_socio
LEFT JOIN dbo.SesionClase AS sc ON sc.id_sesion = r.id_sesion
WHERE s.id_socio IS NULL OR sc.id_sesion IS NULL
UNION ALL
SELECT N'Pagos sin membresia valida', COUNT(*)
FROM dbo.Pago AS p
LEFT JOIN dbo.MembresiaSocio AS m ON m.id_membresia = p.id_membresia
WHERE m.id_membresia IS NULL
UNION ALL
SELECT N'Reservas confirmadas duplicadas', COUNT(*)
FROM (
    SELECT id_socio, id_sesion FROM dbo.Reserva
    WHERE estado = N'confirmada'
    GROUP BY id_socio, id_sesion HAVING COUNT(*) > 1
) AS x
UNION ALL
SELECT N'Sesiones sobre cupo', COUNT(*)
FROM (
    SELECT sc.id_sesion
    FROM dbo.SesionClase AS sc
    JOIN dbo.Reserva AS r ON r.id_sesion = sc.id_sesion
    WHERE r.estado = N'confirmada'
    GROUP BY sc.id_sesion, sc.cupo_maximo
    HAVING COUNT(*) > sc.cupo_maximo
) AS x
UNION ALL
SELECT N'Membresias con sobrepago aplicado', COUNT(*)
FROM (
    SELECT m.id_membresia
    FROM dbo.MembresiaSocio AS m
    JOIN dbo.Pago AS p ON p.id_membresia = m.id_membresia
    GROUP BY m.id_membresia, m.precio_acordado
    HAVING SUM(CASE WHEN p.estado = N'aplicado' THEN p.monto ELSE 0 END)
           > m.precio_acordado
) AS x;

-- Para Power BI: comparar ingresos variables por mes.
SELECT YEAR(fecha_pago) AS Anio, MONTH(fecha_pago) AS Mes,
       COUNT(*) AS Pagos,
       SUM(CASE WHEN estado = N'aplicado' THEN monto ELSE 0 END) AS IngresosAplicados
FROM dbo.Pago
GROUP BY YEAR(fecha_pago), MONTH(fecha_pago)
ORDER BY Anio, Mes;
GO
