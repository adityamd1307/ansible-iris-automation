# Version & license gate (§5.2 mandatory — before hands-on)

Complete **every** item before setting `sharding_hands_on_enabled: true` or
running mutating sharding playbooks. If any item fails, stay in
**concept-only** mode: docs, diagrams, and checklists still satisfy
deliverables; document the blocker in your demo notes.

## 1. Edition & license

| Check | How to verify | Pass criteria |
| ----- | ------------- | ------------- |
| Sharding feature licensed | Management Portal → System Administration → Licensing, or `^%LICENSE` | Sharding / horizontal scalability enabled |
| Not community edition | Image tag + license file | `intersystems/iris` licensed image, not `iris-community` |
| Same key on all data nodes | `iris-env/IRISShardCluster/shard_data*/iris.key` | Valid key on every node before `docker compose up` |
| Key matches image major version | WRC / license letter | No version mismatch errors in `messages.log` |

**Common blockers**

- **IRIS Community** — no sharding; use licensed ICR image (see [licensed-image-setup.md](../licensed-image-setup.md)).
- **HealthShare images** — may not expose full sharding; confirm with your WRC contact.
- **Expired or lab key** — containers start but `%SYSTEM.Cluster.Initialize()` returns license errors.

## 2. IRIS version

| Check | Pass criteria |
| ----- | ------------- |
| `%SYSTEM.Cluster` API available | IRIS 2019.1+ cluster-level sharding (not legacy `%SYSTEM.Sharding` namespace-level only) |
| Documented version in demo notes | Record exact `IRISTAG` from `.env` |

This repo targets **`%SYSTEM.Cluster`** (modern cluster-level architecture).
Legacy **shard master / shard server** terminology maps to **node 1 / data
node** — see [terminology.md](terminology.md).

## 3. Instance prerequisites (%SYSTEM.Cluster docs)

| Check | Automation | Manual fallback |
| ----- | ---------- | --------------- |
| TCP/IP between nodes | Docker `shard_net` 172.29.0.0/16 | `ping` / `telnet host 1972` between containers |
| ECP `MaxServers` / `MaxServerConn` ≥ node count | `cpf/sharding/cluster-template.cpf.j2` | Portal → ECP settings |
| Instances not mirror members | Fresh Topic 2 stack only | `^MIRROR` must be inactive before Initialize |
| Instances not already cluster members | Tear down or `Detach()` | `$SYSTEM.Cluster.ClusterNamespace()` empty |

**Note:** If ECP limits change after install, IRIS may require **restart**
before Cluster API calls succeed. The runbook documents re-run behaviour.

## 4. Gate flag (repo)

In `inventories/sharding/group_vars/all.yml`:

```yaml
sharding_hands_on_enabled: false   # flip to true only when table above passes
```

Mutating playbooks (`setup_sharding_cluster.yml`, `create_sharded_namespace.yml`,
`configure_sharding.yml`, `site.yml`) assert this flag.

Read-only `validate_sharding.yml` can run against an already-configured cluster
without the flag (useful for evidence capture).

## 5. Record outcome

| Outcome | Action |
| ------- | ------ |
| All checks pass | Set gate `true`, run [operational-runbook.md](operational-runbook.md) |
| License/edition blocked | Keep gate `false`; present concept docs + [recommendation.md](recommendation.md) |
| Partial (e.g. 2 of 3 nodes) | See [failure-modes-sharding.md](failure-modes-sharding.md), do not demo as green |

Capture license edition and IRIS version in `evidence/sharding/gate-status.txt`
(optional, git-ignored).
