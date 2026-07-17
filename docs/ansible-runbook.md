# Ansible IRIS Automation - Runbook (Week 2 POC, Topic 1)

This runbook lets another engineer **set up, run, verify, troubleshoot,
and extend** the InterSystems IRIS automation POC without prior context.

**Documentation index (all topics):** [docs/README.md](README.md)

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
5. **Interop production** - classes imported on **primary only**; auto-start on **all nodes**
   (`playbooks/setup_production.yml`; routines replicate via mirrored code DB)
6. **Mirror** - primary create → backup join → primary add-failover (`setup_mirror.yml`)
7. **Validation** of node readiness (incl. production status) and **mirror readiness** (read-only, JSON)

See `docs/mechanism-mapping.md` for the full per-item mechanism table
(CPF vs ObjectScript vs REST) and `architecture/` for the diagram.

**Per-topic guides:** [docs/README.md](README.md) (databases, namespace, mirror, production, routing, security, validation).

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
  configure.yml                     Full Topic-1 configure flow (see docs/README.md)
  setup_*.yml validate_*.yml        Per-area playbooks (each has a topic guide in docs/)
  sync_security.yml                 Primary → backup security sync
  test_routing.yml update_haproxy_primary.yml   HAProxy routing
docs/                               Index + topic guides + runbook + mechanism-mapping
evidence/                           Placeholder for captured run output (git-ignored contents)
```

---

## 4. First run (POC)

See [infra-overview.md](infra-overview.md) for Docker topology details.

From the repository root:

```bash
# 1. Stage license (never commit iris.key)
cp /secure/path/iris.key iris-env/IRISSystemManagement/irisa/iris.key
cp /secure/path/iris.key iris-env/IRISSystemManagement/irisb/iris.key

# 2. Start Docker stack
cd iris-env/IRISSystemManagement && docker compose up -d --pull missing

# 3. Configure IRIS (from repo root)
cd /Users/aryand/Desktop/ansible-iris-automation
ansible-playbook playbooks/configure.yml -i inventories/poc
```

`configure.yml` runs the full ordered flow (databases → mirror → namespace →
web app → security → production import → mirror finalize → autostart →
validate → security sync). See [configure-flow-explained.md](configure-flow-explained.md).

For full Topic 1 green (interop + production), use a licensed
`intersystems/iris:latest-cd` image — see [licensed-image-setup.md](licensed-image-setup.md).

Portal URLs use **`.csp`**: `http://localhost:8081/csp/sys/UtilHome.csp`

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

> **Overview:** [security-overview.md](security-overview.md) — problem, three
> layers (DB resources → bootstrap → sync), Portal checks, troubleshooting.

After both nodes are configured and mirroring is enabled, sync roles and
users from primary to backup (IRISSECURITY is **not** mirrored).

`configure.yml` imports `sync_security.yml` as its **last** step (after mirror
validation). You can also run sync standalone when primary-side security
changes.

Playbook phases in `sync_security.yml`:

1. **Install** — load/compile `SecuritySync.*` on all nodes (`install_security_sync`)
2. **Export** — optional E2E test delta on primary; `Security.Roles/Users`.Export → XML
3. **Transfer** — fetch XML to control node, copy into backup (`no_log`)
4. **Import** — dry-run (`Flags=1`) or real import on backup
5. **Cleanup** — delete XML and invoke scripts on nodes and control node

Bootstrap (both nodes, before sync): `setup_security.yml` — see
[secrets-and-security.md](secrets-and-security.md#when-to-run-what-security-operations).

```bash
# Baseline security on all nodes (if not already run via configure.yml)
ansible-playbook playbooks/setup_security.yml -i inventories/poc
```

Sync commands:

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

**Expected markers:** `SECURITY_SYNC_JSON` with `"ok": true`; import shows
`roles_imported` and `users_imported` > 0; Ansible recap `failed=0`.
Bootstrap re-runs show `EXISTS ROLE` (not `CREATED`).

**Portal verification** (`.csp` URLs):

- Primary: http://localhost:8081/csp/sys/UtilHome.csp
- Backup: http://localhost:8082/csp/sys/UtilHome.csp

Check System Administration → Security → Roles, Resources, Services, Users
on both nodes after sync.

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

See [docs/secrets-and-security.md](secrets-and-security.md) and
[docs/security-overview.md](security-overview.md). In short:

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
