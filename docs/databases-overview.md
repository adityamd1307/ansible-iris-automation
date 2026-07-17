# Databases Overview — Physical DBs & `%DB_*` Resources

How Ansible creates IRIS databases in this POC. This is **Layer 1** for security
(roles reference `%DB_<name>` resources created here).

**Related:** [namespace-overview.md](namespace-overview.md) · [security-overview.md](security-overview.md) · [mechanism-mapping.md](mechanism-mapping.md)

---

## The two-step problem

IRIS database setup needs **two mechanisms**:

| Step | Mechanism | What it does |
| ---- | --------- | ------------ |
| 1 | **CPF merge** | Registers database **definition** in config (`[Databases]`) |
| 2 | **Guarded ObjectScript** | Creates physical `IRIS.DAT` + `%DB_<name>` **resource** |

A CPF merge alone registers the directory but does **not** mount a usable DB —
entering the namespace would show `<DIRECTORY>` without step 2.

---

## Playbook

```bash
ansible-playbook playbooks/setup_databases.yml -i inventories/poc
```

**Role:** `roles/iris_databases/tasks/main.yml`

**Flow:**

1. `mkdir -p` + ownership for each database directory (docker exec as root)
2. Stage and merge `cpf/database-template.cpf.j2`
3. Run `objectscript/create_databases.cos.j2` via `iris session`

---

## Desired state (`inventories/poc/group_vars/all.yml`)

```yaml
db_directory_root: /usr/irissys/mgr
databases:
  - name: TRAININGDATA
    directory: /usr/irissys/mgr/trainingdata
    size_mb: 10
  - name: TRAININGCODE
    directory: /usr/irissys/mgr/trainingcode
    size_mb: 10
  - name: TRAININGDATAENSTEMP
    directory: .../trainingdata/trainingdataenstemp
    size_mb: 10
```

Add a database by extending the `databases` list — no code change required.

---

## Expected output markers

| Marker | Meaning |
| ------ | ------- |
| `EXISTS TRAININGDATA` | Physical DB already present (idempotent re-run) |
| `CREATED TRAININGDATA` | New physical DB created |
| `EXISTS RESOURCE %DB_TRAININGDATA` | Security resource bound |
| `CREATED RESOURCE %DB_TRAININGDATA` | New resource created |

Role creation in `setup_security.yml` fails with `#892 Resource … does not exist`
if this playbook was skipped.

---

## Portal verification

http://localhost:8081/csp/sys/UtilHome.csp →

**System Administration → Configuration → System Configuration → Local Databases**

Confirm `TRAININGDATA`, `TRAININGCODE`, and ENS temp DB exist on **both** nodes.

---

## Mirror note

`TRAININGDATA` and `TRAININGCODE` are listed in `mirror_databases` and added to
the mirror set by `setup_mirror.yml`. The ENS temp DB is typically **not** mirrored.

---

## Idempotency

- Directories: `mkdir -p` (no error if exists)
- CPF merge: converges definitions
- ObjectScript: `SYS.Database.%ExistsId()` / `Security.Resources.Exists()` guards

Re-run should show `EXISTS` markers and `changed=0` on merge when already converged.

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/setup_databases.yml` | Entry playbook |
| `cpf/database-template.cpf.j2` | `[Databases]` merge |
| `objectscript/create_databases.cos.j2` | Physical DB + resource creation |
| `roles/iris_databases/` | Task orchestration |
| `roles/iris_common/tasks/iris_merge.yml` | `iris merge` wrapper |
| `roles/iris_common/tasks/iris_session.yml` | `iris session` wrapper |
