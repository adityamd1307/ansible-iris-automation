# Evidence — Topic 2 sharding

Git-ignored outputs from sharding POC runs. Same policy as
[../README.md](../README.md): folder tracked, artifacts not committed.

## What to capture

| File | Produced by | Shows |
| ---- | ----------- | ----- |
| `validation-sharding-<node>.json` | `validate_sharding.yml -e write_evidence=true` | `SHARDING_JSON` per node |
| `configure-sharding-rerun.log` | second `configure_sharding.yml` | idempotency |
| `gate-status.txt` | manual | license/edition gate outcome |
| `incident-*.log` | `docker logs` redirect | troubleshooting |

Example:

```bash
ansible-playbook playbooks/sharding/validate_sharding.yml -i inventories/sharding \
  -e write_evidence=true
```

See [docs/sharding/demo-script.md](../../docs/sharding/demo-script.md).
