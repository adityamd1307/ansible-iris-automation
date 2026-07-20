# Topic 2 — Sharding documentation index

Topic 2 is **separate** from Topic 1 (mirror automation). Another engineer
can work on sharding without touching `playbooks/configure.yml` or
`inventories/poc/`.

## Week-1 gate status

| Gate item | Doc | Status |
| --------- | --- | ------ |
| IRIS version + edition supports sharding | [version-license-gate.md](version-license-gate.md) | **Complete checklist — verify locally before hands-on** |
| Workload suitability reviewed | [workload-suitability-checklist.md](workload-suitability-checklist.md) | Complete |
| Infrastructure readiness reviewed | [infrastructure-readiness-checklist.md](infrastructure-readiness-checklist.md) | Complete |
| HA + mirroring boundary understood | [ha-mirroring-considerations.md](ha-mirroring-considerations.md) | Complete |

Hands-on playbooks are **gated** by `sharding_hands_on_enabled` in
`inventories/sharding/group_vars/all.yml` (default `false`). Concept
docs, diagrams, checklists, and read-only validation scaffolding ship
even when license/edition blocks live cluster mutation.

## Concept & decision docs

| Document | Purpose |
| -------- | ------- |
| [concept-summary.md](concept-summary.md) | What / why / when / when-not |
| [terminology.md](terminology.md) | Data node, node 1, compute node, cluster vs master namespace |
| [workload-suitability-checklist.md](workload-suitability-checklist.md) | Is your workload a sharding candidate? |
| [infrastructure-readiness-checklist.md](infrastructure-readiness-checklist.md) | Hosts, network, licenses, ECP |
| [ha-mirroring-considerations.md](ha-mirroring-considerations.md) | Mirrored sharding = separate layer; POC scope |
| [recommendation.md](recommendation.md) | Health IT suitability, risks, next steps |

## Operational docs

| Document | Purpose |
| -------- | ------- |
| [operational-runbook.md](operational-runbook.md) | Build → verify → tear down sharding POC |
| [demo-script.md](demo-script.md) | Presenter walkthrough + expected output |
| [mechanism-mapping-sharding.md](mechanism-mapping-sharding.md) | CPF vs `%SYSTEM.Cluster` vs validation JSON |
| [failure-modes-sharding.md](failure-modes-sharding.md) | Partial failure + recovery |

## Architecture

| Document | Purpose |
| -------- | ------- |
| [../../architecture/sharding-architecture.md](../../architecture/sharding-architecture.md) | Mermaid: data nodes, node 1, optional compute |
| [../../architecture/combined-future-architecture.md](../../architecture/combined-future-architecture.md) | Conceptual Topic 1 + Topic 2 (future) |

## Repo map (Topic 2 only)

```text
docs/sharding/                          # This index + concept/ops docs
architecture/sharding-architecture.md
iris-env/IRISShardCluster/              # Separate Docker stack
inventories/sharding/                   # shard_data1..3 — NOT iris_primary
cpf/sharding/
objectscript/sharding/
roles/iris_sharding_*
playbooks/sharding/
examples/desired-state-sharding.example.yml
evidence/sharding/
```

## Quick start (after gate)

```bash
# 1. License + stack
ansible-playbook playbooks/sharding/stack_up.yml -i inventories/sharding \
  -e iris_key_source=/path/to/iris.key

# 2. Enable gate in inventories/sharding/group_vars/all.yml:
#    sharding_hands_on_enabled: true

# 3. Configure + validate
ansible-playbook playbooks/sharding/configure_sharding.yml -i inventories/sharding
```

See [operational-runbook.md](operational-runbook.md) for troubleshooting and tear-down.
