-- Campo expediente (columna "Otro" del Excel de Labor Social)
ALTER TABLE labor_social
  ADD COLUMN IF NOT EXISTS expediente TEXT;
