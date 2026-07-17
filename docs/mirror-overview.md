# Mirror Overview — Primary, Backup, Failover

How Ansible configures and validates the IRIS mirror in this two-node POC.

**Related:** [databases-overview.md](databases-overview.md) · [routing-overview.md](routing-overview.md) · [production-overview.md](production-overview.md)

---

## Topology

```text
irisa (primary)  ←—— mirror ——→  irisb (backup)
         ↑                              ↑
    ISCAgent :21881               ISCAgent :21882
         └──────── arbiter :21883 ──────┘
```

Mirror name: `TRAININGMIRROR` (from inventory)

Mirrored databases: `TRAININGDATA`, `TRAININGCODE`

---

## Playbook

```bash
ansible-playbook playbooks/setup_mirror.yml -i inventories/poc
```

**Three plays (order matters):**

| Play | Hosts | Role | Purpose |
| ---- | ----- | ---- | ------- |
| Primary setup | `iris_primary` | `iris_mirror_primary` | CPF + create mirror, add DBs |
| Backup join | `iris_backup` | `iris_mirror_backup` | Join mirror set |
| Finalize failover | `iris_primary` | `iris_mirror_primary_finalize` | Register backup as failover member |

`configure.yml` runs mirror **twice** — early partial setup, then again after
production import so membership is finalized when app objects exist.

---

## Mechanisms

| Item | Mechanism |
| ---- | --------- |
| Mirror member config | CPF merge (`cpf/mirror-template.cpf.j2`) |
| Create / join / add DBs | Guarded ObjectScript (`setup_mirror_primary.cos.j2`, `setup_mirror_backup.cos.j2`, `setup_mirror_primary_add_failover.cos.j2`) |
| ISCAgent | Started via `roles/iris_common/tasks/start_iscagent.yml` before mirror APIs |

Known duplicate states (e.g. `#2137` member exists) are treated as `EXISTS ...` — idempotent.

---

## Validation

```bash
ansible-playbook playbooks/validate_mirror.yml -i inventories/poc
```

Emits `MIRROR_JSON:{...}` per node. Expected:

| Node | Fields |
| ---- | ------ |
| `irisa` | `is_primary: true`, `is_backup: false`, `is_mirror_member: true` |
| `irisb` | `is_primary: false`, `is_backup: true`, `is_mirror_member: true` |

Also checks arbiter reachability (`mirror_arbiter_host` / `mirror_arbiter_port`) and journaling when `mirror_requires_journaling: true`.

---

## Portal verification

http://localhost:8081/csp/sys/UtilHome.csp →

**System Administration → Configuration → Mirror Settings**

Expected:

- Mirror name: `TRAININGMIRROR`
- `irisa`: Primary, Failover member
- `irisb`: Backup, Failover member
- Databases: `TRAININGDATA`, `TRAININGCODE` mirrored

---

## Data replication demo

After configure completes, create a table on primary SQL and query on backup:

```sql
-- On irisa (primary)
CREATE TABLE SQLUser.DemoMirrorTest (
  ID INTEGER IDENTITY PRIMARY KEY,
  Note VARCHAR(100)
);
INSERT INTO SQLUser.DemoMirrorTest (Note) VALUES ('created on primary');

-- On irisb (backup) — row should appear
SELECT * FROM SQLUser.DemoMirrorTest;
```

See [30-minute-demo-runbook.md](30-minute-demo-runbook.md) § replication.

**Not replicated:** IRISSECURITY (roles/users) — see [security-overview.md](security-overview.md).

---

## Failover (manual lab test)

```bash
docker kill irisa
# wait 30–60s
ansible-playbook playbooks/validate_mirror.yml -i inventories/poc
ansible-playbook playbooks/update_haproxy_primary.yml -i inventories/poc
```

IRIS does not automatically fail back — reset Docker state for a clean primary role.

Production after failover: [production-overview.md](production-overview.md).

---

## Inventory knobs

```yaml
mirror_enabled: true
mirror_name: TRAININGMIRROR
mirror_arbiter_host: 127.0.0.1
mirror_arbiter_port: 21883
mirror_arbiter_url: arbiter:2188    # inside container network
mirror_requires_journaling: true
mirror_databases:
  - TRAININGDATA
  - TRAININGCODE
```

---

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| Backup won't join | Check ISCAgent, arbiter, network; `docker logs irisb` |
| Journaling assertion fails | Enable journaling or `mirror_requires_journaling=false` for lab |
| `#2137` in output | Usually OK — treated as member already exists |
| DB not in mirror set | Re-run `setup_mirror.yml`; check `mirror_databases` list |

More: [failure-modes.md](failure-modes.md)

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/setup_mirror.yml` | Three-play mirror flow |
| `playbooks/validate_mirror.yml` | Read-only mirror JSON validation |
| `cpf/mirror-template.cpf.j2` | `[Config.Mirror]` merge |
| `objectscript/setup_mirror_*.cos.j2` | Runtime mirror APIs |
| `roles/iris_mirror_primary/` / `iris_mirror_backup/` / `iris_mirror_primary_finalize/` | Task orchestration |
