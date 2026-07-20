# Sharding operational runbook (Topic 2)

Build → configure → verify → tear down for the non-mirrored data-node POC.

## 0. Prerequisites

- Topic 1 stack **not required** (independent inventory)
- [version-license-gate.md](version-license-gate.md) completed
- Docker + Ansible on control node
- Licensed `iris.key` with sharding enabled

## 1. Start Docker stack

```bash
cd /path/to/ansible-iris-automation

ansible-playbook playbooks/sharding/stack_up.yml -i inventories/sharding \
  -e iris_key_source=/path/to/iris.key
```

Manual alternative:

```bash
cd iris-env/IRISShardCluster
cp .env.example .env
# copy iris.key into shard_data1/, shard_data2/, shard_data3/
docker compose up -d --pull missing
docker compose ps
```

Wait until all three containers are healthy:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep shard_data
```

## 2. Enable hands-on gate

Edit `inventories/sharding/group_vars/all.yml`:

```yaml
sharding_hands_on_enabled: true
```

## 3. Configure cluster

Full flow (cluster + demo table + validate):

```bash
ansible-playbook playbooks/sharding/configure_sharding.yml -i inventories/sharding
```

Step-by-step:

```bash
ansible-playbook playbooks/sharding/setup_sharding_cluster.yml -i inventories/sharding
ansible-playbook playbooks/sharding/create_sharded_namespace.yml -i inventories/sharding
ansible-playbook playbooks/sharding/validate_sharding.yml -i inventories/sharding \
  -e write_evidence=true
```

**Expected:** `failed=0` on all playbooks; `SHARDING_JSON` shows
`data_node_count: 3`, `node_ready: true` on each host.

## 4. Verify in Portal

| Node | URL |
| ---- | --- |
| shard_data1 | http://localhost:42773/csp/sys/UtilHome.csp |
| shard_data2 | http://localhost:44773/csp/sys/UtilHome.csp |
| shard_data3 | http://localhost:46773/csp/sys/UtilHome.csp |

On node 1, switch to namespace `SHARDCLUSTER` and confirm
`ShardDemo.Patient` exists (System Explorer → SQL or globals).

ObjectScript spot-check (node 1):

```bash
docker exec -it shard_data1 iris session IRIS
```

```objectscript
zn "SHARDCLUSTER"
do $SYSTEM.Cluster.ListNodes()
halt
```

## 5. Idempotency re-run

```bash
ansible-playbook playbooks/sharding/configure_sharding.yml -i inventories/sharding
```

Second run should show `CLUSTER_CHANGED:0`, `SHARD_DEMO_CHANGED:0`, and
validation still green.

## 6. Tear down

```bash
ansible-playbook playbooks/sharding/stack_down.yml -i inventories/sharding
```

Or manually:

```bash
cd iris-env/IRISShardCluster
docker compose down -v --remove-orphans
rm -rf shard_data1 shard_data2 shard_data3
```

## Troubleshooting

| Symptom | Likely cause | Action |
| ------- | ------------ | ------ |
| `Initialize FAILED` license | Sharding not licensed | [version-license-gate.md](version-license-gate.md) |
| `Attach FAILED` hostname | Wrong cluster URL / IP | Check `cluster_url`, `shard_host_ip` |
| `NOTREADY` timeout | ECP limits / startup | Increase retries; check `messages.log` |
| `ERROR #415` on CPF | Invalid section | ECP template only — no `[Services]` conflicts |
| Node already cluster member | Previous partial run | `stack_down` full reset or `$SYSTEM.Cluster.Detach()` |
| Gate assert failure | Flag still false | Set `sharding_hands_on_enabled: true` |

Logs:

```bash
docker logs --tail 120 shard_data1
docker logs --tail 120 shard_data2
docker logs --tail 120 shard_data3
```

See [failure-modes-sharding.md](failure-modes-sharding.md) for recovery paths.

## Coexistence with Topic 1

Topic 1 mirror stack uses ports `51773+` and subnet `172.28.0.0/16`.
Topic 2 uses `41773+` and `172.29.0.0/16`. No playbook imports cross topics.
