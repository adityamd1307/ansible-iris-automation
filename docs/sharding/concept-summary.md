# Sharding concept summary (Topic 2)

## What

**Sharding** horizontally partitions large datasets across multiple IRIS
**data nodes** while presenting a single **cluster namespace** to
applications. Users and SQL see one logical database; the platform routes
rows to shards by a **shard key**.

This repo implements **non-mirrored, data-node-only** cluster formation
using **`%SYSTEM.Cluster`** — the modern cluster-level API. Topic 1
mirroring is intentionally **not** mixed into the first POC.

## Why

| Driver | Sharding response |
| ------ | ----------------- |
| Dataset growth beyond one server | Spread sharded tables across N data nodes |
| Query throughput | Add **compute nodes** (stretch) for read-heavy SQL |
| Operational scale-out | Add data nodes to increase partition count |

Sharding complements — does not replace — mirroring. Mirroring protects
**one** node's availability; sharding spreads **data volume and query load**.

## When to use

Good candidates (see [workload-suitability-checklist.md](workload-suitability-checklist.md)):

- Large fact tables with a stable, high-cardinality **shard key** (e.g. patient MRN, account ID)
- Mostly key-based or shard-key-aligned queries
- Batch ETL that can target shard keys explicitly
- Read-heavy analytics after baseline cluster proves stable (compute nodes)

## When not to use

- Small databases that fit one node comfortably
- Workloads dominated by cross-shard joins or aggregates without shard-key filter
- Replacing mirror HA for a single database (use Topic 1 mirror first)
- First production cut combining **mirrored sharding + app migration** in one phase

## How this repo approaches it

```text
CPF merge (ECP prerequisites)
    → %SYSTEM.Cluster.Initialize (node 1)
    → %SYSTEM.Cluster.AttachAsDataNode (nodes 2..N)
    → SQL CREATE TABLE ... SHARD KEY (demo)
    → validate_sharding.yml (SHARDING_JSON)
```

Separation of concerns:

| Layer | Location |
| ----- | -------- |
| Docker stack | `iris-env/IRISShardCluster/` |
| Inventory | `inventories/sharding/` |
| Playbooks | `playbooks/sharding/` |
| Topic 1 mirror | Unchanged under `playbooks/configure.yml` |

## Relationship to Topic 1

Topic 1 proves **mirror failover** for a two-node app stack.
Topic 2 proves **horizontal data partitioning** across three data nodes.
A future combined architecture (mirrored data nodes + sharding) is
documented only conceptually in
[combined-future-architecture.md](../../architecture/combined-future-architecture.md).
