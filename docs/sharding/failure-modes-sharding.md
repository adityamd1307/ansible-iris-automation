# Failure modes — Sharding (Topic 2)

Partial failure behaviour and safe recovery for sharding playbooks.

## Playbook order dependency

```text
stack_up → setup_sharding_cluster (serial: node1 → data2 → data3)
         → create_sharded_namespace (node1 only)
         → validate_sharding (all nodes)
```

A failure mid-chain leaves the cluster **partially formed**. Re-runs are
designed idempotent where the API allows.

## Failure matrix

| Failure point | Cluster state | Safe re-run? | Recovery |
| ------------- | ------------- | ------------ | -------- |
| `stack_up` — missing key | Containers crash-loop | After fixing keys | Copy `iris.key`, restart compose |
| ECP CPF merge error | Independent instances | Yes | Fix template, re-run setup |
| `Initialize()` on node 1 fails | Not a cluster | Yes | Fix license/network, re-run |
| `Initialize()` succeeded, attach fails | Node 1 only | Yes on failed nodes | Re-run `setup_sharding_cluster.yml` (serial) |
| Attach wrong URL | Node isolated | After fix vars | Correct `cluster_url` / IP, re-attach |
| Demo table SQL fails | Cluster up, no demo data | Yes | Fix SQL vars, re-run `create_sharded_namespace.yml` |
| Validation fails count | Partial attach | Diagnose first | `ListNodes()` on node 1 |
| Node already member (re-attach) | Cluster intact | Yes | Script emits SKIP |

## Symptom → action

### `CLUSTER_ERROR: ... license`

- **Cause:** Sharding not enabled on license/edition
- **Action:** Stop mutating playbooks; set `sharding_hands_on_enabled: false`
- **Deliverable path:** Concept docs + [recommendation.md](recommendation.md)

### `Attach FAILED` / ECP connection

- **Cause:** Hostname resolution, firewall, or `shard_host_ip` mismatch
- **Action:** Verify `172.29.0.x` connectivity; set `cluster_allowed_connections`
- **Action:** Ensure `MaxServers` ≥ 3 (may need instance restart)

### `NOTREADY` after 30 retries

- **Cause:** Slow startup or attach still propagating
- **Action:** Check `messages.log`; increase retries in role task
- **Action:** Manual `$SYSTEM.Cluster.IsNodeReady()`

### Node 1 initialized twice from scratch

- **Cause:** Re-used durable volumes with new intent
- **Action:** `stack_down.yml` with `sharding_remove_volumes: true`

### Detach / reset needed

On a **non-production POC** the fastest recovery is full tear-down:

```bash
ansible-playbook playbooks/sharding/stack_down.yml -i inventories/sharding
# re-copy keys, stack_up, configure
```

Surgical detach (advanced):

```objectscript
zn "%SYS"
write $SYSTEM.Cluster.Detach()
; Node 1 cannot detach while cluster has data — see IRIS docs
```

## Partial failure — Ansible behaviour

| Task | changed_when | failed_when |
| ---- | ------------ | ----------- |
| CPF merge | stdout lacks `Merged 0` | rc ≠ 0 or ERROR in stdout |
| Cluster setup | session logs `CLUSTER_CHANGED:1` | `CLUSTER_ERROR` in stdout |
| Validation | never | assert on JSON fields |

## Evidence after incident

```bash
ansible-playbook playbooks/sharding/validate_sharding.yml -i inventories/sharding \
  -e write_evidence=true
docker logs --tail 200 shard_data1 > evidence/sharding/incident-node1.log
```

Document outcome in demo notes even when hands-on blocked.

## Topic 1 isolation

Sharding failures do **not** affect Topic 1 containers (`irisa`, `irisb`).
Different compose project, subnet, and inventory. No shared playbooks.
