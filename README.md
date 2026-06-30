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

From the repository root:

```bash
ansible-playbook playbooks/prepare.yml -e iris_key_source=/path/to/iris.key
ansible-playbook playbooks/stack_up.yml
ansible-playbook playbooks/verify.yml
```

Or run the full flow:

```bash
ansible-playbook playbooks/site.yml -e iris_key_source=/path/to/iris.key
```

To stop the stack:

```bash
ansible-playbook playbooks/stack_down.yml
```

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

## What To Automate Next

Good next steps are:

- add CPF files under `cpf/` and mount or apply them during startup
- add ObjectScript deployment under `objectscript/`
- add Ansible roles once the playbooks grow beyond this starter shape
- add evidence collection tasks under `evidence/` for repeatable validation
