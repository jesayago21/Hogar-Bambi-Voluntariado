# Backend API — Voluntariado Hogar Bambi

## Setup

1. Copia `.env.example` a `.env` y pon la contraseña real de Postgres.
2. Instala dependencias: `npm install`
3. Aplica migraciones: `npm run migrate`
4. Arranca la API: `npm start`

Desarrollo local con Docker: `docker compose up -d` (Postgres en puerto 5434).

En la máquina de Hogar Bambi (Postgres ya instalado), solo cambia `backend/.env` a las credenciales reales y el `.env` de Flutter (`API_URL`). No hace falta Docker ahí. Corre `npm run migrate` antes de usar el CRUD nuevo.

## Importación CSV

**Por defecto solo se importa el cuadro general de voluntarios** (`docs/*VOLUNTARIOS*.csv`).

Los demás CSV (Labor Social, Servicio Comunitario, Pasantías, Postgrado) están en `docs/backup/` como respaldo y **no se cargan** salvo que uses `--all-modules`.

```bash
npm run import              # solo cuadro gral voluntarios (upsert por CI)
npm run import:dry          # simulación
npm run import:all          # todos los módulos (lee docs/ y docs/backup/)
```

El reporte de filas rechazadas queda en `../docs/importacion-rechazados.csv`.
Un respaldo de rechazos de la carga de estudiantes está en `../docs/backup/importacion-rechazados-estudiantes.csv`.

### Purga de estudiantes/otros (destructivo)

`import:purge-students` borra **todas** las filas de Labor Social, Servicio Comunitario, Pasantías y Otros, más sus observaciones, y las personas que queden sin vínculo a un voluntario. **No toca voluntarios.**

Por defecto solo muestra una vista previa (base, puerto y conteos) y **no borra nada**:

```bash
npm run import:purge-students              # vista previa
npm run import:purge-students -- --confirm # borra de verdad
```

**En la máquina de Hogar Bambi no corras la purga** sin verificar antes que esos módulos estén realmente vacíos o que quieras eliminarlos a propósito. Si en el futuro hay que volver a cargar estudiantes desde los CSV de respaldo:

```bash
npm run import:all
```

## Endpoints

Cada módulo soporta GET/POST/PUT/DELETE (archivado lógico), restaurar y observaciones.
Ver `server.js` y `routes/` para rutas completas.

## Importación Excel desde la app

Cada módulo expone:

| Método | Ruta | Acción |
|--------|------|--------|
| `GET /plantilla` | Descarga `.xlsx` con columnas de la BD y hoja de instrucciones |
| `POST /importar?preview=true` | Valida el archivo sin escribir; devuelve `{ total, crear, actualizar, errores }` |
| `POST /importar` | Importa filas válidas; devuelve `{ creados, actualizados, errores }` |

Rutas:

- `/api/volunteers/plantilla` y `/api/volunteers/importar`
- `/api/students/labor_social/plantilla` y `/importar`
- `/api/students/community_service/plantilla` y `/importar`
- `/api/students/internship_thesis_project/plantilla` y `/importar`
- `/api/others/plantilla` y `/importar`

Reglas:

- Cédula obligatoria por fila.
- **Voluntarios:** si la cédula ya existe, se **actualiza** (un registro por persona).
- **Labor Social:** **un solo registro por cédula** (índice único por persona). Si la cédula ya existe se actualiza con la fila de Inicio más reciente; una fila con Inicio más antiguo solo completa campos vacíos. Crear desde la app una cédula que ya tiene registro devuelve 409.
- **Servicio Comunitario, Pasantías, Otros:** una misma cédula puede tener **varios registros**. La clave es persona + Año + Fecha de inicio (en Otros también `tipo_actividad`). Misma combinación → actualiza (incluido el **Estatus** si cambió); distinta → crea otro.

### Unificar Labor Social desde los Excel originales

`scripts/import/merge-labor-social.js` lee el DEF (2016 - jun 2025) y las copias 2025 / 2026 de `docs/SC BAMBI FINAL/`, agrupa por cédula (o por nombre si no hay cédula) y fusiona campo a campo: gana el valor más reciente no vacío. Las observaciones de todas las apariciones se conservan.

```bash
node scripts/import/merge-labor-social.js --dry-run   # genera Excel + reporte, no toca la BD
node scripts/import/merge-labor-social.js             # respaldo automático y reemplaza labor_social
```

Salidas: `docs/labor_social_unificado.xlsx` y `docs/labor_social_merge_reporte.csv`.
- Celdas vacías no borran datos existentes al actualizar.
- Fechas en `DD/MM/AAAA`.
- El cuerpo del POST es `multipart/form-data` con campo `archivo` (`.xlsx`, máx. 5 MB).
