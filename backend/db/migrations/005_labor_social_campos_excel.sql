-- Campos del Excel de Labor Social (representante, actividad, carta)
ALTER TABLE labor_social
  ADD COLUMN IF NOT EXISTS representante TEXT,
  ADD COLUMN IF NOT EXISTS telefono_representante TEXT,
  ADD COLUMN IF NOT EXISTS email_representante TEXT,
  ADD COLUMN IF NOT EXISTS actividad_apoyo TEXT,
  ADD COLUMN IF NOT EXISTS fecha_carta_culminacion DATE;
