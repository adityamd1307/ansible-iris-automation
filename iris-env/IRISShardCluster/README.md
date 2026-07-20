# IRISShardCluster — Topic 2 Docker stack

Non-mirrored **data-node-only** sharded cluster for hands-on Topic 2 work.
This stack is intentionally separate from `iris-env/IRISSystemManagement`
(Topic 1 mirror POC).

## Topology

| Container     | Role              | Superserver (host) | Web (host) | Docker IP    |
| ------------- | ----------------- | ------------------ | ---------- | ------------ |
| `shard_data1` | Node 1 (initialize)| `41773`           | `42773`    | `172.29.0.10`|
| `shard_data2` | Data node 2       | `43773`            | `44773`    | `172.29.0.11`|
| `shard_data3` | Data node 3       | `45773`            | `46773`    | `172.29.0.12`|

All containers share the `shard_net` bridge (`172.29.0.0/16`), distinct
from Topic 1's `iris_net` (`172.28.0.0/16`), so both stacks can run on
one workstation without port or subnet clashes.

## Prerequisites

1. Complete the **Week-1 gate**: [docs/sharding/version-license-gate.md](../../docs/sharding/version-license-gate.md)
2. Authenticated to InterSystems Container Registry (see [docs/licensed-image-setup.md](../../docs/licensed-image-setup.md))
3. A valid **sharding-enabled** `iris.key` for every data node

## License placement

Copy the same key into each node's runtime folder (git-ignored):

```bash
cd iris-env/IRISShardCluster
mkdir -p shard_data1 shard_data2 shard_data3
cp /path/to/iris.key shard_data1/iris.key
cp /path/to/iris.key shard_data2/iris.key
cp /path/to/iris.key shard_data3/iris.key
```

Or use Ansible:

```bash
ansible-playbook playbooks/sharding/stack_up.yml -i inventories/sharding \
  -e iris_key_source=/path/to/iris.key
```

## Start / stop

```bash
cp .env.example .env   # edit IRISTAG if needed
docker compose config --quiet
docker compose up -d --pull missing
docker compose ps
```

Stop without deleting data:

```bash
docker compose stop
docker compose up -d
```

## Tear down (destructive)

Removes containers **and** named volume mounts under this directory:

```bash
docker compose down -v --remove-orphans
rm -rf shard_data1 shard_data2 shard_data3
```

Then recreate license folders before the next `up`.

## Configure with Ansible

From the repo root (WSL or native shell):

```bash
ansible-playbook playbooks/sharding/configure_sharding.yml -i inventories/sharding
```

See [docs/sharding/operational-runbook.md](../../docs/sharding/operational-runbook.md) for the full build → verify → tear-down flow.

## Management Portal (direct)

```text
Node 1: http://localhost:42773/csp/sys/UtilHome.csp
Node 2: http://localhost:44773/csp/sys/UtilHome.csp
Node 3: http://localhost:46773/csp/sys/UtilHome.csp
```

After cluster configuration, use the **cluster namespace** on any node
(default `SHARDCLUSTER` — see `inventories/sharding/group_vars/all.yml`).
