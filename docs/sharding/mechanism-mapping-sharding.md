# Mechanism mapping — Sharding (Topic 2)

Parallel to [mechanism-mapping.md](../mechanism-mapping.md) for Topic 1.
Records mechanism choice, idempotency, and file locations.

| Configuration item | Mechanism (this repo) | Why | Idempotency approach | Where |
| ------------------ | --------------------- | --- | -------------------- | ----- |
| ECP MaxServers / MaxServerConn | **CPF merge** | Declarative interconnect prerequisites | Re-merge converges; restart may be needed if values changed post-install | `cpf/sharding/cluster-template.cpf.j2`, `setup_sharding_cluster.yml` |
| ECP service enable | **CPF merge** | Required before Cluster API | Same | Same |
| Cluster node 1 formation | **ObjectScript `%SYSTEM.Cluster.Initialize()`** | CPF cannot express cluster topology | `ClusterNamespace()` non-empty → SKIP | `objectscript/sharding/setup_cluster.cos.j2` |
| Data node attach | **ObjectScript `%SYSTEM.Cluster.AttachAsDataNode()`** | Runtime cluster membership | Already member → SKIP; attach errors surfaced as `CLUSTER_ERROR` | Same |
| Compute node attach (stretch) | **ObjectScript `%SYSTEM.Cluster.AttachAsComputeNode()`** | Not in default POC compose | Same pattern | Extend `setup_cluster.cos.j2` + inventory |
| Demo sharded table | **ObjectScript SQL (`%SQL.Statement`)** | SHARD KEY not expressible in CPF | `SQLCODE 201` → exists; INSERT … WHERE NOT EXISTS | `objectscript/sharding/create_sharded_demo.cos.j2`, `create_sharded_namespace.yml` |
| Cluster validation | **ObjectScript read-only → JSON** | Never mutates | Read-only; `SHARDING_JSON` parsed with `from_json` | `objectscript/sharding/validate_sharding.cos.j2`, `validate_sharding.yml` |
| Docker stack lifecycle | **Ansible `command` + compose** | Separate from Topic 1 infra | `stack_up` / `stack_down` repeatable | `playbooks/sharding/stack_*.yml` |
| License / edition gate | **Ansible `assert` on group var** | Prevent destructive runs without license | `sharding_hands_on_enabled` must be true | `roles/iris_sharding_data_node/tasks/main.yml` |

## Mechanism rules applied

1. **CPF merge for static prerequisites** (ECP limits, ECP enable).
2. **`%SYSTEM.Cluster` for all topology mutations** — not legacy
   `%SYSTEM.Sharding` namespace-level API.
3. **Guarded ObjectScript** — check membership before Initialize/Attach.
4. **Read-only validation** with single-line `SHARDING_JSON` (same REPL
   constraint as Topic 1 `READINESS_JSON` / `MIRROR_JSON`).
5. **Serial execution** on `shard_nodes` for ordered Initialize → Attach.

## ObjectScript execution constraint

Same as Topic 1: `iris session` REPL requires **one statement per line**.
All `.cos.j2` under `objectscript/sharding/` follow that rule.

## API reference

- [%SYSTEM.Cluster](https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?CLASSNAME=%25SYSTEM.Cluster&LIBRARY=%25SYS)
- [Sharding Reference (Scalability Guide)](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSCALE_sharding_reference)

## Explicit non-goals (POC)

| Item | Mechanism | Status |
| ---- | --------- | ------ |
| Mirrored sharded data nodes | `InitializeMirrored` / `AttachAsMirroredNode` | Documented only |
| Shard rebalance / node removal | `%SYSTEM.Sharding.Rebalance()` | Out of scope |
| Topic 1 mirror playbooks | N/A | Not imported |
