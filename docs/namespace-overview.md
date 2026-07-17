# Namespace Overview — TRAINING Namespace & DB Mappings

How Ansible creates the application namespace and maps globals/routines to databases.

**Related:** [databases-overview.md](databases-overview.md) · [webapp-overview.md](webapp-overview.md) · [configure-flow-explained.md](configure-flow-explained.md)

---

## Playbook

```bash
ansible-playbook playbooks/create_namespace.yml -i inventories/poc
```

**Prerequisite:** `setup_databases.yml` — namespace entries point at DB names that must exist.

**Role:** `roles/iris_namespace/tasks/main.yml`

**Mechanism:** CPF merge only (`cpf/namespace-template.cpf.j2`) — no ObjectScript required for namespace creation in this POC.

---

## Desired state

```yaml
namespace: TRAINING
globals_db: TRAININGDATA
routines_db: TRAININGCODE
namespace_interop: true          # enables Interoperability in namespace
namespace_interop_enforce: true  # validation fails if interop unavailable
```

The CPF template generates:

```ini
[Namespaces]
TRAINING=TRAININGDATA

[Map.TRAINING]
Global_Default=TRAININGDATA
Routine_Default=TRAININGCODE
```

---

## Order in `configure.yml`

```text
setup_databases → setup_mirror (partial) → create_namespace → ...
```

Namespace is created **after** databases so mappings resolve. Mirror may run
before namespace in configure — first mirror pass is idempotent partial setup.

---

## Expected output

CPF merge stdout shows namespace registration. No `CREATED`/`EXISTS` ObjectScript
markers for this step.

Validation (`validate_nodes.yml`) asserts:

```json
"namespace_exists": true,
"globals_db_exists": true,
"routines_db_exists": true
```

in `READINESS_JSON`.

---

## Portal verification

http://localhost:8081/csp/sys/UtilHome.csp →

**System Administration → Configuration → System Configuration → Namespaces**

- Namespace `TRAINING` exists
- Default global database: `TRAININGDATA`
- Default routine database: `TRAININGCODE`
- Interoperability enabled (if `namespace_interop: true`)

Repeat on `:8082` for backup.

---

## Interoperability requirement

Production automation (`setup_production_import.yml`) needs a licensed
`intersystems/iris` image with Interoperability — not `irishealth` alone.
See [licensed-image-setup.md](licensed-image-setup.md) and [production-overview.md](production-overview.md).

---

## Troubleshooting

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| Namespace maps to `<DIRECTORY>` | Physical DB missing | Run `setup_databases.yml` |
| CPF merge ERROR on namespace | DB name not registered | Run `setup_databases.yml` first |
| `interop_available: false` in JSON | Wrong image or interop not enabled | Licensed image + `namespace_interop: true` |

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/create_namespace.yml` | Entry playbook |
| `cpf/namespace-template.cpf.j2` | Namespace + `[Map.<ns>]` merge |
| `roles/iris_namespace/` | Stage, merge, cleanup |
