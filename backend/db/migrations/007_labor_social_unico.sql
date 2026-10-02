-- Labor Social: un solo registro por persona (se conserva el mas reciente)
CREATE TEMP TABLE ls_keep ON COMMIT DROP AS
SELECT DISTINCT ON (persona_id)
  persona_id,
  labor_social_id AS keep_id
FROM labor_social
ORDER BY persona_id, fecha_inicio DESC NULLS LAST, labor_social_id DESC;

UPDATE observaciones o
SET entidad_id = k.keep_id
FROM labor_social ls
JOIN ls_keep k ON k.persona_id = ls.persona_id
WHERE o.entidad = 'labor_social'
  AND o.entidad_id = ls.labor_social_id
  AND ls.labor_social_id <> k.keep_id;

DELETE FROM labor_social ls
USING ls_keep k
WHERE ls.persona_id = k.persona_id
  AND ls.labor_social_id <> k.keep_id;

DROP INDEX IF EXISTS idx_labor_social_match;

CREATE UNIQUE INDEX IF NOT EXISTS labor_social_persona_unique
  ON labor_social (persona_id);
