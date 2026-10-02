-- Baseline schema inferred from existing API queries in server.js
-- Generated for voluntariado_hogar_bambi / Voluntariado_Bambi
-- If the live DB differs, adjust before applying 002/003.

CREATE TABLE IF NOT EXISTS personas (
  persona_id SERIAL PRIMARY KEY,
  ci VARCHAR(50),
  nombre VARCHAR(150),
  apellido VARCHAR(150),
  telefono VARCHAR(100),
  email VARCHAR(150),
  fecha_nacimiento DATE,
  residencia TEXT,
  fecha_induccion DATE
);

CREATE TABLE IF NOT EXISTS voluntarios (
  voluntario_id SERIAL PRIMARY KEY,
  persona_id INTEGER NOT NULL REFERENCES personas(persona_id),
  fecha_inicio DATE,
  fecha_retiro DATE,
  estatus VARCHAR(50),
  profesion_oficio TEXT,
  lugar_trabajo TEXT
);

CREATE TABLE IF NOT EXISTS labor_social (
  labor_social_id SERIAL PRIMARY KEY,
  persona_id INTEGER NOT NULL REFERENCES personas(persona_id),
  colegio TEXT,
  nivel TEXT,
  fecha_inicio DATE,
  fecha_culminacion DATE
);

CREATE TABLE IF NOT EXISTS servicio_comunitario_universitario (
  servicio_comunitario_id SERIAL PRIMARY KEY,
  persona_id INTEGER NOT NULL REFERENCES personas(persona_id),
  fecha_inicio DATE,
  fecha_culminacion DATE,
  instituto TEXT,
  carrera TEXT,
  proyecto TEXT
);

CREATE TABLE IF NOT EXISTS pasantia_tesis_proyecto (
  pasantia_tesis_proyecto_id SERIAL PRIMARY KEY,
  persona_id INTEGER NOT NULL REFERENCES personas(persona_id),
  tipo TEXT,
  carrera TEXT,
  instituto TEXT,
  tutor_academico TEXT,
  tutor_institucional TEXT,
  fecha_inicio DATE,
  fecha_culminacion DATE
);

CREATE TABLE IF NOT EXISTS otros (
  otros_id SERIAL PRIMARY KEY,
  persona_id INTEGER NOT NULL REFERENCES personas(persona_id),
  tipo_actividad TEXT,
  fecha_inicio DATE,
  fecha_culminacion DATE,
  institucion TEXT
);
