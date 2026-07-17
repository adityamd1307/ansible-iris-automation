# Infrastructure Overview — Docker Topology & Prerequisites

How the local IRIS lab is wired before Ansible configures IRIS itself.

**Related:** [ansible-runbook.md](ansible-runbook.md) · [README.md](../README.md) · [licensed-image-setup.md](licensed-image-setup.md)

---

## What runs where

```text
localhost:8080  →  haproxy        → active primary's Web Gateway
localhost:8081  →  webgatewaya    → irisa (mirror primary)
localhost:8082  →  webgatewayb    → irisb (mirror backup)
localhost:51773 →  irisa superserver (1972 inside container)
localhost:61773 →  irisb superserver
localhost:21883 →  arbiter (mirror arbiter)
```

Docker Compose file:

```text
iris-env/IRISSystemManagement/docker-compose.yml
```

Runtime data (git-ignored durable dirs):

```text
iris-env/IRISSystemManagement/irisa/
iris-env/IRISSystemManagement/irisb/
iris-env/IRISSystemManagement/webgatewaya/
iris-env/IRISSystemManagement/webgatewayb/
```

Ansible playbooks live at the **repo root** (`playbooks/`, `roles/`, `inventories/`).

---

## Containers

| Container | Role | Notes |
| --------- | ---- | ----- |
| `irisa` | IRIS mirror primary | License at `./irisa/iris.key` |
| `irisb` | IRIS mirror backup | License at `./irisb/iris.key` |
| `webgatewaya` | CSP/Web Gateway for `irisa` | Published `:8081` |
| `webgatewayb` | CSP/Web Gateway for `irisb` | Published `:8082` |
| `arbiter` | Mirror arbiter | Validated by `validate_mirror.yml` |
| `haproxy` | Front door `:8080` | Follows active primary — see [routing-overview.md](routing-overview.md) |

Image tags come from `.env` (`IRISTAG`, `WEBGTAG`) or `group_vars/all.yml` defaults.

---

## Bring up infrastructure

From the repo root (see [README.md](../README.md) for Windows/WSL variants):

```bash
# 1. Place license (never commit iris.key)
cp /secure/path/iris.key iris-env/IRISSystemManagement/irisa/iris.key
cp /secure/path/iris.key iris-env/IRISSystemManagement/irisb/iris.key

# 2. Start stack
cd iris-env/IRISSystemManagement
docker compose up -d --pull missing
docker compose ps

# 3. Configure IRIS (from repo root)
cd /Users/aryand/Desktop/ansible-iris-automation
ansible-playbook playbooks/configure.yml -i inventories/poc
```

Wait until `irisa`, `irisb`, gateways, and arbiter report healthy before configure.

---

## License key

- Required for full interop/production features — see [licensed-image-setup.md](licensed-image-setup.md).
- **Never commit** `iris.key` — git-ignored.
- Both IRIS containers mount their own copy under `/iris-shared/iris.key`.

Symptom if missing:

```text
No such file or directory: /iris-shared/iris.key
```

---

## Web Gateway CSP config

Gateways need `CSP.ini` / `CSP.conf` pointing at IRIS superserver port **1972**
with `CSPSystem` credentials. Stale `webgateway*/durable` directories can break
first boot — the README troubleshooting section covers reset steps.

Portal URLs must use **`.csp`**:

```text
http://localhost:8081/csp/sys/UtilHome.csp
http://localhost:8082/csp/sys/UtilHome.csp
```

---

## Ansible execution model

| Variable | POC value | Meaning |
| -------- | --------- | ------- |
| `iris_exec_mode` | `docker` | Ansible uses `docker cp` / `docker exec` on each container |
| `ansible_connection` | `local` | Control node talks to localhost; IRIS reached via Docker |
| `stage_dir` | `/tmp/iris_automation` | Rendered scripts/CPF staged here before push |

For bare-metal IRIS, set `iris_exec_mode: direct` and connect Ansible to the host via SSH.

---

## Tear down / reset

Stop without deleting data:

```bash
cd iris-env/IRISSystemManagement
docker compose stop
```

Full reset (deletes durable data — primary role may change after failover):

```bash
docker compose down -v --remove-orphans
# remove irisa/, irisb/, webgateway*/durable per README.md
```

---

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| Container restart loop | `docker logs irisa` / `irisb` — often missing key |
| Gateway 502/404 | Check CSP.ini; use `UtilHome.csp` not `.cs` |
| Ansible locale 1252 | Run from WSL/Ubuntu or UTF-8 shell |
| Port already in use | `docker compose ps`; stop conflicting services |

More: [failure-modes.md](failure-modes.md) · [ansible-runbook.md §8](ansible-runbook.md#8-troubleshooting)
