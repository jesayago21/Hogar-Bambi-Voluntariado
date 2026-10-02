-- Polymorphic observations / notes history for all modules

CREATE TABLE IF NOT EXISTS observaciones (
  observacion_id SERIAL PRIMARY KEY,
  entidad TEXT NOT NULL,
  entidad_id INTEGER NOT NULL,
  texto TEXT NOT NULL,
  fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  autor TEXT,
  origen TEXT NOT NULL DEFAULT 'manual',
  CONSTRAINT observaciones_entidad_check CHECK (
    entidad IN (
      'voluntario',
      'labor_social',
      'servicio_comunitario',
      'pasantia',
      'otros'
    )
  ),
  CONSTRAINT observaciones_origen_check CHECK (
    origen IN ('manual', 'importacion')
  )
);

CREATE INDEX IF NOT EXISTS idx_observaciones_entidad
  ON observaciones (entidad, entidad_id);
