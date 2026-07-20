# Infrastructure readiness checklist (§5.2)

Complete before `stack_up.yml` or production-style deployment.

## Hosts & containers

| # | Item | POC (Docker) | Real deployment |
| - | ---- | ------------ | --------------- |
| 1 | One IRIS instance per data node | `shard_data1..3` containers | Separate VMs/bare metal |
| 2 | Unique hostname / IP per node | 172.29.0.10–12 | DNS + static IP |
| 3 | Sufficient CPU/RAM per node | Docker Desktop limits | Size per InterSystems guidance |
| 4 | Disk for shard + journal growth | Bind mounts under `IRISShardCluster/` | Dedicated data volumes |

## Network

| # | Item | Verify |
| - | ---- | ------ |
| 5 | Superserver (1972) reachable node-to-node | `docker exec shard_data2 ping shard_data1` |
| 6 | ECP ports allowed between all cluster members | Same subnet / firewall rules |
| 7 | `cluster_allowed_connections` matches reality | `inventories/sharding/group_vars/all.yml` |
| 8 | `pHostIPAddress` / `shard_host_ip` correct when NAT/DNS ambiguous | Docker: use 172.29.0.x |

## IRIS configuration

| # | Item | Automation |
| - | ---- | ---------- |
| 9 | `MaxServers` ≥ data node count (+ compute if used) | `cpf/sharding/cluster-template.cpf.j2` |
| 10 | `MaxServerConn` ≥ anticipated interconnects | Same CPF template |
| 11 | ECP service enabled | CPF `[Services] %Service_ECP` |
| 12 | Instances **not** mirror members before Initialize | Fresh stack or detach |
| 13 | Sharding license active | [version-license-gate.md](version-license-gate.md) |

## Secrets & files

| # | Item | Location |
| - | ---- | -------- |
| 14 | `iris.key` on every node | `shard_data*/iris.key` (git-ignored) |
| 15 | `.env` with `IRISTAG` | `iris-env/IRISShardCluster/.env` |
| 16 | No secrets in git | `.gitignore` covers keys + runtime dirs |

## Ansible control node

| # | Item | Command |
| - | ---- | ------- |
| 17 | Docker + compose available | `docker compose version` |
| 18 | Ansible can run playbooks | `ansible-playbook --version` |
| 19 | Inventory isolated from Topic 1 | `-i inventories/sharding` |
| 20 | Gate flag understood | `sharding_hands_on_enabled` |

## Post-build verification

| # | Item | Playbook |
| - | ---- | -------- |
| 21 | All nodes cluster members | `validate_sharding.yml` |
| 22 | Data node count matches desired | `SHARDING_JSON.data_node_count` |
| 23 | Demo sharded table present (optional) | `create_sharded_namespace.yml` |

When any item fails, record in evidence and consult
[failure-modes-sharding.md](failure-modes-sharding.md).
