# Resumen de cambios — Voluntariado Desktop App

Documento de referencia con lo implementado en backend, base de datos, Flutter e importación de datos.

---

## 1. Backend (API Node.js + Express)

### Estructura

| Ruta / archivo | Rol |
|----------------|-----|
| `backend/server.js` | Arranque de la API, montaje de rutas |
| `backend/db/pool.js` | Conexión PostgreSQL vía `.env` |
| `backend/lib/crudFactory.js` | CRUD genérico (listar, crear, editar, archivar, restaurar, borrar permanente) |
| `backend/lib/validate.js` | Validación y coerción de fechas/enteros |
| `backend/routes/*.js` | Voluntarios, Labor Social, Servicio Comunitario, Pasantías, Otros, Observaciones |

### Endpoints por módulo

Prefijos:

- `/api/volunteers`
- `/api/students/labor_social`
- `/api/students/community_service`
- `/api/students/internship_thesis_project`
- `/api/others`
- `/api/observaciones` (+ rutas anidadas `/:id/observaciones`)

Operaciones:

| Método | Ruta | Acción |
|--------|------|--------|
| `GET /` | Lista (query: `soloArchivados`, `incluirArchivados`, `q`) |
| `GET /:id` | Detalle |
| `POST /` | Crear |
| `PUT /:id` | Actualizar |
| `DELETE /:id` | Archivar (borrado lógico, `activo = false`) |
| `POST /:id/restaurar` | Restaurar archivado |
| `DELETE /:id/permanente` | Borrado definitivo (solo si ya está archivado) |

### Validación de fechas

`optionalDate` acepta `DD/MM/AAAA`, `AAAA-MM-DD` e ISO; normaliza a `YYYY-MM-DD` para Postgres.

### Configuración local

- Credenciales en `backend/.env` (plantilla: `backend/.env.example`)
- Docker Compose: Postgres + API local (`backend/docker-compose.yml`)

---

## 2. Base de datos (migraciones)

| Archivo | Contenido |
|---------|-----------|
| `001_baseline.sql` | Tablas: `personas`, `voluntarios`, `labor_social`, `servicio_comunitario_universitario`, `pasantia_tesis_proyecto`, `otros` |
| `002_campos_modulos.sql` | Campos de Excel (`anio`, `estatus`, `asistencias`, `actividad`, `carrera`, etc.) + flag `activo` |
| `003_observaciones.sql` | Tabla polimórfica `observaciones` |
| `004_labor_social_expediente.sql` | Columna `expediente` en Labor Social (columna Excel «Otro») |

Ejecución: `runMigrations()` aplica `.sql` en orden y registra en `schema_migrations`.

---

## 3. App Flutter (escritorio)

### CRUD en UI

- Listas con búsqueda (nombre, CI, **fecha de inicio**)
- Switch **Solo archivados** (muestra únicamente archivados)
- Crear / editar con diálogo reutilizable y date picker
- Archivar / restaurar con confirmación
- **Eliminar definitivamente** solo desde archivados (con confirmación)

### Voluntarios

- Asistencias editables en el detalle (+ / − / valor manual), fuera del formulario general
- Estatus Activo/Inactivo gestionado en el detalle (no como texto libre en editar)

### Estudiantes (detalle)

Formularios completos con: teléfono, email, año, fecha inicio, fecha culminación, inducción (lectura).

Labor Social además: **Expediente** (editable).

### Utilidades nuevas

| Archivo | Uso |
|---------|-----|
| `lib/presentation/utils/date_search.dart` | Formato corto y búsqueda por fecha |
| `lib/presentation/utils/form_body.dart` | Armado del body API (fechas/enteros) |
| `lib/presentation/widgets/record_form_dialog.dart` | Formulario crear/editar |
| `lib/presentation/widgets/confirm_archive_dialog.dart` | Confirmaciones archivar / borrar permanente |
| `lib/presentation/widgets/observaciones_panel.dart` | Historial de observaciones por registro |
| `lib/presentation/widgets/data_table_list.dart` | Tabla virtualizada de listas + barra superior |
| `lib/presentation/widgets/detail_layout.dart` | Detalle compacto en dos columnas |
| `lib/presentation/widgets/import_excel_dialog.dart` | Descargar plantilla e importar `.xlsx` con resumen previo |

### Importar Excel (desde cada lista)

En las 5 listas hay un botón **Importar Excel**:

1. **Descargar plantilla** — archivo `.xlsx` con columnas reales de la BD y desplegable de Estatus.
2. **Seleccionar archivo lleno** — el backend valida y muestra resumen (crear / actualizar / errores).
3. **Confirmar importación** — inserta o actualiza; la lista se recarga al cerrar.

Reglas: cédula obligatoria; fechas `DD/MM/AAAA`; celdas vacías no borran datos al actualizar.
**Labor Social y Voluntarios:** un solo registro por cédula. En Labor Social se guarda la participación más reciente (por fecha de inicio); una fila más antigua solo completa campos vacíos.
En Servicio Comunitario, Pasantías y Otros una misma cédula puede tener varios registros: la clave es **persona + año + fecha de inicio** (en Otros también tipo de actividad). Si coinciden, se actualiza (incluido el **estatus** si cambió); si la fecha/año cambian, se crea otro.

### Labor Social unificado (DEF + copias 2025 y 2026)

Se reconstruyó Labor Social con `merge-labor-social.js`: 404 filas del DEF, 41 de la copia 2025 y 27 de la 2026 quedaron en **424 personas** (368 solo en el DEF, 32 del DEF actualizadas con las copias y 24 nuevas desde las copias). En cada campo se tomó el valor más reciente no vacío. Quedaron 28 personas sin cédula; están listadas en `docs/labor_social_merge_reporte.csv`. El Excel resultante para revisar está en `docs/labor_social_unificado.xlsx`.

---

## 4. Importación de CSV

### Scripts

| Script | Descripción |
|--------|-------------|
| `npm run import` | Solo cuadro general de voluntarios (`docs/`) |
| `npm run import -- --all-modules` | Voluntarios + estudiantes (`docs/` y `docs/backup/`) |
| `npm run import -- --dry-run` | Vista previa sin escribir |
| `npm run import:purge-students` | Vista previa de purga; con `--confirm` borra datos de estudiantes |

### Mapeo archivo → módulo

| CSV | Módulo en la app |
|-----|------------------|
| `CUADRO GRAL ... Voluntarios HBV.csv` | Voluntarios |
| `Bdd LS.xlsx - Hoja1.csv` | Labor Social |
| `... SERVICIO COMUNITARIO ... Integral SC.csv` | Servicio Comunitario |
| `... Pasantias ... Base de Datos.csv` | Pasantías / tesis / proyectos |
| `... Post Grado ... Base de Datos.csv` | Otros (`tipo_actividad = Postgrado`) |

### Reglas de importación (estudiantes)

1. Clave de upsert: **persona + año + fecha de inicio** (misma persona en años distintos = registros separados).
2. Filas **sin cédula**: se importan; se busca persona por nombre solo entre personas sin CI; se anotan en el reporte.
3. Columna **Otro** de Labor Social → campo `expediente` (no observación).
4. Observaciones del Excel → tabla `observaciones` con `origen = importacion`.
5. Estatus se normalizan (p. ej. «Entregó informe» → `Culminó`); el texto original puede guardarse como observación.

### Reportes

- `docs/importacion-rechazados.csv` — última corrida (p. ej. «Importada sin cédula»)
- `docs/backup/importacion-rechazados-estudiantes.csv` — respaldo de un reporte anterior

---

## 5. Estado de datos tras la última importación (local)

| Módulo | Registros |
|--------|-----------|
| Voluntarios | 289 |
| Labor Social | 467 |
| Servicio Comunitario | 1.306 |
| Pasantías | 128 |
| Otros (Postgrado) | 24 |

- 126 personas sin cédula importadas (listadas en el reporte).
- Voluntarios de prueba (`V99990001`, `30035353`) eliminados definitivamente.
- Todos los registros de Labor Social tienen `expediente` poblado cuando venía en el Excel.

---

## 6. Cómo probar en local

1. Backend: desde `backend/`, `docker compose up -d` (si aplica) y `node server.js` (o el script npm correspondiente).
2. Flutter: `flutter run -d windows` (hot restart `R` tras cambios de UI).
3. Reimportar estudiantes: `npm run import -- --all-modules` (idempotente por la clave persona+año+inicio).

---

## 7. Pendientes / notas

- Campos que el Excel no trae y quedan vacíos: `nivel` (Labor Social), `proyecto` (Servicio Comunitario), tutores en Pasantías.
- Algunas cédulas de Servicio Comunitario llegan con formato irregular; se normalizan a dígitos cuando es posible.
- Completar CI de las 126 personas importadas sin cédula desde la app o con un script futuro.
- Para llevar esto a la máquina de Hogar Bambi: usar las credenciales reales en `.env` y volver a correr migraciones + import allí (ver también `Cuando vayas a la máquina de Hogar Bambi.docx`).
