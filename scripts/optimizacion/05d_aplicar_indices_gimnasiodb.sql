/* =====================================================================
   05d_aplicar_indices_gimnasiodb.sql
   Aplica en la base REAL (GimnasioDB) los 3 indices evaluados en
   05b. Ejecutar APARTE y SOLO despues de revisar las mediciones de 05b
   (lecturas, CPU, tiempo, plan, tamaño y costo). Si las mediciones no
   justifican algun indice, omitalo y documente el motivo.
   No borra nada: solo crea los indices que falten.
   El tamaño medido de los indices se consulta en el paso 5 de 05b.
   ===================================================================== */
USE GimnasioDB;
GO
IF DB_NAME() <> N'GimnasioDB'
    THROW 50041, N'Contexto incorrecto: este script solo corre en GimnasioDB.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Reserva_Sesion_Estado'
               AND object_id = OBJECT_ID(N'dbo.Reserva'))
    CREATE NONCLUSTERED INDEX IX_Reserva_Sesion_Estado
        ON dbo.Reserva (id_sesion, estado) INCLUDE (id_socio);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SesionClase_Inicio'
               AND object_id = OBJECT_ID(N'dbo.SesionClase'))
    CREATE NONCLUSTERED INDEX IX_SesionClase_Inicio
        ON dbo.SesionClase (inicio) INCLUDE (id_clase, estado, cupo_maximo);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pago_Estado_FechaPago'
               AND object_id = OBJECT_ID(N'dbo.Pago'))
    CREATE NONCLUSTERED INDEX IX_Pago_Estado_FechaPago
        ON dbo.Pago (estado, fecha_pago) INCLUDE (monto);
GO
