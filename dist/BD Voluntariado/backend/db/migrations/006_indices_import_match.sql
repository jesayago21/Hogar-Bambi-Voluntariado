-- Indices para coincidencia de importacion Excel (persona + año + fecha_inicio)
CREATE INDEX IF NOT EXISTS idx_labor_social_match
  ON labor_social (persona_id, anio, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_servicio_comunitario_match
  ON servicio_comunitario_universitario (persona_id, anio, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_pasantia_match
  ON pasantia_tesis_proyecto (persona_id, anio, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_otros_match
  ON otros (persona_id, anio, fecha_inicio, tipo_actividad);
