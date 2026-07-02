# ansible-iris-automation
# IRIS Automation Starter

This repository contains a small Ansible wrapper around the existing
`docker-compose.yml` topology:

- two IRIS containers: `irisa`, `irisb`
- two web gateways: `webgatewaya`, `webgatewayb`
- one arbiter
- one HAProxy entry point

The starter keeps Docker Compose as the runtime source of truth and uses
Ansible for repeatable setup, start, stop, and verification steps.

## Prerequisites

- Docker with the `docker compose` plugin
- Ansible available in your shell. On Windows, WSL/Ubuntu is usually the
  smoothest control-node environment for Ansible.
- Access to the InterSystems container images configured in
  `group_vars/all.yml`
- An IRIS license key if your selected IRIS image requires one

## First Run

From the repository root. Pick an environment inventory with `-i`
(`inventories/poc` for the local docker topology):

```bash
ansible-playbook playbooks/prepare.yml  -i inventories/poc -e iris_key_source=/path/to/iris.key
ansible-playbook playbooks/stack_up.yml -i inventories/poc
ansible-playbook playbooks/verify.yml   -i inventories/poc
ansible-playbook playbooks/configure.yml -i inventories/poc
```

Or run the full end-to-end flow (infra bring-up **and** IRIS configuration):

```bash
ansible-playbook playbooks/site.yml -i inventories/poc -e iris_key_source=/path/to/iris.key
```

To stop the stack:

```bash
ansible-playbook playbooks/stack_down.yml -i inventories/poc
```

## Configuration flow (Topic 1)

`playbooks/configure.yml` converges each IRIS node to the declarative
desired state in `inventories/<env>/group_vars/all.yml`, in order:

1. `setup_databases.yml`  - physical databases via **CPF merge**
2. `create_namespace.yml` - namespace + mappings via **CPF merge**
3. `setup_webapp.yml`     - CSP web app via guarded **ObjectScript**
4. `setup_security.yml`   - services (CPF) + roles/password (guarded ObjectScript)
5. `setup_production.yml` - interop production auto-start (guarded ObjectScript)
6. `validate_nodes.yml`   - read-only node readiness incl. production (asserts + JSON)
7. `validate_mirror.yml`  - read-only mirror readiness (arbiter + journaling)

Everything is idempotent and parameterized. Switch environments by
changing `-i inventories/dev|sit|uat` - no code changes.

## Documentation

- `architecture/ansible-iris-architecture.md` - architecture diagram (Mermaid)
- `docs/mechanism-mapping.md` - per-item CPF vs ObjectScript vs REST table
- `docs/ansible-runbook.md` - set up, run, verify, troubleshoot, extend
- `docs/failure-modes.md` - partial-failure behavior and recovery
- `docs/secrets-and-security.md` - vault, license key, `no_log`, cleanup
- `docs/demo-script.md` - step-by-step POC demo
- `examples/desired-state.example.yml` - desired-state template

## Useful Overrides

The defaults live in `group_vars/all.yml`. You can override them from the
command line:

```bash
ansible-playbook playbooks/site.yml \
  -e iris_image=containers.intersystems.com/intersystems/iris:latest-em \
  -e webgateway_image=containers.intersystems.com/intersystems/webgateway:latest-em \
  -e iris_key_source=/path/to/iris.key
```

If you are using an image that does not require `iris.key`, run:

```bash
ansible-playbook playbooks/site.yml -e require_iris_key=false
```

## Windows Note

If native PowerShell reports `Ansible requires the locale encoding to be
UTF-8; Detected 1252`, run the playbooks from WSL/Ubuntu or another UTF-8
shell. The playbooks still manage the Docker Compose stack in this repository;
the issue is the local Ansible runtime encoding.

## Published Local Ports

- IRIS A superserver: `localhost:51773`
- IRIS A web: `http://localhost:52773`
- IRIS B superserver: `localhost:61773`
- IRIS B web: `http://localhost:62773`
- Web Gateway A: `http://localhost:8081`
- Web Gateway B: `http://localhost:8082`
- HAProxy: `http://localhost:8080`

## Secrets

No secrets are committed. The IRIS license key and all passwords are kept
out of git and out of logs. See `docs/secrets-and-security.md`. In short:

- License key: `-e iris_key_source=/secure/path/iris.key` (copied with
  `no_log`, git-ignored).
- Passwords: `group_vars/vault.yml` (ansible-vault encrypted, git-ignored).
  Template: `group_vars/vault.example.yml`.

## What To Automate Next

Good next steps are:

- convert the flat playbooks into Ansible roles as they grow
- build an actual mirror (this POC validates mirror *readiness*)
- add CI to lint playbooks (`ansible-lint`) and run `--check` dry runs
