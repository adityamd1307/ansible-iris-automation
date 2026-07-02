# Evidence

This folder holds **captured output** from POC runs (validation JSON,
re-run logs, screenshots) used to demonstrate the Week 2 deliverables.

The **contents are git-ignored** (`*.json`, `*.log`, `*.txt`) so that run
artifacts - which may include host names or environment detail - are not
committed. This `README.md` and `.gitkeep` are the only tracked files, so
the folder always exists.

## What to capture (see docs/demo-script.md)

| File | Produced by | Shows |
| ---- | ----------- | ----- |
| `readiness-<env>-<node>.json` | `validate_nodes.yml -e write_evidence=true` | namespace/db/web app present per node |
| `configure-rerun.log` | second `configure.yml` run | idempotency (`changed=0`, no `CREATED`) |
| `mirror-<env>.txt` | `validate_mirror.yml` (redirect output) | mirror role, journaling, arbiter reachability |
| `routing.txt` | `test_routing.yml` (redirect output) | HAProxy -> Web Gateway -> IRIS |

Example:

```bash
ansible-playbook playbooks/validate_mirror.yml -i inventories/poc | tee evidence/mirror-poc.txt
```
