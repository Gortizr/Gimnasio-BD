/* =====================================================================
   GimnasioDB - 03b_prueba_acceso_denegado.sql
   Demostración de permisos: cada prueba se ejecuta como un usuario
   de la matriz (EXECUTE AS USER) y se vuelve al usuario propio con REVERT.

   Requisito: haber ejecutado 03_seguridad.sql.

   Forma de uso en SSMS: seleccionar UNA prueba (desde su comentario
   hasta su GO) y presionar F5. El error aparece en la pestaña Messages.
   Ninguna prueba deja cambios en los datos.
   ===================================================================== */

USE GimnasioDB;
GO

/* ---------------------------------------------------------------------
   PRUEBA 0. ¿Quién soy?
   Debe mostrar dbo (el usuario conectado es el dueño de la base).
   --------------------------------------------------------------------- */

SELECT USER_NAME() AS usuario_actual;
GO

/* ---------------------------------------------------------------------
   PRUEBA 1. Recepción intenta BORRAR un pago.
   Esperado: Msg 229, "The DELETE permission was denied on the object
   'Pago'". Motivo: DENY DELETE ON SCHEMA::dbo TO rol_recepcion.
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_recepcion';
SELECT USER_NAME() AS usuario_actual;

DELETE FROM dbo.Pago
WHERE id_pago = 1;

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 2. Entrenador intenta VER los pagos.
   Esperado: Msg 229, "The SELECT permission was denied on the object
   'Pago'". Motivo: DENY SELECT ON dbo.Pago TO rol_entrenador.
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_entrenador';

SELECT id_pago, monto
FROM dbo.Pago;

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 3. Entrenador intenta ver datos privados del socio.
   La primera consulta funciona (columnas permitidas).
   La segunda falla: Msg 230, "The SELECT permission was denied on the
   column 'documento' of the object 'Socio'". Permiso por columna.
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_entrenador';

SELECT id_socio, nombre, apellido
FROM dbo.Socio;

SELECT nombre, documento, telefono
FROM dbo.Socio;

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 4. Reportes lee la vista, pero no la tabla.
   La vista funciona; la tabla dbo.Socio da Msg 229.
   Motivo: rol_reportes solo tiene SELECT sobre el esquema reportes.
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_reportes';

SELECT *
FROM reportes.vw_OcupacionSesion;

SELECT *
FROM dbo.Socio;

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 5. El administrador de la aplicación intenta borrar la auditoría.
   Esperado: Msg 229 sobre 'CambioPago'.
   Motivo: DENY DELETE ON SCHEMA::auditoria TO rol_administrador.
   Ningún rol de la aplicación puede borrar el historial.
   (sa y dbo sí podrían: DENY no limita al administrador del servidor.)
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_admin';

DELETE FROM auditoria.CambioPago;

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 6. Permisos efectivos de un usuario.
   Lista lo que usuario_recepcion SÍ puede hacer sobre dbo.Pago.
   DELETE no aparece en la lista.
   --------------------------------------------------------------------- */

EXECUTE AS USER = N'usuario_recepcion';

SELECT
    entity_name AS objeto,
    subentity_name AS columna,
    permission_name AS permiso
FROM fn_my_permissions(N'dbo.Pago', N'OBJECT')
WHERE subentity_name = N'';

REVERT;
GO

/* ---------------------------------------------------------------------
   PRUEBA 7. Auditoría en acción (cambio permitido).
   Recepción anula un pago dentro de una transacción.
   Se ve la fila nueva en auditoria.CambioPago con usuario_recepcion.
   ROLLBACK deshace el cambio y la fila de auditoría:
   los datos quedan igual que antes.
   --------------------------------------------------------------------- */

BEGIN TRANSACTION;

EXECUTE AS USER = N'usuario_recepcion';

UPDATE dbo.Pago
SET estado = N'anulado'
WHERE id_pago = 11;

REVERT;

SELECT *
FROM auditoria.CambioPago;

ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   PRUEBA 8. GRANT y REVOKE sobre el mismo permiso.
   Paso 1: se da UPDATE al rol de reportes sobre dbo.Clase -> se puede.
   Paso 2: REVOKE quita ese GRANT -> vuelve a no tener permiso.
   Todo dentro de una transacción con ROLLBACK, sin dejar cambios.
   El UPDATE no lleva WHERE porque un WHERE exige también permiso
   de SELECT, y aquí solo se quiere probar UPDATE.
   Esperado: el primer UPDATE funciona (5 filas); el segundo da Msg 229.
   --------------------------------------------------------------------- */

BEGIN TRANSACTION;

GRANT UPDATE ON dbo.Clase TO rol_reportes;

EXECUTE AS USER = N'usuario_reportes';
UPDATE dbo.Clase SET estado = N'activo';
REVERT;

REVOKE UPDATE ON dbo.Clase TO rol_reportes;

EXECUTE AS USER = N'usuario_reportes';
UPDATE dbo.Clase SET estado = N'activo';
REVERT;

ROLLBACK TRANSACTION;
GO

/* ---------------------------------------------------------------------
   PRUEBA 9. Identidad real de Power BI (login_powerbi).
   EXECUTE AS LOGIN actúa como ese login, igual que si Power BI
   se conectara con él.
   Esperado: es_db_owner = 0; la vista se lee bien;
   dbo.Socio da Msg 229 (no tiene acceso a las tablas).
   --------------------------------------------------------------------- */

EXECUTE AS LOGIN = N'login_powerbi';

SELECT
    SUSER_SNAME() AS login_actual,
    USER_NAME() AS usuario_actual,
    IS_MEMBER(N'db_owner') AS es_db_owner,
    IS_MEMBER(N'rol_reportes') AS es_rol_reportes;

SELECT *
FROM reportes.vw_SaldoMembresia;

SELECT *
FROM dbo.Socio;

REVERT;
GO

/* ---------------------------------------------------------------------
   CIERRE. Confirmar que volviste a tu usuario.
   Debe decir dbo. Si muestra otro usuario, ejecutar REVERT;
   --------------------------------------------------------------------- */

SELECT USER_NAME() AS usuario_actual;
GO
