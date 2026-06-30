# ansible-iris-automation
# IRIS Automation Starter

This repository contains an Ansible wrapper around the existing `docker-compose.yml` topology:
- Two IRIS containers: `irisa`, `irisb`
- Two Web Gateways: `webgatewaya`, `webgatewayb`
- One Arbiter node
- One HAProxy load balancer / entry point

The starter keeps Docker Compose as the runtime source of truth and uses Ansible for repeatable setup, start, stop, configuration, and verification steps.

---

## ⚠️ Critical WSL / Windows Architecture Requirements

If you are running this stack inside **WSL (Windows Subsystem for Linux)**, you must adhere to the following architecture rules to prevent permissions and container runtime failures:

1. **Native Linux Filesystem Only (`~/`)**
   Do **NOT** clone or move this repository into a mounted Windows directory (e.g., `/mnt/c/Users/...`). 
   - Windows filesystems mounted via WSL default to world-writable permissions (`777`), which breaks standard POSIX security.
   - Ansible will ignore configurations or error out due to world-writable security policies.
   - Python filesystem operations (such as creating an `ansible-vault` file) will crash with `Operation not permitted` errors.
   - **Fix:** Always keep this directory inside your home space (e.g., `~/iris-automation`).

2. **Docker Named Volume Ownership (UID 51773)**
   By default, Docker Desktop initializes brand-new named volumes under `root:root` ownership. Because the InterSystems IRIS containers drop root privileges and execute as the `irisowner` user account (UID `51773`), the engine will crash on startup with a target directory non-writeable error.
   - **Fix:** If you drop the volumes (`docker compose down -v`), you must repair their internal ownership tracking before launching the containers:
     ```bash
     docker run --rm \
       -v iris-automation_irisa_durable:/vol1 \
       -v iris-automation_irisb_durable:/vol2 \
       -v iris-automation_arbiter_durable:/vol3 \
       -v iris-automation_webgatewaya_durable:/vol4 \
       -v iris-automation_webgatewayb_durable:/vol5 \
       alpine chown -R 51773:51773 /vol1 /vol2 /vol3 /vol4 /vol5
     ```

3. **Docker Engine Binding Caches**
   If you clean-delete project folders manually inside WSL, Docker Desktop's host mount manager can lose track of local file index structures, throwing OCI runtime errors (`no such file or directory` or mount binding failures).
   - **Fix:** Run a clean `docker compose down -v --remove-orphans` and restart the Docker Desktop system tray engine to flush the host bind-mount caches.

---

## Prerequisites

- Docker with the `docker compose` plugin
- Ansible available in your shell environment.
- Access to the InterSystems container images configured in `group_vars/all.yml`
- An InterSystems IRIS license key

---

## Deployment & Verification

### First Run Flow
From the repository root directory, provide the **absolute path** to your `iris.key` file (you can use `$PWD` to generate it automatically):

```bash
ansible-playbook -i inventories/poc/hosts.yml playbooks/site.yml -e iris_key_source=$PWD/iris.key