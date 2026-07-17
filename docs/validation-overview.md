# Validation Overview — Read-Only Checks & JSON Evidence

All validation playbooks in this repo. **None of them mutate IRIS state** —
safe to run anytime to audit current convergence.

**Related:** [ansible-runbook.md §5](ansible-runbook.md#5-verify) · [failure-modes.md](failure-modes.md)

---

## Summary table

| Playbook | Hosts | JSON prefix | Asserts |
| -------- | ----- | ----------- | ------- |
| `validate_nodes.yml` | all nodes | `READINESS_JSON` | Namespace, DBs, web app, production |
| `validate_mirror.yml` | all nodes | `MIRROR_JSON` | Mirror role, journaling, arbiter |
| `validate_security_sync.yml` | all nodes | `SECURITY_SYNC_JSON` | Role/user counts, required lists |
| `validate_failover_production.yml` | all nodes | `READINESS_JSON` | Production failover readiness |
| `validate_production_mirror_data.yml` | varies | (playbook-specific) | Production data on mirror path |
| `test_routing.yml` | localhost | — | HAProxy → IRIS HTTP 200 |

Topic guides: [security-overview.md](security-overview.md) · [mirror-overview.md](mirror-overview.md) · [production-overview.md](production-overview.md) · [routing-overview.md](routing-overview.md)

---

## `validate_nodes.yml`

```bash
ansible-playbook playbooks/validate_nodes.yml -i inventories/poc
ansible-playbook playbooks/validate_nodes.yml -i inventories/poc -e write_evidence=true
```

**Role:** `iris_validate_nodes`

**Script:** `objectscript/validate_readiness.cos.j2`

**Key JSON fields:**

```json
{
  "namespace_exists": true,
  "globals_db_exists": true,
  "routines_db_exists": true,
  "web_app_exists": true,
  "interop_available": true,
  "production_configured": true,
  "production_running": true
}
```

**Production assertions** (when `production_enforce: true`):

- Primary must have `production_running: true`
- Backup must have `production_configured: true` (running may be false)

Evidence: `evidence/readiness-poc-<hostname>.json`

---

## `validate_mirror.yml`

```bash
ansible-playbook playbooks/validate_mirror.yml -i inventories/poc
```

**Role:** `iris_validate_mirror`

**Script:** `objectscript/validate_mirror.cos.j2`

**Key JSON fields:**

```json
{
  "is_mirror_member": true,
  "is_primary": true,
  "is_backup": false,
  "journaling_enabled": true,
  "arbiter_reachable": true
}
```

Expected recap:

```text
Mirror readiness OK on irisa (role: primary).
Mirror readiness OK on irisb (role: backup).
failed=0
```

---

## `validate_security_sync.yml`

```bash
ansible-playbook playbooks/validate_security_sync.yml -i inventories/poc \
  -e security_sync_enabled=true
```

Skips entirely when `security_sync_enabled=false`.

See [security-overview.md](security-overview.md).

---

## `validate_failover_production.yml`

```bash
ansible-playbook playbooks/validate_failover_production.yml -i inventories/poc
```

Use after configure or after failover drill. Mirror-role-aware production checks.

Evidence: `evidence/failover-production-poc-<hostname>.json`

---

## `test_routing.yml`

```bash
ansible-playbook playbooks/test_routing.yml -i inventories/poc
```

Not ObjectScript — HTTP GET via HAProxy. See [routing-overview.md](routing-overview.md).

---

## Capture evidence for demos

```bash
INV=inventories/poc
ansible-playbook playbooks/validate_nodes.yml  -i $INV -e write_evidence=true
ansible-playbook playbooks/validate_mirror.yml -i $INV -e write_evidence=true
ansible-playbook playbooks/sync_security.yml   -i $INV -e write_evidence=true \
  -e security_sync_enabled=true -e security_sync_dry_run=false
```

Output directory: `evidence/` (contents git-ignored).

---

## Parsing convention

All ObjectScript validation scripts emit **one JSON line** with a prefix:

```text
READINESS_JSON:{...}
MIRROR_JSON:{...}
SECURITY_SYNC_JSON:{...}
```

Playbooks select the line with `select('match', '^PREFIX:')` and `from_json`.
This avoids fragile multi-line regex against `iris session` prompt noise.

See [mechanism-mapping.md](mechanism-mapping.md) § ObjectScript execution constraint.

---

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| `from_json` error | Inspect raw `session_result.stdout`; find PREFIX line |
| Validation passes on irisa, fails on irisb | Re-run failed configure step with `--limit irisb` |
| `production_enforce` failure | See [production-overview.md](production-overview.md) |
| Mirror arbiter timeout | Start arbiter container; check port 21883 |

Recovery pattern: fix root cause → re-run configure step → re-validate.
See [failure-modes.md](failure-modes.md).

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/validate_*.yml` | Validation entry points |
| `objectscript/validate_readiness.cos.j2` | Node readiness JSON |
| `objectscript/validate_mirror.cos.j2` | Mirror readiness JSON |
| `roles/iris_validate_*` | Task orchestration |
