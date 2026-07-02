# ObjectScript automation scripts

CPF merge is the preferred mechanism for **databases, namespaces and
mappings** (see `cpf/`). ObjectScript is used **only where CPF cannot
express the desired state**:

| Script | Purpose | Idempotency guard |
| ------ | ------- | ----------------- |
| `setup_webapp.cos.j2` | Create/update CSP web applications | `Security.Applications.Exists()` before create; otherwise modify |
| `setup_security.cos.j2` | Create application roles, enable services, rotate the admin password | `Security.Roles.Exists()`; password only rotated when explicitly requested |
| `setup_production.cos.j2` | Configure interop production auto-start | `Ens.Director.GetAutoStartProduction()` checked first; `SetAutoStart()` only if different; try/catch skips non-interop namespaces |
| `validate_readiness.cos.j2` | Read-only node readiness check (incl. production status), emits JSON | none (read-only) |
| `validate_mirror.cos.j2` | Read-only mirror-readiness check, emits JSON | none (read-only) |

## Conventions

- Every script is a Jinja2 template (`.cos.j2`). Ansible renders it with
  the environment desired state and feeds it to
  `iris session <instance>` inside the target node.
- Every mutating operation is **guarded** so re-running is safe. Scripts
  print `CREATED` / `EXISTS` / `UPDATED` markers so the calling playbook
  can decide whether anything actually changed (`changed_when`).
- Validation scripts are strictly read-only and emit a machine-readable
  JSON block between `--- VALIDATION JSON ---` and `--- END VALIDATION ---`
  markers that the playbooks parse and assert on.
- No script ever hardcodes a namespace, path, role or password. All of
  those come from variables. Secrets are passed via ansible-vault and the
  calling task uses `no_log: true`.
