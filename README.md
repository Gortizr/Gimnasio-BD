# Gimnasio-BD

Proyecto final de Administración de Bases de Datos: **Sistema de Reservas de Gimnasio (GimnasioDB)**.

- **Gestor:** SQL Server 2025 Developer en Docker (contenedor `sqlserver-2025`, servidor `localhost,1434`)
- **Herramientas:** SQL Server Management Studio (SSMS), Power BI Desktop, PowerShell
- **Docente:** Ing. James Edward Humberstone Morales

## Integrantes

| Integrante | Carnet | Responsabilidad |
|---|---|---|
| Angel Leonel Choto Garcia | 00185725 | Modelo de datos, carga de datos y respaldos |
| Diego Gabriel Bonilla Comandari | 00147325 | Seguridad: esquemas, roles, permisos y auditoría |
| Pablo Antonio Brito Elias | 00179025 | Consultas, índices, dimensionamiento y respaldos |
| Guillermo Andres Ortiz Reyes | 00131725 | Dashboard en Power BI |

## Estructura del repositorio

```
Gimnasio-BD/
├── scripts/              Scripts principales (ejecutar en orden)
│   ├── optimizacion/     Medición de consultas e índices
│   └── respaldos/        Respaldo diferencial, monitoreo y archivado
├── evidencias/           Capturas, planes de ejecución (.sqlplan) y mediciones
├── powerbi/              Dashboard (.pbix) y capturas de sus páginas
└── informe/              Informe técnico y matriz de permisos
```

## Requisitos previos

1. Contenedor de SQL Server 2025 en ejecución, con autenticación de SQL Server habilitada (modo mixto).
2. SQL Server Agent habilitado en el contenedor.
3. Conexión en SSMS a `localhost,1434`.

## Orden de ejecución (desde cero)

Abrir cada archivo en SSMS y ejecutarlo con F5, salvo donde se indique otra cosa.

### 1. Base de datos y datos

| Paso | Archivo | Qué hace |
|---|---|---|
| 1 | `scripts/01_Crear_base.sql` | Crea GimnasioDB y sus 8 tablas. Solo funciona si la base no existe |
| 2 | `scripts/02_datos_prueba.sql` | Carga los datos de prueba (10 socios, 21 reservas, 11 pagos…) |
| 3 | `scripts/03_datos_adicionales_dashboard.sql` | Completa los datos: 150 socios, 80 sesiones, 300 reservas y 180 pagos. Las incidencias deben dar 0 |

### 2. Seguridad

| Paso | Archivo | Qué hace |
|---|---|---|
| 4 | `scripts/03_seguridad.sql` | Esquemas `reportes` y `auditoria`, roles, usuarios, permisos, auditoría de pagos y login de Power BI. **Antes de ejecutarlo, cambiar la contraseña de `login_powerbi` en la sección 5.2** (no subir la contraseña real) |
| 5 | `scripts/03b_prueba_acceso_denegado.sql` | Pruebas de acceso permitido y denegado. Ejecutar **una prueba a la vez**, desde su comentario hasta su `GO`. Al final, el bloque CIERRE debe mostrar `dbo` |

`scripts/03r_reinicio_laboratorio.sql` **no forma parte del orden normal**: solo sirve para borrar la seguridad y empezar de cero en laboratorio (se pierde el historial de auditoría).

### 3. Consultas e índices

| Paso | Archivo | Qué hace |
|---|---|---|
| 6 | `scripts/04_consultas.sql` | Crea las funciones `fn_Consulta1…3` (consultas con funciones de ventana) |
| 6b | `scripts/04b_vistas_reportes.sql` | Crea las vistas `reportes.vw_Consulta1…3` que usa el dashboard |
| 7 | `scripts/optimizacion/05a_datos_volumen.sql` | Crea la base de pruebas `GimnasioDB_Perf` con volumen alto. Ajustar `@ruta_bak` y ejecutar el LOTE 1 y luego el LOTE 2 |
| 8 | `scripts/optimizacion/05b_indices_y_planes.sql` | Mide las consultas antes y después de los índices en `GimnasioDB_Perf` (activar Ctrl+M) |
| 9 | `scripts/optimizacion/05d_aplicar_indices_gimnasiodb.sql` | Aplica los índices evaluados en GimnasioDB |

### 4. Respaldos

| Paso | Archivo | Qué hace |
|---|---|---|
| 10 | `scripts/04_crear_historial_backup.sql` | Comandos de Docker para crear `/backup/GimnasioDB`. **Se ejecutan en PowerShell, no en SSMS** |
| 11 | `scripts/05_Operador_Gym.sql` | Crea el operador que recibe los avisos de los jobs |
| 12 | `scripts/06_Backup_FULL.sql` | Job `GimnasioDB_Backup_FULL` (respaldo completo diario) |
| 13 | `scripts/07_Backup_LOG.sql` | Job `GimnasioDB_Backup_LOG` (respaldo del log cada 15 minutos) |
| 14 | — | Ejecutar una vez el job FULL desde SQL Server Agent (Start Job). Los respaldos diferencial y de log necesitan un FULL previo |
| 15 | `scripts/respaldos/06_jobs_respaldo.sql` | Job `GimnasioDB - Respaldo Diferencial` (diario, 16:07) |
| 16 | `scripts/respaldos/06b_probar_jobs_y_monitoreo.sql` | Prueba el job diferencial y consulta historial y archivos |
| 17 | `scripts/respaldos/07_archivar_respaldos.ps1` | Mueve los respaldos con más de 7 días a `/backup/GimnasioDB_Archivo` sin borrarlos. Se programa en el Programador de tareas de Windows (diario, 18:30) |

`scripts/08_archivo_semanal.ps1` es la versión anterior del archivado (semanal). Fue reemplazada por `respaldos/07_archivar_respaldos.ps1`.

### 5. Dashboard

| Paso | Archivo | Qué hace |
|---|---|---|
| 18 | `powerbi/Dashboard_GimnasioDB.pbix` | Abrir en Power BI Desktop → Transformar datos → Configuración de origen de datos → credenciales de **Base de datos** con `login_powerbi`. Ese usuario solo puede leer las vistas del esquema `reportes` |

## Usuarios y roles

| Usuario | Rol | Acceso |
|---|---|---|
| usuario_admin | rol_administrador | Datos de dbo; lectura de reportes y auditoría. No modifica la auditoría |
| usuario_recepcion | rol_recepcion | Registra socios, membresías, reservas y pagos. No borra |
| usuario_entrenador | rol_entrenador | Consulta clases, sesiones y reservas; del socio solo id, nombre y apellido. No ve pagos |
| usuario_reportes | rol_reportes | Solo lectura del esquema `reportes` (pruebas) |
| usuario_powerbi (`login_powerbi`) | rol_reportes | Conexión de Power BI, solo lectura del esquema `reportes` |
| sa | sysadmin | Dueño de los jobs de respaldo; único que crea tablas |
