# ansible-iris-automation

Local Docker + Ansible automation for an InterSystems IRIS mirror lab.

**Full documentation index:** [docs/README.md](docs/README.md)

The desired steady state is:

- `irisa` = mirror primary
- `irisb` = mirror backup / fallback
- `arbiter` = mirror arbiter
- `webgatewaya` = Web Gateway for `irisa`, exposed on `localhost:8081`
- `webgatewayb` = Web Gateway for `irisb`, exposed on `localhost:8082`
- `haproxy` = front door, exposed on `localhost:8080`

The Docker runtime lives under:

```powershell
C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement
```

Ansible configuration lives in the normal repo folders:

```text
playbooks/
roles/
inventories/
objectscript/
cpf/
docs/
```

## Security (mirror gap)

IRIS mirroring replicates **data databases**, not **IRISSECURITY**. This
repo applies security in three layers: `%DB_*` resources during database
setup, bootstrap roles/services on every node (`setup_security.yml`), then
primary→backup sync (`sync_security.yml`).

**Guide:** [docs/security-overview.md](docs/security-overview.md)

## Topic documentation

| Area | Guide |
| ---- | ----- |
| Infrastructure & Docker | [docs/infra-overview.md](docs/infra-overview.md) |
| Databases | [docs/databases-overview.md](docs/databases-overview.md) |
| Namespace | [docs/namespace-overview.md](docs/namespace-overview.md) |
| Web applications | [docs/webapp-overview.md](docs/webapp-overview.md) |
| Security & sync | [docs/security-overview.md](docs/security-overview.md) |
| Mirror | [docs/mirror-overview.md](docs/mirror-overview.md) |
| Production | [docs/production-overview.md](docs/production-overview.md) |
| HAProxy routing | [docs/routing-overview.md](docs/routing-overview.md) |
| Validation | [docs/validation-overview.md](docs/validation-overview.md) |

Quick sync after configure:

```bash
ansible-playbook playbooks/sync_security.yml -i inventories/poc \
  -e security_sync_enabled=true -e security_sync_dry_run=false
```

Portal URLs must use **`.csp`** (e.g. `http://localhost:8081/csp/sys/UtilHome.csp`).

## Prerequisites

- Docker Desktop with Compose
- WSL/Ubuntu with Ansible installed
- Access to the InterSystems container images in `.env`
- A valid `iris.key`

The playbooks are normally launched from PowerShell using `wsl.exe`.

## 1. Put the IRIS license key in place

Put your license file at the repo root first:

```text
C:\Users\adhaded\Desktop\ansible-iris-automation\iris.key
```

Then copy it into both IRIS runtime folders:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation

$base = ".\iris-env\IRISSystemManagement"
New-Item -ItemType Directory -Force "$base\irisa", "$base\irisb" | Out-Null
Copy-Item .\iris.key "$base\irisa\iris.key" -Force
Copy-Item .\iris.key "$base\irisb\iris.key" -Force
```

Optional but recommended after copying:

```powershell
Remove-Item .\iris.key -Force
```

The runtime copies are ignored by Git.

## 2. Start Docker

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement

docker compose config --quiet
docker compose up -d --pull missing
docker compose ps
```

Wait until the main containers are healthy:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected:

```text
irisa         Up ... (healthy)
irisb         Up ... (healthy)
arbiter       Up ... (healthy)
webgatewaya   Up ... (healthy)
webgatewayb   Up ... (healthy)
haproxy       Up ...
```

## 3. Run the full configuration

From PowerShell:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation

wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/configure.yml"
```

`configure.yml` runs the full sequence:

1. `setup_databases.yml`
2. `setup_mirror.yml`
3. `create_namespace.yml`
4. `setup_webapp.yml`
5. `setup_security.yml`
6. `setup_production_import.yml`
7. `setup_mirror.yml` again, idempotently, to finalize backup/failover membership
8. `setup_production_autostart.yml`
9. `validate_nodes.yml`
10. `validate_mirror.yml`
11. `sync_security.yml`

Expected recap:

```text
failed=0
```

## 4. Run playbooks one by one

Use this when debugging or proving each layer independently.

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation
```

Database setup:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_databases.yml"
```

Mirror setup:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_mirror.yml"
```

Namespace setup:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/create_namespace.yml"
```

Web app setup:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_webapp.yml"
```

Security setup:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_security.yml"
```

Production class import:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_production_import.yml"
```

Run mirror setup again to finalize membership after app objects exist:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_mirror.yml"
```

Production autostart:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/setup_production_autostart.yml"
```

Validation:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/validate_nodes.yml"

wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/validate_mirror.yml"

wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/sync_security.yml"
```

## 5. Verify Management Portal access

After Docker and Ansible are green:

```powershell
Invoke-WebRequest http://localhost:8081/csp/sys/UtilHome.csp -UseBasicParsing
Invoke-WebRequest http://localhost:8082/csp/sys/UtilHome.csp -UseBasicParsing
Invoke-WebRequest http://localhost:8080/csp/sys/UtilHome.csp -UseBasicParsing
```

Expected HTTP status:

```text
200 OK
```

Browser URLs:

```text
IRIS A via Web Gateway:  http://localhost:8081/csp/sys/UtilHome.csp
IRIS B via Web Gateway:  http://localhost:8082/csp/sys/UtilHome.csp
HAProxy:                 http://localhost:8080/csp/sys/UtilHome.csp
Direct IRIS A:           http://localhost:52773/csp/sys/UtilHome.csp
Direct IRIS B:           http://localhost:62773/csp/sys/UtilHome.csp
```

## 6. Verify mirror roles

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/validate_mirror.yml"
```

Expected:

```text
irisa is_primary: true
irisb is_backup: true
```

## 7. Verify production readiness

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/validate_nodes.yml"
```

Expected:

```text
irisa production_running: true
irisb production_configured: true
```

`irisb` should normally have production configured but not running while it is backup.

## 8. Failover test

Kill the primary:

```powershell
docker kill irisa
```

Wait 30-60 seconds, then verify failover production:

```powershell
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/validate_failover_production.yml"
```

Expected after failover:

```text
irisb is primary
TRAINING.Production is running on irisb
```

Bring `irisa` back:

```powershell
docker start irisa
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Important: after failover, IRIS does not automatically make `irisa` primary again. If you want the normal lab state back, either perform a controlled failback in IRIS or reset the Docker state from scratch.

## 9. Clean reset from scratch

This deletes runtime data under `iris-env\IRISSystemManagement`. Use it when you want `irisa` to become primary again from a fresh environment.

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement

docker compose down -v --remove-orphans
```

Remove runtime folders:

```powershell
$base = "C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement"
Remove-Item -Recurse -Force "$base\irisa", "$base\irisb", "$base\arbiter", "$base\webgatewaya\durable", "$base\webgatewayb\durable" -ErrorAction SilentlyContinue
```

Recreate license placement:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation

$base = ".\iris-env\IRISSystemManagement"
New-Item -ItemType Directory -Force "$base\irisa", "$base\irisb" | Out-Null
Copy-Item .\iris.key "$base\irisa\iris.key" -Force
Copy-Item .\iris.key "$base\irisb\iris.key" -Force
```

Start and configure again:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement
docker compose up -d --pull missing

cd C:\Users\adhaded\Desktop\ansible-iris-automation
wsl.exe -e sh -lc "cd /mnt/c/Users/adhaded/Desktop/ansible-iris-automation && ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventories/poc playbooks/configure.yml"
```

## 10. Stop and start without deleting data

Stop:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement
docker compose stop
```

Start:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement
docker compose up -d
```

## 11. Troubleshooting

Check all containers:

```powershell
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Check logs:

```powershell
docker logs --tail 120 irisa
docker logs --tail 120 irisb
docker logs --tail 120 webgatewaya
docker logs --tail 120 webgatewayb
docker logs --tail 120 haproxy
```

If `irisa` or `irisb` restarts with missing key:

```text
No such file or directory: /iris-shared/iris.key
```

copy `iris.key` into:

```text
iris-env\IRISSystemManagement\irisa\iris.key
iris-env\IRISSystemManagement\irisb\iris.key
```

If `webgatewaya` or `webgatewayb` restarts, make sure these files exist:

```text
iris-env\IRISSystemManagement\webgatewaya\CSP.ini
iris-env\IRISSystemManagement\webgatewaya\CSP.conf
iris-env\IRISSystemManagement\webgatewayb\CSP.ini
iris-env\IRISSystemManagement\webgatewayb\CSP.conf
```

The working `CSP.conf` uses:

```apache
LoadModule csp_module_sa /opt/webgateway/bin/CSPa24.so
```

If Docker accidentally created `CSP.ini` or `CSP.conf` as directories, stop the gateways, delete those directories, restore the files, and restart:

```powershell
cd C:\Users\adhaded\Desktop\ansible-iris-automation\iris-env\IRISSystemManagement

docker compose stop webgatewaya webgatewayb haproxy
Remove-Item -Recurse -Force .\webgatewaya\CSP.ini, .\webgatewaya\CSP.conf, .\webgatewayb\CSP.ini, .\webgatewayb\CSP.conf -ErrorAction SilentlyContinue
git checkout -- .\webgatewaya\CSP.ini .\webgatewaya\CSP.conf .\webgatewayb\CSP.ini .\webgatewayb\CSP.conf
Remove-Item -Recurse -Force .\webgatewaya\durable, .\webgatewayb\durable -ErrorAction SilentlyContinue
docker compose up -d webgatewaya webgatewayb haproxy
```

## Useful ports

```text
51773  irisa superserver
52773  irisa native web
61773  irisb superserver
62773  irisb native web
8081   webgatewaya
8082   webgatewayb
8080   haproxy
21881  irisa ISCAgent mirror port
21882  irisb ISCAgent mirror port
21883  arbiter
```

## Topic 2 — Sharding (separate from mirror POC)

Horizontal sharding uses its **own** Docker stack, inventory, and playbooks.
Topic 1 `configure.yml` is unchanged.

| Area | Guide |
| ---- | ----- |
| Sharding index + gate | [docs/sharding/README.md](docs/sharding/README.md) |
| Architecture | [architecture/sharding-architecture.md](architecture/sharding-architecture.md) |
| Operational runbook | [docs/sharding/operational-runbook.md](docs/sharding/operational-runbook.md) |

Quick start (after [version-license-gate.md](docs/sharding/version-license-gate.md)):

```bash
ansible-playbook playbooks/sharding/site.yml -i inventories/sharding \
  -e iris_key_source=/path/to/iris.key \
  -e sharding_hands_on_enabled=true
```

Default inventory remains Topic 1 POC (`inventories/poc`). Always pass
`-i inventories/sharding` for sharding work.
