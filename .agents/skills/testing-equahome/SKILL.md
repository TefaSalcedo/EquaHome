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
- Number fields may pre-fill or hint a default (e.g. minutes) — ctrl+a before typing, or digits append (typing 10 onto a 15 default once produced 1510).
- After switching backend branches: restart uvicorn AND run `(cd backend && .venv/bin/alembic upgrade head)` — new endpoints/tables are migration-gated.
- Screenshot-vs-DOM coordinate mismatch: the browser viewport may be larger than the 1024x768 screenshot space (seen: 1600x1069, ~1.56x scale). Small tap targets (IconButtons, chips) can be missed by several px. Reliable fix: enable semantics once via `document.querySelector('flt-semantics-placeholder').click()` (browser_console), then read each target's `getBoundingClientRect()` and click `x/1.5625, (y+~80)/1.5625` in screenshot coords — or just click a few px right of the visual center for right-edge icons.
- Debugging silent client failures: snackbar "Algo salió mal" + no request in the uvicorn log means the exception happened before dio sent. Temporarily print the caught error (`print('ERR: $e\n$st')`) and re-read browser console — caught exceptions don't surface otherwise. Fase-04 instance (fixed): a notifier calling `ref.read`/`ref.invalidate` of a provider that transitively watches the notifier's own provider → Riverpod 3 CircularDependencyError — in any notifier method, watch for that shape.
- Test users seeded by E2E runs: ana@test.com / password123 (owner of "Casa Principal"), bruno@test.com / password123 (member).

## Devin Secrets Needed
- none (all local, no external credentials).
