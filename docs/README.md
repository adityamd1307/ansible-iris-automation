# Documentation Index — IRIS Ansible Automation (Topic 1)

Start here if you are new to the repo. Each guide is written so you can
**demo or run that area standalone** without reading the whole codebase.

**Repo root (macOS example):** `/Users/aryand/Desktop/ansible-iris-automation`

---

## Quick start

| Doc | Use when you need to… |
| --- | --------------------- |
| [ansible-runbook.md](ansible-runbook.md) | Set up, run, verify, and troubleshoot the POC end-to-end |
| [demo-script.md](demo-script.md) | ~10-minute presenter walkthrough |
| [30-minute-demo-runbook.md](30-minute-demo-runbook.md) | Longer demo with mirror SQL replication proof |
| [configure-flow-explained.md](configure-flow-explained.md) | File-by-file explanation of `configure.yml` |

---

## Topic guides (one per automation area)

| Topic | Guide | Playbook(s) |
| ----- | ----- | ----------- |
| **Infrastructure** | [infra-overview.md](infra-overview.md) | Docker Compose under `iris-env/`; license placement |
| **Databases** | [databases-overview.md](databases-overview.md) | `setup_databases.yml` |
| **Namespace & mappings** | [namespace-overview.md](namespace-overview.md) | `create_namespace.yml` |
| **Web applications** | [webapp-overview.md](webapp-overview.md) | `setup_webapp.yml` |
| **Security & sync** | [security-overview.md](security-overview.md) | `setup_security.yml`, `sync_security.yml`, `validate_security_sync.yml` |
| **Mirror** | [mirror-overview.md](mirror-overview.md) | `setup_mirror.yml`, `validate_mirror.yml` |
| **Interop production** | [production-overview.md](production-overview.md) | `setup_production_import.yml`, `setup_production_autostart.yml`, failover playbooks |
| **Routing (HAProxy)** | [routing-overview.md](routing-overview.md) | `update_haproxy_primary.yml`, `test_routing.yml` |
| **Validation** | [validation-overview.md](validation-overview.md) | All `validate_*.yml` playbooks |

---

## Reference & cross-cutting

| Doc | Contents |
| --- | -------- |
| [mechanism-mapping.md](mechanism-mapping.md) | CPF vs ObjectScript vs REST per configuration item |
| [secrets-and-security.md](secrets-and-security.md) | Vault, `no_log`, license key handling |
| [failure-modes.md](failure-modes.md) | Partial failures, recovery, `--limit` |
| [licensed-image-setup.md](licensed-image-setup.md) | Licensed `intersystems/iris` image for interop |

---

## Master configure flow

`playbooks/configure.yml` runs (in order):

```text
setup_databases → setup_mirror → create_namespace → setup_webapp
→ setup_security → setup_production_import → setup_mirror (finalize)
→ setup_production_autostart → validate_nodes → validate_mirror → sync_security
```

```bash
cd /Users/aryand/Desktop/ansible-iris-automation
ansible-playbook playbooks/configure.yml -i inventories/poc
```

Expected recap: `failed=0`.

---

## Desired state & environments

| Path | Purpose |
| ---- | ------- |
| `inventories/poc/group_vars/all.yml` | POC desired state (namespace, DBs, mirror, security, production) |
| `inventories/poc/hosts.yml` | `irisa` / `irisb` groups and mirror roles |
| `inventories/dev|sit|uat/` | Same pattern for other environments |
| `examples/desired-state.example.yml` | Template to copy for new envs |
| `group_vars/all.yml` | Shared infra (images, ports, HAProxy backends) |

---

## Management Portal (always use `.csp`)

| Node | URL |
| ---- | --- |
| Primary | http://localhost:8081/csp/sys/UtilHome.csp |
| Backup | http://localhost:8082/csp/sys/UtilHome.csp |
| HAProxy | http://localhost:8080/csp/sys/UtilHome.csp |
