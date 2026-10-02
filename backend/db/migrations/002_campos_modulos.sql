-- New module fields, soft-delete flags, and unique CI for upsert

ALTER TABLE personas
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

-- Index on normalized CI for upsert lookups (non-unique: legacy data may have duplicates)
CREATE INDEX IF NOT EXISTS idx_personas_ci_norm
  ON personas ((regexp_replace(ci, '[^0-9A-Za-z]', '', 'g')));

ALTER TABLE voluntarios
  ADD COLUMN IF NOT EXISTS asistencias INTEGER,
  ADD COLUMN IF NOT EXISTS actividad TEXT,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE labor_social
  ADD COLUMN IF NOT EXISTS anio INTEGER,
  ADD COLUMN IF NOT EXISTS estatus TEXT,
  ADD COLUMN IF NOT EXISTS carrera TEXT,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE servicio_comunitario_universitario
  ADD COLUMN IF NOT EXISTS anio INTEGER,
  ADD COLUMN IF NOT EXISTS estatus TEXT,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE pasantia_tesis_proyecto
  ADD COLUMN IF NOT EXISTS anio INTEGER,
  ADD COLUMN IF NOT EXISTS estatus TEXT,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE otros
  ADD COLUMN IF NOT EXISTS anio INTEGER,
  ADD COLUMN IF NOT EXISTS estatus TEXT,
  ADD COLUMN IF NOT EXISTS carrera TEXT,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;
