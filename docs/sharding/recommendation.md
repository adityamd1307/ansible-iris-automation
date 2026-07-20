# Sharding recommendation — health IT use case

## Executive summary

**Sharding is suitable** for health IT workloads that have very large,
patient- or encounter-keyed datasets and queries that primarily scope to
that key. It is **not a substitute** for mirror-based HA on a single
application database.

For this assignment POC we prove **non-mirrored data-node clustering**
in isolation. Production health IT should plan **mirrored sharded data
nodes** as a later phase ([ha-mirroring-considerations.md](ha-mirroring-considerations.md)).

## Fit for typical clinical data

| Pattern | Sharding fit | Rationale |
| ------- | ------------ | --------- |
| Patient demographics / facts keyed by MRN | Good | Stable high-cardinality shard key |
| Encounter lines keyed by encounter ID | Good | Aligns queries to single shard |
| Global cross-patient analytics | Moderate | May need compute nodes + careful SQL |
| Small reference / lookup tables | Poor | Keep nonsharded in master namespace |
| Interoperability message stores | Case-by-case | Volume + key design matter |

The repo demo (`ShardDemo.Patient`, `SHARD KEY (MRN)`) models the **good**
case — not a full EMR schema.

## Risks

| Risk | Mitigation |
| ---- | ---------- |
| Wrong shard key choice | [workload-suitability-checklist.md](workload-suitability-checklist.md) before build |
| Cross-shard query latency | Query review; compute nodes for read scale |
| Operational complexity | Runbooks, `%SYSTEM.Cluster.ListNodes()` monitoring |
| License cost | Early [version-license-gate.md](version-license-gate.md) |
| Security not replicated | Per-node security automation (Topic 1 pattern) |
| Combined mirror + shard cutover | Phased: mirror POC → shard POC → combined design |

## Comparison to Topic 1 mirror

| Capability | Topic 1 mirror | Topic 2 sharding |
| ---------- | -------------- | ---------------- |
| Primary goal | HA / failover | Horizontal scale |
| Nodes | 2 + arbiter | 3+ data nodes |
| User sees | One app namespace | One cluster namespace |
| This repo status | Hands-on POC | Hands-on if licensed; else concept |

## Recommended next steps

1. **Complete gate** — confirm sharding license on target IRIS version
2. **Run POC** — [operational-runbook.md](operational-runbook.md)
3. **Workload workshop** — fill suitability checklist with real tables/keys
4. **Sizing** — data node count from growth model (not "3 because demo")
5. **Design mirrored sharding** — [combined-future-architecture.md](../../architecture/combined-future-architecture.md)
6. **Security model** — extend Topic 1 sync pattern for N nodes or per pair
7. **Compute nodes** — evaluate after baseline cluster stable (stretch in compose)

## Decision

| If… | Then… |
| --- | ----- |
| Largest tables fit one node 2+ years | Defer sharding; optimize + mirror |
| Shard-key-aligned access dominates | Proceed to infra checklist + POC |
| License unavailable | Deliver concept package (this repo default gate) |
| HA required day one | Plan mirrored sharding, not POC topology alone |

This recommendation satisfies deliverable §5.2 even when hands-on steps
are blocked — automation and documentation remain the engineering artifact.
