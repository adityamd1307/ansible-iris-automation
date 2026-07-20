# HA & mirroring considerations (Topic 2)

## Assignment rule

> Do **not** mix sharding and mirroring in the first POC.

This repo honours that rule:

| Stack | Mirroring | Sharding |
| ----- | --------- | -------- |
| `iris-env/IRISSystemManagement` (Topic 1) | Yes | No |
| `iris-env/IRISShardCluster` (Topic 2) | No | Yes (data nodes only) |

Both stacks can run concurrently on one machine (different subnets/ports).

## Mirrored sharding (future layer)

`%SYSTEM.Cluster` supports **mirrored data nodes** via:

- `InitializeMirrored()` on node 1
- `AttachAsMirroredNode()` for paired failover members

That mode is **documented only** in
[combined-future-architecture.md](../../architecture/combined-future-architecture.md).
Do not enable it in the Topic 2 POC playbooks without a dedicated design pass.

## HA dimensions

| Concern | Non-mirrored sharding POC | Mirrored sharded cluster (future) |
| ------- | ------------------------- | --------------------------------- |
| Node failure | Shard unavailable until ops intervention | Failover within mirror pair |
| Data durability | Single copy per shard | Mirrored journal on pair |
| Split brain | Not applicable (no mirror) | Arbiter + mirror rules |
| Security (`IRISSECURITY`) | Per-node like Topic 1 | Same mirror gap — automation required |

## Interaction with Topic 1 patterns

Topic 1 teaches:

- Mirror replicates **data databases**, not security/interop
- Ansible closes gaps with guarded ObjectScript on every node

Mirrored sharding inherits those gaps **per mirror pair**. A combined
future playbook tree would need:

1. `%SYSTEM.Cluster.InitializeMirrored` / `AttachAsMirroredNode`
2. Mirror-aware validation (primary vs backup roles per pair)
3. Security sync per pair or cluster-wide strategy (TBD with InterSystems guidance)

## Recommendation for demos

Present Topic 2 as **scale-out partitioning**, not **failover**:

- "Three data nodes, three shards, one cluster namespace"
- "Mirroring and sharding solve different problems; we prove each separately"
- "Production health IT likely needs mirrored sharded data nodes — out of POC scope"

See [recommendation.md](recommendation.md) for health IT-specific guidance.
