# Flujo simple: Release y uso en Bambi (sin “entrar al código”)

## Respuestas cortas

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cómo saco el `.exe` Release? | En tu PC: doble clic en **`empaquetar.bat`** (compila Flutter + arma la carpeta lista). |
| ¿En Bambi tengo que descargar Docker? | **Sí, una sola vez** (y Node.js LTS). |
| ¿Tengo que pegar el dump? | **Sí, la primera vez** (para llevar tus datos). Después no. |
| ¿Puedo usarlo sin meterme a la carpeta del proyecto? | **Sí**: llevas solo `dist\BD Voluntariado\` al Escritorio y usas **doble clic** en `BD Voluntariado.exe`. |

---

## En tu PC (ahora)

1. Abre **Docker Desktop** (para poder exportar datos si quieres).
2. (Recomendado) Doble clic en **`exportar-base-local.bat`** → genera el `.dump` en `backups\`.
3. Doble clic en **`empaquetar.bat`**.
   - Corre `flutter build windows --release`
   - Arma la carpeta: **`dist\BD Voluntariado\`**
   - Ahí quedan la app, el backend, los `.bat`, el lanzador y el dump (si había uno).

Esa carpeta `dist\BD Voluntariado` es lo que copias a USB / OneDrive / Escritorio de Bambi.

**No hace falta** llevar toda la carpeta del repositorio (código fuente, `.dart`, etc.).

---

## En Bambi — primera vez (instalación)

### A) Instalar una sola vez (como cualquier programa)

1. **Docker Desktop** → instalar, reiniciar si pide, dejarlo abierto.
2. **Node.js LTS** → instalar (https://nodejs.org).

### B) Pegar la carpeta

Copia `BD Voluntariado` por ejemplo a:

`C:\Users\Public\Desktop\BD Voluntariado\`

o al Escritorio.

### C) Datos (solo la primera vez)

1. Abre **Docker Desktop** y espera a que esté listo.
2. Doble clic en **`restaurar-en-bambi.bat`** (usa solo el `.dump` más reciente de `backups\`).
3. Cuando pida, escribe `SI` y Enter.
4. Luego una vez, en cmd dentro de la carpeta:

```bat
cd backend
npm run migrate
cd ..
```

### D) Arrancar

Doble clic en **`BD Voluntariado.exe`** (o `Iniciar BD Voluntariado.bat`).

---

## En Bambi — todos los días

1. Abrir **Docker Desktop** (icono de ballena).
2. Doble clic en **`BD Voluntariado.exe`**.

Listo. No entras al proyecto, no corres Flutter, no tocas el dump.

---

## Qué es cada cosa

| Archivo / carpeta | Para qué |
|-------------------|----------|
| `BD Voluntariado.exe` | Lanzador: enciende API + abre la app |
| `app\` | El `.exe` Release de Flutter |
| `backend\` | API + Docker de Postgres |
| `backups\*.dump` | Copia de tus datos |
| `restaurar-en-bambi.bat` | Solo primera vez / recuperar datos |

---

## Orden mental

```
TU PC                          BAMBI (1ª vez)              BAMBI (diario)
─────────                      ────────────────           ───────────────
exportar dump  ─┐
empaquetar.bat ─┼─► USB ──►  instalar Docker+Node
                │            pegar carpeta
                │            restaurar dump (1 vez)
                └─────────►  doble clic BD Voluntariado.exe  ◄── solo esto
```

---

## Si en Bambi dice error de npm / Node

Aunque “esté en variables de entorno”, al abrir con doble clic a veces **no se ve**.

1. Instala **Node.js LTS** desde https://nodejs.org  
   - Marca **Add to PATH**  
2. **Reinicia el PC** (importante).  
3. Abre Docker Desktop.  
4. Doble clic en **`verificar-bambi.bat`** → debe decir OK en Node.  
5. Luego **`BD Voluntariado.exe`** / `iniciar-app.bat`.

El API ya no depende de `npm` en el PATH: arranca con `node.exe …\server.js`.  
Solo se usa `npm install` la primera vez si falta `backend\node_modules`.
