# Workload suitability checklist (§5.2)

Use before proposing sharding for a health IT (or any) workload. Score each
row: **Y** = yes, **N** = no, **?** = needs analysis.

## Data characteristics

| # | Question | Y / N / ? | Notes |
| - | -------- | --------- | ----- |
| 1 | Largest tables expected to exceed comfortable single-node storage? | | |
| 2 | Identified **shard key** with high cardinality (e.g. MRN, encounter ID)? | | |
| 3 | Shard key stable over row lifetime (not frequently updated)? | | |
| 4 | Majority of queries filter on shard key or single-shard scope? | | |
| 5 | Cross-shard joins rare or acceptable at higher latency? | | |

## Access patterns

| # | Question | Y / N / ? | Notes |
| - | -------- | --------- | ----- |
| 6 | Write path can target correct shard (key known at insert)? | | |
| 7 | Reporting can use shard-key-aligned aggregates or federated pattern? | | |
| 8 | Batch jobs partitionable by shard key? | | |
| 9 | Need extreme read scaling → compute nodes justified later? | | |

## Operational fit

| # | Question | Y / N / ? | Notes |
| - | -------- | --------- | ----- |
| 10 | Team can operate multi-node cluster (ECP, adds, rebalances)? | | |
| 11 | License covers sharding + enough data nodes? | | See [version-license-gate.md](version-license-gate.md) |
| 12 | HA requirements understood separately from sharding? | | See [ha-mirroring-considerations.md](ha-mirroring-considerations.md) |
| 13 | Migration path from non-sharded DB defined? | | |
| 14 | Rollback / detach strategy documented? | | |

## Scoring guide

| Result | Recommendation |
| ------ | -------------- |
| Mostly **Y** on rows 1–8 | Strong sharding candidate — proceed to infra checklist |
| Mixed with critical **N** on 2, 4, 6 | Redesign shard key or query pattern first |
| **N** on 1 | Sharding likely premature — scale vertically / optimize |
| Mostly **N** | Do **not** shard; document decision in [recommendation.md](recommendation.md) |

## POC demo table alignment

This repo's demo uses `ShardDemo.Patient` with **`SHARD KEY (MRN)`** —
typical for patient-centric health records **if** queries are MRN-scoped.
It is illustrative, not a production schema sign-off.
