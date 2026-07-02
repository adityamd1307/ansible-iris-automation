# Mechanism Mapping - How Ansible applies each IRIS change (Topic 1, §3.2)

There is no single Ansible module that covers all IRIS administration.
For each configuration item this table records the chosen mechanism, why,
how idempotency is achieved, and where it lives in this repo.

| Configuration item | Mechanism (this repo) | Why | Idempotency approach | Where |
| ------------------ | --------------------- | --- | -------------------- | ----- |
| Database creation | **CPF merge** | Declarative, repeatable, reviewable | `[Databases]` merge creates if missing, updates if present; dir created first; `changed_when` on merge output | `cpf/database-template.cpf.j2`, `playbooks/setup_databases.yml` |
| Namespace + mapping | **CPF merge** | Supported for ns/db actions; declarative | `[Namespaces]` + `[Map.<ns>]` merge; re-running converges | `cpf/namespace-template.cpf.j2`, `playbooks/create_namespace.yml` |
| Service enablement | **CPF merge** | Simple, declarative | `[<service>] Enabled=` merge | `cpf/services-template.cpf.j2`, `playbooks/setup_security.yml` |
| Web application | **ObjectScript (guarded)** | Not reliably expressible in CPF | `Security.Applications.Exists()` -> Create else Modify; prints CREATED/UPDATED | `objectscript/setup_webapp.cos.j2`, `playbooks/setup_webapp.yml` |
| Role / resource | **ObjectScript (guarded)** | Security model needs the API | `Security.Roles.Exists()` before Create | `objectscript/setup_security.cos.j2`, `playbooks/setup_security.yml` |
| Admin/app password | **ObjectScript (guarded, `no_log`)** | Operational, secret-bearing | Opt-in (`rotate_admin_password`); value from vault; script deleted after run | `objectscript/setup_security.cos.j2`, `playbooks/setup_security.yml` |
| Interop production auto-start | **ObjectScript (guarded)** | Operational setting via `Ens.Director` | `GetAutoStartProduction()` checked first, `SetAutoStart()` only if different; try/catch skips non-interop ns | `objectscript/setup_production.cos.j2`, `playbooks/setup_production.yml` |
| Namespace/DB/web app validation | **ObjectScript (read-only) -> JSON** | Validation, not creation | Read-only; never `changed`; asserts + JSON | `objectscript/validate_readiness.cos.j2`, `playbooks/validate_nodes.yml` |
| Production status | **ObjectScript (read-only)** | Runtime validation | Read-only; distinguishes primary (running) vs backup (ready) | `objectscript/validate_readiness.cos.j2` |
| Mirror readiness | **ObjectScript (read-only) + network check** | Validation, not creation | Read-only member/journal check + arbiter `wait_for` | `objectscript/validate_mirror.cos.j2`, `playbooks/validate_mirror.yml` |
| Routing (HAProxy->Gateway->IRIS) | **REST (`uri`)** | Read-only runtime check | Idempotent GET, asserts content | `playbooks/test_routing.yml` |

## Mechanism rules applied

1. **CPF merge is the default** for database creation, namespace creation
   and mapping, and basic service enablement - declarative and repeatable.
2. **ObjectScript only where merge cannot express the action** (web apps,
   roles, password, interop auto-start). It is run from a **script file**
   fed to `iris session` with a clean `halt` (not fragile inline
   commands), and **every mutating action is guarded by an existence /
   current-value check**.
3. **Read-only validation** (namespace/db/web app/production/mirror) via
   ObjectScript or REST changes nothing and emits both human-readable and
   machine-readable JSON.

## Merge reconfiguration note (§3.1)

`iris merge` applies the CPF to a running instance, so the playbooks apply
configuration on re-run rather than relying on a startup-only merge. If a
particular setting only takes effect at startup for your image/version,
add a controlled restart step after the merge and re-validate. Validation
playbooks are safe to run at any time to confirm the converged state.
