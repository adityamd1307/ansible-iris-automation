# Production Overview — Interop Import, Auto-Start & Failover

How Ansible deploys the TRAINING interoperability production in a mirrored lab.

**Related:** [namespace-overview.md](namespace-overview.md) · [mirror-overview.md](mirror-overview.md) · [licensed-image-setup.md](licensed-image-setup.md)

---

## Requirements

- Licensed **`intersystems/iris`** image (not health-only) with Interoperability
- Namespace `TRAINING` with `namespace_interop: true`
- Mirrored `TRAININGCODE` DB (routines/classes replicate to backup)

See [licensed-image-setup.md](licensed-image-setup.md).

---

## Two playbooks (split by design)

| Playbook | Hosts | Purpose |
| -------- | ----- | ------- |
| `setup_production_import.yml` | **primary only** | Load/compile classes; register `Ens.Config.Production` |
| `setup_production_autostart.yml` | **primary only** | Set `Ens.Director` auto-start production |

```bash
ansible-playbook playbooks/setup_production_import.yml -i inventories/poc
ansible-playbook playbooks/setup_production_autostart.yml -i inventories/poc
```

Both are imported by `configure.yml` (import runs before second mirror pass; autostart after).

**Role:** `roles/iris_production/` — gated by `production.enabled: true`.

---

## Desired state

```yaml
production:
  class: TRAINING.Production
  auto_start: true
  enabled: true
  classes:
    - name: MirrorMessage.cls
      src: objectscript/production/MirrorMessage.cls.j2
      remote: /tmp/MirrorMessage.cls
    # ... MirrorOperation, MirrorService, Production, FailoverWatcher
production_enforce: true   # validate_nodes fails if production not ready
```

---

## What replicates vs what doesn't

| Replicates via mirror | Does not replicate |
| --------------------- | ------------------ |
| Compiled classes in `TRAININGCODE` | Whether production is **running** on backup |
| Namespace-level auto-start setting (journaled globals) | Primary-only import step (run once on primary) |
| `Ens.Config.Production` registration (via mirrored globals) | IRISSECURITY |

Import runs on **primary only**; backup receives classes through mirrored code DB.

---

## Expected output markers

**Import (`import_production_classes.cos.j2`):**

| Marker | Meaning |
| ------ | ------- |
| `LOAD MirrorMessage.cls` | Class loaded |
| `REGISTER PRODUCTION CONFIG` | Ens.Config.Production created |
| `EXISTS PRODUCTION CONFIG` | Already registered |
| `SKIP production-class-import` | Interop not available — non-fatal when `production_enforce: false` |

**Auto-start (`setup_production.cos.j2`):**

| Marker | Meaning |
| ------ | ------- |
| `SET AUTOSTART TRAINING.Production` | Auto-start configured |
| `EXISTS AUTOSTART` | Already set |

---

## Validation

```bash
ansible-playbook playbooks/validate_nodes.yml -i inventories/poc
```

`READINESS_JSON` fields (when `production_enforce: true`):

| Node | Expected |
| ---- | -------- |
| Primary (`irisa`) | `production_running: true`, `production_configured: true` |
| Backup (`irisb`) | `production_configured: true`, `production_running: false` (normal while backup) |

**Failover readiness:**

```bash
ansible-playbook playbooks/validate_failover_production.yml -i inventories/poc
```

**After killing primary:**

```bash
docker kill irisa
ansible-playbook playbooks/start_failover_production.yml -i inventories/poc   # if needed
ansible-playbook playbooks/validate_failover_production.yml -i inventories/poc
```

**Mirror data path test:**

```bash
ansible-playbook playbooks/validate_production_mirror_data.yml -i inventories/poc
```

---

## Portal verification

**Primary:** http://localhost:8081/csp/sys/UtilHome.csp

- **Interoperability → Configure → Production** — `TRAINING.Production` running
- **Interoperability → List → Production** — message flow

**Backup:** `:8082` — production configured but typically not running while backup.

---

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| `SKIP interop-not-enabled-or-missing-class` | Use licensed iris image; check `namespace_interop` |
| Production not running on primary | Re-run `setup_production_autostart.yml` |
| Backup missing production class | Re-run import on primary, then mirror validate |
| `production_enforce` fails | Set `false` until interop genuinely available |

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/setup_production_import.yml` | Primary class import |
| `playbooks/setup_production_autostart.yml` | Primary auto-start |
| `playbooks/validate_failover_production.yml` | Failover readiness JSON |
| `playbooks/start_failover_production.yml` | Start production on new primary |
| `objectscript/import_production_classes.cos.j2` | LOAD + Ens.Config register |
| `objectscript/setup_production.cos.j2` | Ens.Director auto-start |
| `objectscript/production/*.cls.j2` | Production class sources |
