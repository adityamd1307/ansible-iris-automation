# Sharding demo script (presenter walkthrough)

15–20 minute flow. Adjust if license gate blocks hands-on — skip to
**Concept-only path** below.

## Setup (before audience)

1. Complete [version-license-gate.md](version-license-gate.md)
2. `stack_up.yml` + `configure_sharding.yml` green
3. Terminal ready with repo root as cwd

## Narrative arc

1. **Problem** — single-node limits for large patient datasets
2. **Approach** — cluster namespace + data nodes + shard key
3. **Separation** — Topic 1 mirror ≠ Topic 2 sharding
4. **Automation** — CPF for ECP, `%SYSTEM.Cluster` for topology, JSON validation
5. **Recommendation** — health IT suitability ([recommendation.md](recommendation.md))

---

## Live demo steps

### 1. Show separate stack (2 min)

```bash
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E 'shard_data|irisa'
```

**Say:** "Mirror lab is Topic 1 (`irisa`/`irisb`). Sharding lab is three
independent data nodes — no arbiter, no mirror."

### 2. Show inventory isolation (1 min)

```bash
cat inventories/sharding/hosts.yml
```

**Say:** "We never reuse `iris_primary` / `iris_backup` groups."

### 3. Run validation (3 min)

```bash
ansible-playbook playbooks/sharding/validate_sharding.yml -i inventories/sharding
```

**Expected output (per node, abbreviated):**

```json
{
  "node": "shard_data1",
  "cluster_namespace": "SHARDCLUSTER",
  "node_ready": true,
  "data_node_count": 3,
  "local_node_type": "Data"
}
```

**Say:** "Same pattern as Topic 1 — read-only ObjectScript emits
`SHARDING_JSON` for Ansible asserts."

### 4. List cluster nodes (2 min)

```bash
docker exec shard_data1 sh -c 'iris session IRIS <<EOF
zn "%SYS"
do $SYSTEM.Cluster.ListNodes()
halt
EOF'
```

**Expected:** Three data nodes with NodeId 1, 2, 3.

### 5. Demo sharded table (3 min)

Portal → `SHARDCLUSTER` → SQL:

```sql
SELECT MRN, FamilyName FROM ShardDemo.Patient;
```

**Say:** "Rows distribute by `SHARD KEY (MRN)` — demo uses three sample MRNs."

Optional — show re-run idempotency:

```bash
ansible-playbook playbooks/sharding/setup_sharding_cluster.yml -i inventories/sharding
```

Look for `CLUSTER_ACTION:SKIP already cluster member` or `CLUSTER_CHANGED:0`.

### 6. Architecture slide (2 min)

Open [sharding-architecture.md](../../architecture/sharding-architecture.md) —
walk through node 1 master namespace vs cluster namespace on all nodes.

### 7. Close with recommendation (2 min)

Summarize [recommendation.md](recommendation.md): suitable for large
shard-key-aligned clinical facts; risks around cross-shard SQL and ops complexity.

---

## Concept-only path (license blocked)

If `%SYSTEM.Cluster.Initialize()` fails on license:

1. Present [concept-summary.md](concept-summary.md) + terminology
2. Walk through checklists (workload + infrastructure)
3. Show playbooks/roles **without** running mutating steps
4. Show `sharding_hands_on_enabled: false` gate — deliberate safety
5. Document blocker in demo notes:

```text
Hands-on blocked: <edition/license reason>
Deliverables: docs + automation + diagrams complete
```

---

## Expected final state

| Check | Expected |
| ----- | -------- |
| Containers | 3 × `shard_data*` Up (healthy) |
| Cluster namespace | `SHARDCLUSTER` on all nodes |
| Data nodes | 3 (non-mirrored) |
| Demo table | `ShardDemo.Patient` with 3 rows |
| Ansible | `validate_sharding.yml` → `failed=0` |

Capture evidence:

```bash
ansible-playbook playbooks/sharding/validate_sharding.yml -i inventories/sharding \
  -e write_evidence=true
# → evidence/sharding/validation-sharding-*.json
```
