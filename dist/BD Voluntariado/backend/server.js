const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const express = require('express');
const cors = require('cors');

const volunteers = require('./routes/volunteers');
const laborSocial = require('./routes/laborSocial');
const communityService = require('./routes/communityService');
const internship = require('./routes/internship');
const others = require('./routes/others');
const observaciones = require('./routes/observaciones');
const { createNestedRouter } = require('./routes/observaciones');

const app = express();
const port = Number(process.env.PORT) || 8000;

app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

// Observaciones nested mounts first (more specific paths)
app.use('/api/volunteers/:id/observaciones', createNestedRouter('voluntario'));
app.use(
  '/api/students/labor_social/:id/observaciones',
  createNestedRouter('labor_social')
);
app.use(
  '/api/students/community_service/:id/observaciones',
  createNestedRouter('servicio_comunitario')
);
app.use(
  '/api/students/internship_thesis_project/:id/observaciones',
  createNestedRouter('pasantia')
);
app.use('/api/others/:id/observaciones', createNestedRouter('otros'));

app.use('/api/volunteers', volunteers);
app.use('/api/students/labor_social', laborSocial);
app.use('/api/students/community_service', communityService);
app.use('/api/students/internship_thesis_project', internship);
app.use('/api/others', others);
app.use('/api/observaciones', observaciones);

app.listen(port, '0.0.0.0', () => {
  console.log(`API funcionando en http://localhost:${port}`);
});
