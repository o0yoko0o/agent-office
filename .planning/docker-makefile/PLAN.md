# Plan: Makefile + Docker für agent-office

Stand: 2026-10-28. Status: Phasen 1 bis 5 umgesetzt, nicht committet. Details unter „Umsetzungsstand“ am Ende.

## Ziel

- Das Office läuft per `make up` in Docker auf dem Mac (Docker Desktop).
- Erreichbar unter derselben IP wie bisher (`127.0.0.1`), aber auf einem anderen Port (Vorschlag `4848`), damit ein lokal gestartetes Office auf `4747` parallel laufen kann.
- Laufende Sessions der lokalen Agents (Claude Code, Codex, opencode, Cursor, Gemini, Qwen, Droid, Command Code) werden weiter erkannt.
- Makefile nach dem bekannten Muster aus den anderen Projekten: einheitliche Schnittstelle über `docker compose`, nichts lokal installieren, `help` als Standard-Target, `.env` aus versionierter `.env.dist`.

Bewusst nicht im Scope: Traefik/nip.io (Anforderung ist gleiche IP, anderer Port), Control-Plane im Container, Remotes/Sandboxes im Container.

Harte Grenze: Alle Änderungen bleiben in diesem Repo. Die Setups der Agents (`~/.claude`, `~/.codex`, `~/.config/opencode` und die übrigen) werden nicht angefasst. Kein Make-Target ruft `theagentoffice install` oder `uninstall` auf.

## Ergebnisse der Recherche

Stand im Repo: kein Dockerfile, keine compose-Datei, kein Makefile, kein `.dockerignore`.

### Was ohne Codeänderung funktioniert

- **Discovery** liest nur Dateien unter `$HOME` (`src/ingest/discover.ts:61-111`, `src/ingest/source.ts:110`). Read-only Bind-Mounts der Agent-Verzeichnisse reichen.
- **Netzwerk:** Mit `--host 0.0.0.0` im Container und `ports: "127.0.0.1:4848:4747"` gehen Host- und Origin-Check durch, weil beide nur den Hostnamen ohne Port prüfen (`src/server/http.ts:150`, `:308-363`).
- **Build:** `npm ci` → `npm run build`. Zur Laufzeit braucht es nur `dist/` und `package.json`. Node 24 nehmen, opencode braucht `node:sqlite`.

### Was beachtet werden muss

1. **Presence-Scan (Blocker):** `scanProcesses()` ruft `ps` auf (`src/ingest/presence.ts:120-130`). Ist `ps` im Image vorhanden, sieht der Container keine Agent-Prozesse und beendet über `reconcileLocal([])` jede Session nach 15 s Stille (`src/server/state.ts:290-320`). Fehlt `ps`, bleibt nur die Timer-Logik (idle nach 90 s, Ende nach 20 min). Ein Flag zum Abschalten gibt es nicht.
2. **HOME muss gleich sein:** Aus `cwd` wird nur dann `~`, wenn der Pfad mit dem Container-HOME beginnt (`src/server/state.ts:534`, `:571-575`). Mit `HOME=/root` würden volle Pfade über SSE rausgehen, was die Privacy-Regeln verletzt. Deshalb im Container `HOME=$HOME` des Hosts setzen und an gleichen Pfaden mounten.
3. **Outbox (MCP-Signale):** `office_status`, `office_shout`, `office_celebrate` und `office_flip` hängen nur eine Zeile an `~/.agentoffice/outbox/<pid>.jsonl` an (`src/mcp/tools.ts`). Sie brauchen weder Port noch laufendes Office. Der Container liest die Outbox über einen read-only Mount, damit kommen diese vier Signale ohne Änderung an den Agent-Setups an.
4. **office.json und `office_peers`:** Nur `office_peers` fragt das Office per HTTP ab. Der MCP-Server findet es über `~/.agentoffice/office.json` und prüft `alive(pid)` (`src/mcp/office.ts:148-158`). Den MCP-Server starten die Agents aus dem veröffentlichten npm-Paket, ein Patch in diesem Fork käme dort nicht an. Das Container-Office schreibt sein office.json deshalb nur in sein eigenes `AGENT_OFFICE_HOME`, damit es das `~/.agentoffice/office.json` eines parallelen Host-Office nicht überschreibt.
5. **opencode-SQLite im WAL-Modus** über einen `:ro`-Mount auf virtiofs kann CANTOPEN oder veraltete Daten liefern (`src/ingest/source.ts:138`). Muss getestet werden.
6. **Polling:** Unter Linux ist `fs.watch` aus, es wird alle 1,5 s gepollt (`src/ingest/index.ts:48`, `:1186`). Über virtiofs kostet das etwas CPU.
7. **Control-Plane** ist bei nicht-Loopback-Host ohnehin aus (`src/cli.ts:459`). Im Container fehlen die Agent-CLIs, also explizit `--no-control` und `--local-only`.

## Umsetzung in Phasen

### Phase 1: Docker-Grundgerüst

- `Dockerfile`, Multi-Stage:
  - Build: `node:24-bookworm-slim`, `npm ci`, `npm run build`.
  - Runtime: `node:24-bookworm-slim`, nur `dist/` und `package.json`. Kein `npm ci` nötig, weil es keine Runtime-Dependencies gibt (node-pty braucht es ohne Control-Plane nicht).
  - Start: `node dist/cli.js --host 0.0.0.0 --port 4747 --no-open --no-control --local-only`.
- `.dockerignore` (`node_modules`, `dist`, `site/dist`, `video`, `.planning`, `.git`).
- `compose.yaml`:
  - `ports: "${BIND_IP:-127.0.0.1}:${HOST_PORT:-4848}:4747"`
  - `environment: HOME=${HOME}`, `AGENT_OFFICE_HOME` auf eigenes Container-Verzeichnis
  - Healthcheck auf `/api/snapshot` oder `/healthz`
- Mounts werden generiert: `scripts/docker/mounts.sh` schreibt `compose.mounts.yaml` nur für Agent-Verzeichnisse, die auf dem Host existieren. So legt Docker keine leeren Ordner als root an. Alle Mounts `:ro` an gleichem Pfad, Outbox separat `:ro`.
- `.env.dist` (versioniert) → `.env` (gitignored): `HOST_PORT`, `BIND_IP`, optional `AGENT_OFFICE_<AGENT>_DIR`.

### Phase 2: Makefile

Targets nach bekanntem Muster:

| Target | Zweck |
|---|---|
| `help` (Default) | Liste aller Targets |
| `env-check` / `docker-check` | `.env` anlegen, Docker läuft, Port frei |
| `build` / `rebuild` | Image bauen (mit `--no-cache`) |
| `up` | Mounts generieren, starten, URL ausgeben |
| `down` / `restart` | stoppen / neu starten |
| `logs` / `status` | Logs folgen, `docker compose ps` + Healthcheck |
| `shell` | Shell im Container |
| `open` | `http://127.0.0.1:$(HOST_PORT)` im Browser |
| `typecheck` / `test` | im Build-Container ausführen (nichts lokal installieren) |
| `native` | wie bisher ohne Docker (`npm run dev`) |

### Phase 3: Kleine Code-Anpassungen (fork-lokal)

Damit die Session-Erkennung nicht davon abhängt, dass im Image zufällig kein `ps` existiert:

1. `--no-presence` (plus Env `AGENT_OFFICE_PRESENCE=0`): Prozess-Scan und `reconcileLocal` aus. Header-Kommentar in `src/control/presence.ts` anpassen.
2. Optional: Env-Variablen für `--host`/`--port`, damit compose ohne Command-Override auskommt.
3. Tests nach Konvention (z. B. `test/control.presence.test.mjs`).

Keine Änderung am MCP-Code (`src/mcp/`): Sie würde die Agents nicht erreichen, ohne deren Config auf den Fork umzustellen.

### Phase 4: Verifikation

- `make up`, dann mit echten Agents prüfen: neue Claude-Code- und Codex-Session erscheint, wird idle, verschwindet.
- opencode separat prüfen (SQLite über virtiofs). Fallback falls nötig: DB vor dem Lesen in den Container kopieren.
- Prüfen, dass kein voller Pfad (`/Users/...`) in `/api/snapshot` auftaucht.
- MCP-Signale `office_status` und `office_shout` aus einem Host-Agent kommen im Container-Office an (Outbox-Mount).
- `~/.agentoffice/office.json` auf dem Host bleibt nach `make up` und `make down` unverändert.
- Parallel: Host-Office auf 4747 und Container-Office auf 4848 stören sich nicht.

### Phase 5: Doku

- `AGENTS.md` (Commands-Abschnitt), README-Fork-Hinweis, `.planning/codebase/STACK.md` und `INTEGRATIONS.md` ergänzen.
- Bekannte Einschränkungen des Docker-Betriebs dokumentieren (siehe unten).

## Bekannte Einschränkungen im Docker-Betrieb

- `office_peers` meldet „Office nicht erreichbar“, solange nur das Container-Office läuft. Die Agents sehen dann nicht, woran andere Agents arbeiten. Die übrigen vier MCP-Tools funktionieren.
- Ohne Presence-Scan erscheinen Agents erst mit dem ersten Transkript-Eintrag statt beim Prozessstart, und beendete Agents bleiben bis zu 20 min sichtbar.
- Keine Control-Plane: kein Anheuern von Agents, kein PTY, keine Approvals aus dem Office heraus.
- Keine Remotes (ssh, Daytona, Vercel, Railway, boat) im Container.

## Entscheidungen (2026-10-28)

1. Host-Port: `4848` auf `127.0.0.1`.
2. Fork-lokale Code-Anpassungen aus Phase 3 sind freigegeben.
3. Branch: `feat/docker-makefile`, abgezweigt von `docs/claude-md`.

## Umsetzungsstand (2026-10-28)

Umgesetzt:

- Phase 1: `Dockerfile`, `.dockerignore`, `compose.yaml` (Services `office` und `dev`), `.env.dist`, `scripts/docker/mounts.sh`. `.env` und `compose.mounts.yaml` stehen in `.gitignore`.
- Phase 2: `Makefile` mit allen Targets aus der Tabelle, zusätzlich `mounts`.
- Phase 3: `--no-presence` und `AGENT_OFFICE_PRESENCE=0` (`src/cli.ts`, `presenceOffByEnv` in `src/control/presence.ts`), Tests in `test/control.presence.test.mjs` und `test/cli.test.mjs`.
- Phase 5: `AGENTS.md`, README (Abschnitt „Docker (this fork)“ mit den Einschränkungen, CLI-Tabelle), `.planning/codebase/STACK.md` und `INTEGRATIONS.md`.

Abweichungen:

- Die Outbox braucht keinen Code: Das Container-Office nutzt `AGENT_OFFICE_HOME=/var/lib/agentoffice`, die Host-Outbox ist read-only nach `/var/lib/agentoffice/outbox` gemountet.
- Keine Env-Variablen für `--host`/`--port` (optional im Plan). Die Flags stehen im `CMD` des Dockerfile.
- Der `dev`-Container läuft als User `node`. Als root schlägt ein Test fehl, der sich auf eine unlesbare Datei verlässt.

Verifikation (Phase 4):

- `make typecheck` grün, `make test` grün (501 Tests, 2 nur unter Windows übersprungen).
- `make up`: Container healthy, `/api/snapshot` liefert Claude-Sessions ohne `/Users/`-Pfade.
- `~/.agentoffice` auf dem Host vor, während und nach `make up`/`make down` unverändert (kein `office.json`, `control.json` gleicher Hash).
- opencode-DB lässt sich im Container read-only öffnen, der Ingest meldet keinen Fehler. Eine laufende opencode-Session war nicht da, Aktualität über virtiofs ist also nicht live geprüft.
- Outbox-Mount mit einem Temp-Verzeichnis geprüft (lesbar, read-only). Die echte `~/.agentoffice/outbox` existiert auf diesem Rechner noch nicht.

Offen:

- Mit echten Agents prüfen: neue Session erscheint, wird idle, verschwindet; MCP-Signale aus einem Host-Agent kommen an; Host-Office auf 4747 parallel.
