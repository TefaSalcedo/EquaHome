# EquaHome

App móvil para repartir el trabajo doméstico de forma justa entre las personas que comparten una casa — por tiempo y esfuerzo reales, no por número de tareas. La app propone y reorganiza; las personas siempre deciden.

## Estructura

Monorepo:

- `mobile/` — app Flutter (iOS/Android), Riverpod + dio, design system pastel propio.
- `backend/` — API FastAPI + PostgreSQL (SQLAlchemy 2 + Alembic). La lógica de negocio vive aquí.
- `docker-compose.yml` — PostgreSQL 16 para desarrollo local.

## Backend

```bash
docker compose up -d postgres          # o un Postgres local equivalente
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
cp .env.example .env                   # ajustar si es necesario
.venv/bin/alembic upgrade head
.venv/bin/uvicorn app.main:app --reload
```

API en `http://localhost:8000` (`/health`, docs en `/docs`).

```bash
.venv/bin/pytest          # tests (crean la base equahome_test)
.venv/bin/ruff check app tests
```

Si el puerto 5432 ya está ocupado por un Postgres local, basta crear el rol y la base:

```bash
sudo -u postgres psql -c "CREATE USER equahome PASSWORD 'equahome' CREATEDB;" \
                     -c "CREATE DATABASE equahome OWNER equahome;"
```

## Mobile

```bash
cd mobile
flutter pub get
flutter run   # --dart-define=API_BASE_URL=http://10.0.2.2:8000 en emulador Android
flutter analyze && flutter test
```

## Diseño

Las decisiones de arquitectura, modelo de datos, endpoints, paleta pastel y el plan por fases están en el documento de diseño del MVP (fase 00–01 implementada: auth JWT + hogares de 1 a N miembros + invitaciones + residencia principal).
