# Demo Script - Week 2 POC (Topic 1)

A ~10-minute walkthrough proving working, idempotent, secret-safe IRIS
automation across two nodes with mirror readiness. Capture output into
`evidence/` as you go.

**All topic guides:** [docs/README.md](README.md)

> Set a shell variable to keep commands short:
> `INV=inventories/poc`

---

## 0. Pre-demo checklist (do before the audience joins)

- [ ] Docker running; images pullable
- [ ] `iris.key` available at a known secure path (or use `-e require_iris_key=false`)
- [ ] Repo clean: `git status` shows no `vault.yml` / `*.key` / `.env`
- [ ] Terminal in a UTF-8 shell (WSL/Ubuntu on Windows)

---

## 1. Show the desired state (parameterization) - 1 min

> "Everything is declarative and per-environment. No machine or namespace
> is hardcoded."

```bash
sed -n '1,40p' inventories/poc/group_vars/all.yml
ls inventories/            # poc dev sit uat
```

---

## 2. Bring up infrastructure - 2 min

```bash
ansible-playbook playbooks/prepare.yml  -i $INV -e iris_key_source=/secure/path/iris.key
ansible-playbook playbooks/stack_up.yml -i $INV
ansible-playbook playbooks/verify.yml   -i $INV
```

> Point out the `verify` step waiting on published ports and listing
> running services.

---

## 3. Configure IRIS (namespace, db, web app, security) - 2 min

```bash
ansible-playbook playbooks/configure.yml -i $INV
```

> Call out the ordered flow: databases (CPF) -> namespace/mappings (CPF)
> -> web app (guarded ObjectScript) -> security -> validation.

---

## 4. Prove idempotency - 1 min

```bash
ansible-playbook playbooks/configure.yml -i $INV | tee evidence/configure-rerun.log
```

> Show `changed=0` on the merges and **no** `CREATED` markers on the
> second run. "Re-running converges; it does not duplicate."

---

## 5. Validate node & mirror readiness - 2 min

```bash
ansible-playbook playbooks/validate_nodes.yml  -i $INV -e write_evidence=true
ansible-playbook playbooks/validate_mirror.yml -i $INV
cat evidence/readiness-poc-*.json
```

> Show the JSON: namespace/dbs/web app exist on **both** nodes, and each
> node reports its mirror role, journaling state, and arbiter reachability.

---

## 6. Prove routing - 30 sec

```bash
ansible-playbook playbooks/test_routing.yml -i $INV
```

---

## 7. Show secret safety - 1 min

```bash
git status                                   # no vault.yml / *.key / .env tracked
sed -n '1,20p' group_vars/vault.example.yml  # template only, CHANGE_ME placeholders
# Optional: rotate the admin password from the vault (output is no_log)
ansible-playbook playbooks/setup_security.yml -i $INV \
  -e rotate_admin_password=true --ask-vault-pass
```

> "License key and passwords never touch git; sensitive tasks run with
> `no_log`; the templated security script is deleted after it runs."

---

## 8. Tear down (optional) - 30 sec

```bash
ansible-playbook playbooks/stack_down.yml -i $INV
```

---

## 9. Security demo (primary → backup sync) - 3 min

> "Mirroring copies data databases, not IRISSECURITY. Bootstrap puts the same
> roles on both nodes; sync exports from primary and imports on backup so
> failover has matching users and role definitions."

Full reference: [security-overview.md](security-overview.md).

**Show desired state** (roles + sync flags):

```bash
sed -n '63,77p' inventories/poc/group_vars/all.yml   # security_roles, security_services
sed -n '132,144p' inventories/poc/group_vars/all.yml # security_sync_*
```

**Bootstrap** (if not already done via `configure.yml`):

```bash
ansible-playbook playbooks/setup_security.yml -i $INV
```

> Point at `EXISTS ROLE TRAINING_APP` and `EXISTS SERVICE %Service_WebGateway`.
> Roles reference `%DB_*` resources created in `setup_databases.yml`.

**Real sync** (export on primary, import on backup):

```bash
ansible-playbook playbooks/sync_security.yml -i $INV \
  -e security_sync_enabled=true \
  -e security_sync_dry_run=false
```

> Highlight `SECURITY_SYNC_JSON` and `roles_imported` / `users_imported`.
> XML and invoke scripts are removed after the run (`no_log` on file transfer).

**Validate** (read-only, both nodes):

```bash
ansible-playbook playbooks/validate_security_sync.yml -i $INV \
  -e security_sync_enabled=true
```

**Portal** (use `.csp`, not `.cs`):

- Primary: http://localhost:8081/csp/sys/UtilHome.csp → Security → Roles → `TRAINING_APP`
- Backup: http://localhost:8082/csp/sys/UtilHome.csp → same check on `irisb`

**Optional E2E delta** (creates `sync_test_user` on primary, syncs to backup):

```bash
ansible-playbook playbooks/sync_security.yml -i $INV \
  -e security_sync_enabled=true \
  -e security_sync_dry_run=false \
  -e security_sync_create_test_delta=true \
  -e 'security_sync_required_users=["sync_test_user"]'
```

**Talking points:**

- Three layers: DB resources → bootstrap on all nodes → primary→backup sync.
- CPF cannot enable services (`ERROR #415`); ObjectScript uses `Security.Services`.
- Secrets never in git; sync XML has hashes only; vault + `no_log` for passwords.

---

## Talking points / Q&A

- **Idempotency**: CPF merge converges; ObjectScript is guarded by
  `...Exists()`.
- **Portability**: switch `-i inventories/dev|sit|uat` - same playbooks.
- **CPF vs ObjectScript**: CPF for databases/namespace/mapping;
  ObjectScript for web apps, roles, services, password, security sync.
- **IRISSECURITY gap**: mirror does not copy roles/users — see
  [security-overview.md](security-overview.md).
- **Failure handling**: see `docs/failure-modes.md` (fix + re-run,
  `--limit <host>`).
