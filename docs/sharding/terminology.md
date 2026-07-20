# Terminology (Topic 2 — modern cluster API)

Use these terms in docs, playbooks, and demos. Legacy names appear only
where mapping to old `%SYSTEM.Sharding` docs is required.

## Core terms

| Term | Definition |
| ---- | ---------- |
| **Sharded cluster** | Interconnected IRIS instances providing horizontal scale |
| **Data node** | Stores a **shard** (partition) of sharded data locally |
| **Node 1** | First data node; runs `Initialize()`; hosts **master namespace** |
| **Compute node** | No local shard data; maps to a data node's shard for query compute (stretch) |
| **Cluster namespace** | Same name on every node; apps/SQL connect here (`SHARDCLUSTER` in POC) |
| **Master namespace** | Exists **only on node 1**; holds nonsharded metadata + code (`SHARDMASTER`) |
| **Shard database** | Per-data-node DB holding that node's shard partition |
| **Cluster URL** | `IRIS://host:port/cluster-namespace` — used by `AttachAsDataNode()` |

## Namespace rules (from `%SYSTEM.Cluster`)

- **User access** should use the **cluster namespace** on any node.
- **Master namespace** is for admin/metadata: mappings defined there propagate to all cluster namespaces.
- Do not define user mappings only on one node's cluster namespace — they won't propagate.

## Legacy mapping (do not use in new automation)

| Legacy (namespace-level / old docs) | Modern equivalent |
| ----------------------------------- | ----------------- |
| Shard master | Node 1 + master namespace |
| Shard server / shard data server | Data node |
| Query server | Compute node |
| `%SYSTEM.Sharding` namespace API | **`%SYSTEM.Cluster`** for deployment |

This repo's ObjectScript uses **`$SYSTEM.Cluster.*` only** for cluster
formation. Demo table creation uses SQL `SHARD KEY` in the cluster namespace.

## Inventory host names (POC)

| Host | Role | API call |
| ---- | ---- | -------- |
| `shard_data1` | Node 1 | `Initialize()` |
| `shard_data2` | Data node 2 | `AttachAsDataNode()` |
| `shard_data3` | Data node 3 | `AttachAsDataNode()` |

Ansible groups:

- `shard_node1` — initialize play (serial first)
- `shard_data_nodes` — attach targets
- `shard_nodes` — all data nodes (validation)

Never reuse Topic 1 groups `iris_primary` / `iris_backup` for sharding.
