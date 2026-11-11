# SommoMemory game service

Requires Node.js >=22.13 or Node24 (`node:sqlite`). Install locked dependencies with `npm ci --omit=dev`;
run `npm start`. Run `npm test` for game rules, privacy boundaries, persistence and
real WebSocket integration checks.

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `HOST` | `127.0.0.1` | Use `0.0.0.0` inside an isolated container. |
| `PORT` | `8787` | HTTP and WebSocket listener. |
| `DATA_DIR` | `server/data` | Private rooms, transactional economy database and capability key; mount a persistent volume. |
| `WEB_DIR` | `app/build/web` | Absolute path to the compiled Flutter web app. |
| `ALLOWED_ORIGINS` | production domain and localhost:8080 | Comma-separated browser origins. Native clients omit Origin. |
| `ADMIN_ORIGIN` | `https://sommomemory.sommomi.cc` | Exact HTTPS origin for passkey-protected `/admin`; HTTP loopback only for development. |
| `TRUST_PROXY` | off | Set `1` only when the listener is reachable exclusively by the trusted reverse proxy. |

Terminate HTTPS at the reverse proxy and forward WebSocket upgrades on `/ws`.
Use an idle timeout greater than 20 seconds (heartbeat interval); 120 seconds is
sufficient. Health checks use `/healthz`; public informational pages use `/privacy`
and `/support`. `/delete-account` supports deletion without reinstalling the app.
Do not expose `DATA_DIR` through a static web server.

The service runs as one instance. A malformed or incompatible room snapshot stops
startup instead of silently deleting data. Preserve the snapshot before attempting
manual repair. `SIGTERM` / `SIGINT` close connections and mark persisted players
disconnected; reconnect grace is 90 seconds. Normal restarts must finish within
that interval to preserve active games. Idle rooms expire after 24 hours.

Optional profiles use opaque device tokens and a user-exported recovery code for
cross-device sync. Optional Apple/Google authentication is available only when
configured; guest play remains available. There are no app passwords, text chat, ads,
real money or purchases. The passkey-protected [admin dashboard](../docs/ADMIN.md) retains operational
profile activity and sanitized online match history for 90 days. Deletion removes
activity and anonymizes historical participants. No third-party gameplay analytics
are used; the native Google authentication SDK declares separate account/device/usage
data and analytics purposes, documented in [the privacy policy](public/privacy.html).
Wallet changes use SQLite
transactions and unique ledger sources; tokens/recovery/capabilities are hashed.
Restore never merges balances. See [the economy contract](../docs/ECONOMY_PROTOCOL.md)
for routes, offline reward limits, quotas and deletion semantics.

Account setup, runtime environment variables, native build flags and deletion
retention are documented in [ACCOUNTS_SETUP.md](../docs/ACCOUNTS_SETUP.md).
Provider credentials and confirmation results are encrypted using a
domain-separated key derived from the external economy capability key. Never
use the App Store Connect publishing key for player authentication.

Back up `economy.sqlite` using SQLite backup or while the process is stopped,
together with `economy-capability.key`; copying only the live database omits its
WAL. Do not print these files or commit them. One server process owns the database.
Pair identities online remain authoritative and concealed until revealed. See
[PROTOCOL.md](PROTOCOL.md) for room sessions. Domain association JSON is served
publicly from `server/public/.well-known/`, including the root iOS AASA alias.

Admin enrollment is available at `/admin`. The first-start activation code is
written only to private `DATA_DIR/admin-enrollment.json`, expires in 24 hours and
is consumed by a verified passkey registration. Never serve or log this file.
See [ADMIN.md](../docs/ADMIN.md) for activation, backup keys, recovery and local setup.
