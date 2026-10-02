# Instalación en la máquina de Hogar Bambi

Guía para instalar el sistema **desde cero** en esa PC y llevar los datos completos desde tu máquina de desarrollo.

## Idea general

- El programa viejo (solo Flutter) **no trae** este backend ni este Postgres. No dependas de sus `.env` antiguos.
- En Bambi se instala el stack nuevo: **Docker (Postgres) + Node (API) + app Flutter**.
- Los datos completos van en un **dump** generado en tu PC. `npm run migrate` solo crea tablas; **no copia datos**.
- Los `.env` de Bambi **no tienen que ser iguales** a los tuyos: solo deben apuntar al Postgres y al API **de esa máquina**. Con Docker nuevo, usar el `.env.example` basta.

---

## Parte A — En tu PC (antes de ir)

### 1. Exportar la base completa

1. Abre **Docker Desktop**.
2. Doble clic en `exportar-base-local.bat` (raíz del proyecto).
3. Se crea un archivo en:

   `backups\voluntariado_YYYYMMDD_HHMM.dump`

### 2. Compilar la app (recomendado)

```bat
flutter build windows --release
```

El ejecutable queda en:

`build\windows\x64\runner\Release\voluntariado_desktop_app.exe`

### 3. Qué llevar a Bambi

- Carpeta del proyecto (o al menos `backend`, los `.bat`, `docs`, y la carpeta `Release` si ya compilaste).
- El archivo `.dump` de `backups\`.
- Instaladores si hace falta: Docker Desktop, Node.js LTS (y Flutter solo si vas a compilar allá).

---

## Parte B — En Bambi (instalación desde cero)

### 1. Instalar herramientas

| Herramienta | ¿Para qué? |
|-------------|------------|
| **Docker Desktop** | Postgres de la app |
| **Node.js** (LTS) | API backend |
| **Flutter** | Solo si compilas en esa PC; si llevas el `.exe` Release, no es obligatorio |

Docker Desktop debe quedar **abierto** (o el servicio de Docker activo) cuando uses la app.

### 2. Copiar el proyecto

Por ejemplo:

`C:\Voluntariado\voluntariado_desktop_app\`

### 3. Backend `.env`

En `backend\`:

1. Copiar `backend\.env.example` → `backend\.env`
2. Dejarlo como el example (Postgres en Docker, puerto `5434`, API en `8001`), salvo que cambien contraseña a propósito **y** la actualicen también en `docker-compose.yml`.

No hace falta “averiguar” un `.env` viejo de ellos: este sistema es nuevo.

### 4. Flutter `.env` (raíz del proyecto)

Crear o reemplazar `.env` en la raíz:

```env
API_URL=http://127.0.0.1:8001
```

Los `.env` viejos de Flutter de la app anterior se pueden **ignorar**.

### 5. Dependencias y base vacía

En una terminal, desde `backend\`:

```bat
npm install
docker compose up -d
npm run migrate
```

### 6. Restaurar tus datos completos

Desde la raíz del proyecto:

```bat
restaurar-en-bambi.bat backups\voluntariado_XXXX.dump
```

El script:

1. Guarda un respaldo de lo que haya en esa base (`backups\bambi_antes_de_restaurar_....dump`).
2. Pide que escribas `SI` para continuar.
3. Restaura **tu** dump (reemplaza los datos de esa base por los tuyos).

Luego, otra vez en `backend\`:

```bat
npm run migrate
```

(por si el dump es de una versión un poco anterior y faltan índices/columnas nuevas).

### 7. Arrancar el sistema

Doble clic en **`BD Voluntariado.exe`** (o en `iniciar-app.bat`).

Eso levanta Postgres (Docker) + API Node y abre la app.

Si aún no tienes el `.exe` lanzador, en la PC de desarrollo corre `compilar-lanzador.bat` y cópialo junto a `iniciar-app.bat`.


---

## Uso diario en Bambi

1. Abrir **Docker Desktop**.
2. Doble clic en **`BD Voluntariado.exe`** (o `iniciar-app.bat`).

No hace falta correr migrate ni restaurar cada día.

---

## Sobre los `.env`

| Archivo | Qué es |
|---------|--------|
| `backend\.env` | Conexión a **su** Postgres y puerto del API |
| `.env` (raíz) | `API_URL` de la app Flutter → casi siempre `http://127.0.0.1:8001` |

- **No** tienen que coincidir con los de tu laptop.
- Con instalación Docker nueva: example + `API_URL` local es suficiente.
- El `.dump` **no incluye** los `.env`; solo datos.

---

## Si algo sale mal al restaurar

Queda el respaldo previo en:

`backups\bambi_antes_de_restaurar_YYYYMMDD_HHMM.dump`

Se puede volver a pasar por `restaurar-en-bambi.bat` apuntando a ese archivo.

---

## Checklist rápido

**Antes (tu PC)**

- [ ] Docker arriba
- [ ] `exportar-base-local.bat` → `.dump` listo
- [ ] `flutter build windows --release` (ideal)
- [ ] USB / OneDrive con proyecto + dump

**Allá (Bambi)**

- [ ] Docker + Node instalados
- [ ] Proyecto copiado
- [ ] `backend\.env` desde example
- [ ] `.env` Flutter con `API_URL=http://127.0.0.1:8001`
- [ ] `npm install` + `docker compose up -d` + `npm run migrate`
- [ ] `restaurar-en-bambi.bat` + `npm run migrate`
- [ ] `iniciar-app.bat` / **`BD Voluntariado.exe`** y verificar datos

---

## Recordatorios

- Avisa al equipo: el día de la restauración no carguen datos nuevos en Bambi; se pierden al pegar tu dump.
- Si en el futuro hay que volver a cargar solo desde Excel, se puede usar **Importar Excel** en cada módulo o los scripts CSV del backend; eso es independiente de este procedimiento de dump.
