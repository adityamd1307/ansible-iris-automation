# Ansible + IRIS Architecture (Topic 1 POC)

Deliverable 5.1 #1. This diagram is kept as text (Mermaid) so it is
version-control friendly and reviewable in a PR. Export to
`ansible-iris-architecture.png` for the slide/handover pack (GitHub/most
IDEs render Mermaid; or use the Mermaid CLI / mermaid.live).

## Control + data flow

```mermaid
flowchart TB
  subgraph CTRL["Ansible Controller (control node)"]
    A["ansible-playbook\nplaybooks/configure.yml"]
    INV["inventories/&lt;env&gt;\nhosts.yml + group_vars"]
    V["group_vars/vault.yml\n(ansible-vault, git-ignored)"]
    CPF["cpf/*.j2 (CPF merge)"]
    OS["objectscript/*.cos.j2 (guarded)"]
    A --- INV
    A --- V
    A --- CPF
    A --- OS
  end

  subgraph NET["Container network (172.28.0.0/16)"]
    direction TB
    subgraph NA["Node A - PRIMARY (irisa)"]
      IA["IRIS instance\nnamespace + DBs + web app\n+ roles + production auto-start"]
    end
    subgraph NB["Node B - BACKUP (irisb)"]
      IB["IRIS instance\nsame config applied by automation"]
    end
    ARB["Arbiter"]
    WGA["Web Gateway A"]
    WGB["Web Gateway B"]
    HAP["HAProxy (VIP / entrypoint :8080)"]
  end

  A -- "docker exec / cp (POC)\nor SSH key auth (DEV/SIT/UAT)" --> IA
  A -- "docker exec / cp\nor SSH key auth" --> IB

  IA <-. "mirror: data DBs replicate\n(NOT security/interop)" .-> IB
  IA -. heartbeat .-> ARB
  IB -. heartbeat .-> ARB

  HAP --> WGA --> IA
  HAP --> WGB --> IB
  USER["Client / Portal"] --> HAP
```

## Why automation is needed (the mirror gap)

```mermaid
flowchart LR
  subgraph MIRRORED["Replicated by mirroring"]
    D1["Mirrored database data\n(TRAININGDATA / TRAININGCODE)"]
  end
  subgraph NOTMIRRORED["NOT replicated - applied by Ansible to every node"]
    N1["Namespace + mappings"]
    N2["Web applications"]
    N3["Roles / resources (IRISSECURITY)"]
    N4["Interop production auto-start"]
  end
  D1 --> READY["Promoted backup is\nAPPLICATION-READY"]
  N1 --> READY
  N2 --> READY
  N3 --> READY
  N4 --> READY
```

## Access / execution method

| Environment | Connection | IRIS command execution |
| ----------- | ---------- | ---------------------- |
| POC | `ansible_connection: local` | `docker cp` + `docker exec <container> iris ...` (`iris_exec_mode: docker`) |
| DEV / SIT / UAT | SSH key auth to hosts | `iris merge` / `iris session` directly on PATH (`iris_exec_mode: direct`) |

Secrets never leave the vault/`no_log` boundary; license keys and
passwords are never committed (see `docs/secrets-and-security.md`).
