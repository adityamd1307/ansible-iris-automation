# Ansible IRIS Automation - Runbook (Week 2 POC, Topic 1)

This runbook lets another engineer **set up, run, verify, troubleshoot,
and extend** the InterSystems IRIS automation POC without prior context.

---

## 1. What this POC does

Given a two-node IRIS topology (`irisa` primary, `irisb` backup, plus an
arbiter, two web gateways and HAProxy), the automation converges each
node to a declarative desired state:

1. **Databases** - definition via CPF merge (`cpf/database-template.cpf.j2`),
   then physical `IRIS.DAT` + `%DB_<name>` resource via guarded ObjectScript
   (`objectscript/create_databases.cos.j2`; a runtime merge registers the
   definition but does not instantiate the physical database)
2. **Namespace + mappings** created via CPF merge (`cpf/namespace-template.cpf.j2`)
3. **Web application** created via guarded ObjectScript (`objectscript/setup_webapp.cos.j2`)
4. **Security** - services + roles/password via guarded ObjectScript
   (`objectscript/setup_security.cos.j2`; CPF has no services section)
5. **Interop production auto-start** via guarded ObjectScript (`objectscript/setup_production.cos.j2`)
6. **Validation** of node readiness (incl. production status) and **mirror readiness** (read-only, JSON)

See `docs/mechanism-mapping.md` for the full per-item mechanism table
(CPF vs ObjectScript vs REST) and `architecture/` for the diagram.

Everything is **idempotent** (safe to re-run) and **parameterized** per
environment. No secrets are committed.

---

## 2. Prerequisites

- Docker with the `docker compose` plugin (for the POC topology)
- Ansible on the control node (WSL/Ubuntu recommended on Windows; native
  PowerShell can report a `1252` locale error - see §7)
- Network access to the InterSystems container images referenced in
  `group_vars/all.yml`
- An IRIS license key (`iris.key`) if your chosen image requires one.
  **Never commit it** - it is git-ignored.

---

## 3. Repository map

```
ansible.cfg                         Default inventory + settings
docker-compose.yml                  POC topology (2x IRIS, 2x gateway, arbiter, HAProxy)
group_vars/
  all.yml                           Shared infra defaults (images, ports, runtime dirs)
  vault.example.yml                 Template for the encrypted secrets file (no real secrets)
inventories/
  poc/  dev/  sit/  uat/            One inventory per environment
    hosts.yml                       Nodes + mirror roles (primary/backup)
    group_vars/all.yml              Per-env desired state (namespace, dbs, web app, security, mirror)
examples/
  desired-state.example.yml         Reference desired-state block to copy into a new env
cpf/
  database-template.cpf.j2          [Databases] merge (definition only)
  namespace-template.cpf.j2         [Namespaces] + [Map.<ns>] merge
objectscript/
  create_databases.cos.j2           Guarded physical IRIS.DAT + %DB_<name> resource
  setup_webapp.cos.j2               Guarded CSP app create/modify
  setup_security.cos.j2             Guarded services + roles + optional password rotation
  setup_production.cos.j2           Guarded interop production auto-start
  validate_readiness.cos.j2         Read-only node readiness (incl. production) -> JSON
  validate_mirror.cos.j2            Read-only mirror readiness -> JSON
  security_sync/                    SecuritySync ObjectScript module (roles/users sync)
  invoke_security_sync.cos.j2       Thin invoke script for SecuritySync.Service
  install_security_sync.cos.j2      Load/compile SecuritySync classes into %SYS
architecture/                       Mermaid architecture diagram (export to PNG)
playbooks/
  site.yml                          Infra bring-up + full configure (end to end)
  prepare.yml stack_up.yml stack_down.yml verify.yml   Infra lifecycle
  configure.yml                     databases -> namespace -> webapp -> security -> production -> validate
  setup_databases.yml create_namespace.yml setup_webapp.yml setup_security.yml setup_production.yml
  validate_nodes.yml validate_mirror.yml test_routing.yml
  sync_security.yml validate_security_sync.yml   Primary → backup security sync
  tasks/                            Reusable helpers (push_file, fetch_file, iris_merge, iris_session, install_security_sync)
docs/                               Runbook + mechanism-mapping + failure-modes + secrets + demo-script
evidence/                           Placeholder for captured run output (git-ignored contents)
```

---

## 4. First run (POC)

From the repository root:

```bash
# 1. Bring up infra and configure IRIS in one shot
ansible-playbook playbooks/site.yml -i inventories/poc \
  -e iris_key_source=/secure/path/to/iris.key

# If your image does not need a key:
ansible-playbook playbooks/site.yml -i inventories/poc -e require_iris_key=false
```

Step-by-step equivalent (useful when debugging a single stage):

```bash
ansible-playbook playbooks/prepare.yml   -i inventories/poc -e iris_key_source=/path/iris.key
ansible-playbook playbooks/stack_up.yml  -i inventories/poc
ansible-playbook playbooks/verify.yml    -i inventories/poc
ansible-playbook playbooks/configure.yml -i inventories/poc
```

`configure.yml` on its own runs: databases -> namespace -> web app ->
security -> node validation -> mirror validation.

---

## 5. Verify

```bash
# Node readiness (asserts namespace/dbs/web app exist on every node)
ansible-playbook playbooks/validate_nodes.yml  -i inventories/poc

# Mirror readiness (arbiter reachable + journaling/member state per node)
ansible-playbook playbooks/validate_mirror.yml -i inventories/poc

# HAProxy -> Web Gateway -> IRIS routing
ansible-playbook playbooks/test_routing.yml    -i inventories/poc
```

Capture JSON evidence during validation:

```bash
ansible-playbook playbooks/validate_nodes.yml -i inventories/poc -e write_evidence=true
# writes evidence/readiness-poc-<node>.json
```

---

## 5b. Security sync (primary → backup)

After both nodes are configured and mirroring is enabled, sync roles and
users from primary to backup (IRISSECURITY is **not** mirrored):

```bash
# Real import (post-bootstrap or after primary-side security changes)
ansible-playbook playbooks/sync_security.yml -i inventories/poc \
  -e security_sync_enabled=true \
  -e security_sync_dry_run=false

# Dry-run only (validate XML counts without applying)
ansible-playbook playbooks/sync_security.yml -i inventories/poc \
  -e security_sync_enabled=true \
  -e security_sync_dry_run=true

# Optional post-sync validation
ansible-playbook playbooks/validate_security_sync.yml -i inventories/poc \
  -e security_sync_enabled=true
```

E2E proof with a deliberate primary-only delta:

```bash
ansible-playbook playbooks/sync_security.yml -i inventories/poc \
  -e security_sync_enabled=true \
  -e security_sync_dry_run=false \
  -e security_sync_create_test_delta=true \
  -e 'security_sync_required_users=["sync_test_user"]' \
  -e write_evidence=true
```

Exported XML contains password hashes, not plaintext — treat as sensitive.
Playbooks use `no_log` and delete XML/invoke scripts after each run.

---

## 6. Idempotency

Re-running any playbook converges to the same state:

- **CPF merge** updates existing definitions and creates missing ones; it
  does not duplicate. Tasks mark `changed` only when the merge output
  indicates a real change.
- **ObjectScript** setup scripts check `...Exists()` before creating and
  otherwise modify, printing `CREATED` / `UPDATED` / `EXISTS`. Tasks mark
  `changed` only when `CREATED`/`PWROTATE` appears.
- **Validation** playbooks are read-only and never report `changed`.

Prove it: run `configure.yml` twice; the second run should report no
`CREATED` markers and `changed=0` for the merges.

---

## 7. Secrets

See `docs/secrets-and-security.md`. In short:

- License key: pass `-e iris_key_source=...`; it is copied with
  `no_log` and is git-ignored.
- Passwords: stored only in an ansible-vault file
  (`group_vars/vault.yml`, git-ignored). Rotate the admin password with:

```bash
ansible-playbook playbooks/setup_security.yml -i inventories/poc \
  -e rotate_admin_password=true --ask-vault-pass
```

---

## 8. Troubleshooting

| Symptom | Likely cause | Action |
| ------- | ------------ | ------ |
| `Ansible requires the locale encoding to be UTF-8; Detected 1252` | Native Windows PowerShell | Run from WSL/Ubuntu or a UTF-8 shell |
| `Missing irisa/iris.key` (assert in prepare) | No license key staged | Pass `-e iris_key_source=...` or `-e require_iris_key=false` |
| `wait_for` times out in `verify.yml` | Containers still starting or image pull failing | `docker compose ps`, `docker compose logs <svc>` |
| CPF merge task fails with `ERROR` | Bad directory or unsupported CPF section (e.g. a services section - `ERROR #415`) | Read `merge_result.stdout_lines`; services are enabled via ObjectScript, not CPF (see mechanism-mapping) |
| `<DIRECTORY>` when entering the namespace | Physical `IRIS.DAT` not created (definition-only merge) | Run `setup_databases.yml` - it creates the physical DB via guarded ObjectScript after the merge |
| Role create fails `#892 Resource ... does not exist` | `%DB_<name>` resource missing | Run `setup_databases.yml` first - it creates/binds the DB resources the role references |
| `<SYNTAX>` in an ObjectScript step | Multi-line `{ }` block fed to the `iris session` REPL | Keep each statement (whole `try {...} catch {...}`) on one line; no `$$$` macros |
| `from_json` errors in validation | JSON line not found/parsed | Check `session_result.stdout` for the `READINESS_JSON:`/`MIRROR_JSON:` line the playbook selects |
| Mirror validation fails on journaling | Journaling disabled | Enable journaling, or set `mirror_requires_journaling=false` for a pre-mirror node |

More detail and partial-failure recovery: `docs/failure-modes.md`.

---

## 9. Extend the POC

- **New environment**: copy `inventories/poc/` to `inventories/<env>/`,
  edit `hosts.yml` (real addresses) and `group_vars/all.yml` (desired
  state). Run any playbook with `-i inventories/<env>`.
- **New database / mapping**: add to the `databases` list (and mapping in
  the namespace template if needed). No code change required.
- **New web app / role**: add to `web_apps` / `security_roles`. The
  guarded ObjectScript loops over the lists.
- **New node**: add it to the inventory with a `mirror_role` and
  `iris_container`. Playbooks target groups, not machines.

---

## 10. Tear down

```bash
ansible-playbook playbooks/stack_down.yml -i inventories/poc
```
