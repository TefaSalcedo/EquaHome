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
- New/changed Flutter plugins require a FULL `flutter run` restart (quit with `q`, relaunch) — not just `R` hot restart. The web plugin registrant is baked into the compiled entrypoint; hot restart serves the stale registrant and plugin calls throw `MissingPluginException` (seen: `pickImage` on `plugins.flutter.io/image_picker`) even though `.dart_tool/dartpad/web_plugin_registrant.dart` already lists the plugin.
- Testing file pickers (`image_picker`, file inputs) on Flutter web: the native GTK chooser may never appear under Chrome-for-Testing, and synthetic clicks on flt-semantics nodes don't reach the gesture system. Working recipe — CDP file-chooser injection: Chrome runs with `--remote-debugging-port=29229`; backend venv has `websockets`. Connect to the page target, `Page.setInterceptFileChooserDialog{enabled:true}`, trigger the button with a normal mouse click, then on `Page.fileChooserOpened` send `DOM.setFileInputFiles{files:['/tmp/room_test.png'], backendNodeId}` — the app continues as if the user picked the file. Script used: `/tmp/cdp_filechooser.py` (copy/adapt).

## Devin Secrets Needed
- none (all local, no external credentials).

## Fases 05–06 (plan diario, calendario, fotos)
- Al abrir Inicio (o GET /tasks?date=hoy) el backend materializa el día: plantillas activas → tareas propuestas (diarias siempre; semanales en su día preferido ISO 1=lunes..7=domingo, lunes por defecto; mensuales en el día del mes de creación; una-vez solo la primera vez).
- Carry-over: pendientes/seleccionadas/saltadas de días pasados reaparecen hoy como `carried_over` ("Viene de ayer"), sin duplicar y aún elegibles.
- Barra inferior ahora tiene 4 pestañas: Inicio, Casa, Tareas, Calendario (key `navCalendar`). Calendario muestra la semana (flechas `prevWeek`/`nextWeek`), minutos por día y el plan del día seleccionado (solo lectura; seleccionar/completar se hace desde Inicio).
- Fotos: en el detalle de una habitación, `scanRoomPhoto` abre el selector de archivos; tras subir se llama analyze automáticamente (mock AI: detecciones de ejemplo) y se abre una hoja para corregir objetos; `confirmAnalysis` los guarda como objetos de la habitación (source=ai). Uploads van a `backend/uploads/` (EQUAHOME_STORAGE_DIR); el proveedor IA es mock por defecto (EQUAHOME_AI_PROVIDER).

## Fases 07–08 (asistente + evaluación diaria)
- Asistente: tarjeta "Cuéntale a la app" en Inicio (`assistantInput` + `assistantSend`="Proponer") → POST interpret → diálogo "La app propone" (summary + acciones o "(Sin cambios concretos por ahora)") → `applyProposal` ejecuta solo tipos permitidos: `release_my_tasks` / `postpone_my_tasks` / `create_task`, siempre a nombre de quien confirma. Mock rules: "no estoy|no puedo|no voy a estar" → release; "pasar|posponer|para mañana" → postpone (mueve SOLO mis tareas a mañana); "agrega|añade|crea" → create_task con título = texto completo de la instrucción y ~20 min.
- `apply()` invalida todayTasksProvider + loadProvider pero NO weekProvider — el Calendario puede mostrar datos viejos hasta cambiar de semana.
- Foto del cierre del día: `dailyPhotoButton` (icono cámara junto a "Puntual") → pick + upload purpose=`daily_check` → analyze → diálogo "Así se ve la casa" con el resumen del mock.
- El chooser de archivos puede abrirse como diálogo GTK real (Open File con Cancel/Open) si no hay intercepción CDP activa — cerrar con el botón Cancel (Escape no siempre lo cierra).
