---
name: testing-equahome
description: How to run and E2E-test the EquaHome monorepo (FastAPI backend + Flutter mobile) locally, including the Flutter-web path for UI testing.
---

# Testing EquaHome locally

## Backend
- Start: `cd backend && .venv/bin/uvicorn app.main:app --port 8000` (venv already exists).
- Postgres: local instance, DB `equahome`, user `equahome`, password `equahome`. `sudo -n -u postgres psql` works for admin ops.
- Health check: `curl http://localhost:8000/health` → `{"status":"ok"}`. Docs at `/docs`.
- CORS is `allow_origins=["*"]`, so Flutter web on another port just works.
- Useful DB check: `PGPASSWORD=equahome psql -h localhost -U equahome -d equahome -c "select code,status from household_invitations;"` — verify invite codes read from screenshots (they are case-sensitive, 8 chars, single-use, 7-day expiry).

## Frontend (Flutter)
- Flutter SDK: `/home/ubuntu/flutter-sdk/bin` — add to PATH.
- `mobile/web/` may be committed (scaffolded during PR-#1 testing). If missing on a branch, scaffold with `cd mobile && flutter create . --platforms web` (also touches `.metadata`/`analysis_options.yaml` — keep untracked or revert).
- Serve: `flutter run -d web-server --web-port 5000`, open Chrome at `http://localhost:5000`. `flutter run` caches a build — after switching branches, kill and restart the process (hot-restart alone may serve stale code).
- `flutter_secure_storage` WORKS on web (lockfile includes `flutter_secure_storage_web`); token persistence and reload-session-restore are testable.
- `API_BASE_URL` defaults to `http://localhost:8000` — correct for web; Android emulator needs `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
- Auth form quirk: login/register share controllers — switching modes retains field text. Always ctrl+a before retyping fields.
- Test users seeded by E2E runs: ana@test.com / password123 (owner of "Casa Principal"), bruno@test.com / password123 (member).

## Devin Secrets Needed
- none (all local, no external credentials).
