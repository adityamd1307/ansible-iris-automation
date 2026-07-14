# Mechanism Mapping - How Ansible applies each IRIS change (Topic 1, §3.2)

There is no single Ansible module that covers all IRIS administration.
For each configuration item this table records the chosen mechanism, why,
how idempotency is achieved, and where it lives in this repo.

| Configuration item | Mechanism (this repo) | Why | Idempotency approach | Where |
| ------------------ | --------------------- | --- | -------------------- | ----- |
| Database definition (name -> dir) | **CPF merge** | Declarative, repeatable, reviewable | `[Databases]` merge registers the config entry; dir created first | `cpf/database-template.cpf.j2`, `playbooks/setup_databases.yml` |
| Physical database (IRIS.DAT) + DB resource | **ObjectScript (guarded)** | A runtime CPF merge registers the definition but does **not** instantiate the physical `IRIS.DAT`, so the namespace would map to a non-mountable DB (`<DIRECTORY>`). Also creates/binds a dedicated `%DB_<name>` resource (not auto-created) | `SYS.Database.%ExistsId()` -> `CreateDatabase()`; `Security.Resources.Exists()` -> `Create()`; bind only if `ResourceName` differs | `objectscript/create_databases.cos.j2`, `playbooks/setup_databases.yml` |
| Namespace + mapping | **CPF merge** | Supported for ns/db actions; declarative | `[Namespaces]` + `[Map.<ns>]` merge; re-running converges | `cpf/namespace-template.cpf.j2`, `playbooks/create_namespace.yml` |
| Service enablement | **ObjectScript (guarded)** | A configuration merge has **no services section** in current IRIS (a `[%Service_*]` / `[Services]` section is rejected with `ERROR #415`); `Security.Services` is the supported API | `Security.Services.Exists()` (skip if absent) -> compare `Enabled` -> `Modify()` only if different | `objectscript/setup_security.cos.j2`, `playbooks/setup_security.yml` |
| Web application | **ObjectScript (guarded)** | Not reliably expressible in CPF | `Security.Applications.Exists()` -> Create else Modify; prints CREATED/UPDATED | `objectscript/setup_webapp.cos.j2`, `playbooks/setup_webapp.yml` |
| Role / resource | **ObjectScript (guarded)** | Security model needs the API | `Security.Roles.Exists()` before Create; the referenced `%DB_<name>` resources are created+bound during DB setup | `objectscript/setup_security.cos.j2`, `playbooks/setup_security.yml` |
| Admin/app password | **ObjectScript (guarded, `no_log`)** | Operational, secret-bearing | Opt-in (`rotate_admin_password`); value from vault; script deleted after run | `objectscript/setup_security.cos.j2`, `playbooks/setup_security.yml` |
| Interop production auto-start | **ObjectScript (guarded)** | Operational setting via `Ens.Director` | `GetAutoStartProduction()` checked first, `SetAutoStart()` only if different; try/catch skips non-interop ns | `objectscript/setup_production.cos.j2`, `playbooks/setup_production.yml` |
| Namespace/DB/web app validation | **ObjectScript (read-only) -> JSON** | Validation, not creation | Read-only; never `changed`; asserts + JSON | `objectscript/validate_readiness.cos.j2`, `playbooks/validate_nodes.yml` |
| Production status | **ObjectScript (read-only)** | Runtime validation | Read-only; distinguishes primary (running) vs backup (ready) | `objectscript/validate_readiness.cos.j2` |
| Mirror readiness | **ObjectScript (read-only) + network check** | Validation, not creation | Read-only member/journal check + arbiter `wait_for` | `objectscript/validate_mirror.cos.j2`, `playbooks/validate_mirror.yml` |
| Security sync (roles/users) | **ObjectScript (Security.* Export/Import) + file transfer** | IRISSECURITY is not mirrored; official API preserves hashes/metadata | Export/import guarded by Validator; re-import is safe; Ansible `changed_when` from log markers + JSON | `objectscript/security_sync/`, `objectscript/invoke_security_sync.cos.j2`, `playbooks/sync_security.yml` |
| Routing (HAProxy->Gateway->IRIS) | **REST (`uri`)** | Read-only runtime check | Idempotent GET, asserts content | `playbooks/test_routing.yml` |

## Mechanism rules applied

1. **CPF merge is the default** for the database *definition*, namespace
   creation and mapping - declarative, reviewable and repeatable.
2. **ObjectScript where merge cannot express the action.** This is
   required for more than expected: the physical `IRIS.DAT` (merge only
   registers the definition), service enablement (no CPF services section
   - `ERROR #415`), web apps, roles/resources, password, and interop
   auto-start. It is run from a **script file** fed to `iris session` with
   a clean `halt` (not fragile inline commands), and **every mutating
   action is guarded by an existence / current-value check**.
3. **Read-only validation** (namespace/db/web app/production/mirror) via
   ObjectScript or REST changes nothing and emits both human-readable and
   machine-readable JSON.

## ObjectScript execution constraint (important)

`iris session <instance>` reads stdin as an interactive **terminal REPL**,
executing **one line at a time**. It therefore cannot continue a `{ }`
block across input lines - a bare `try {` on its own line raises
`<SYNTAX>`. All `.cos.j2` templates in this repo keep each executable
statement (including whole guarded `try {...} catch e {...}` blocks) on a
**single line**. `$$$` macros are unavailable in this mode, so the scripts
use the runtime API (e.g. `$system.Status.GetErrorText()`), not macros.

Validation scripts emit their result as one line, `READINESS_JSON:{...}` /
`MIRROR_JSON:{...}` / `SECURITY_SYNC_JSON:{...}`, which the playbooks
select and parse with `from_json`.
This avoids fragile multi-line regex against prompt-interleaved output.

## Service naming note

The modern web/CSP service is **`%Service_WebGateway`**; the legacy
`%Service_CSP` no longer exists. `security_services` entries whose service
is not present on the instance are skipped (logged `SKIP SERVICE ...`)
rather than failing the run.

## Merge reconfiguration note (§3.1)

`iris merge` applies the CPF to a running instance, so the playbooks apply
configuration on re-run rather than relying on a startup-only merge. If a
particular setting only takes effect at startup for your image/version,
add a controlled restart step after the merge and re-validate. Validation
playbooks are safe to run at any time to confirm the converged state.
