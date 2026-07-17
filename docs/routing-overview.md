# Routing Overview — Web Gateways & HAProxy

How external HTTP traffic reaches IRIS and follows the active mirror primary.

**Related:** [infra-overview.md](infra-overview.md) · [mirror-overview.md](mirror-overview.md)

---

## Traffic paths

```text
Direct per-node (demo/admin):
  :8081 → webgatewaya → irisa:1972
  :8082 → webgatewayb → irisb:1972

HAProxy front door:
  :8080 → haproxy → active primary's webgateway → IRIS superserver
```

Use **8081/8082** when you need to know which node you are on.
Use **8080** to simulate client access that should follow failover.

Portal URLs (always `.csp`):

```text
http://localhost:8081/csp/sys/UtilHome.csp   # irisa
http://localhost:8082/csp/sys/UtilHome.csp   # irisb
http://localhost:8080/csp/sys/UtilHome.csp   # via HAProxy
```

---

## Static vs dynamic routing

| Component | Behavior |
| --------- | -------- |
| `webgatewaya` / `webgatewayb` | Fixed mapping to `irisa` / `irisb` (see `group_vars/all.yml` `webgateway_configs`) |
| `haproxy` | **Dynamic** — backend follows mirror primary |

After failover, `:8080` must point at the backup's gateway unless you run
`update_haproxy_primary.yml`.

---

## Playbooks

**Detect primary and reload HAProxy:**

```bash
ansible-playbook playbooks/update_haproxy_primary.yml -i inventories/poc
```

Flow:

1. `tasks/detect_mirror_primary.yml` — `$SYSTEM.Mirror.IsPrimary()` on each node
2. `tasks/resolve_haproxy_primary.yml` — pick backend IP/host
3. Render `config/haproxy/haproxy.cfg.j2` → `haproxy/haproxy.cfg`
4. `docker kill -s HUP haproxy` or compose restart

**End-to-end routing test:**

```bash
ansible-playbook playbooks/test_routing.yml -i inventories/poc
```

Imports `update_haproxy_primary.yml`, then GET `:8080/csp/sys/UtilHome.csp` and
asserts `'InterSystems IRIS'` in response body.

Expected: `Routing test passed. HAProxy :8080 serves IRIS via backend ...`

---

## Configuration reference

From `group_vars/all.yml`:

```yaml
haproxy_initial_primary: irisa
haproxy_primary_backends:
  irisa:
    host: webgatewaya
    ip: 172.28.0.20
  irisb:
    host: webgatewayb
    ip: 172.28.0.21
webgateway_iris_port: 1972
```

HAProxy health check: `GET /csp/sys/UtilHome.csp` (see `config/haproxy/haproxy.cfg.j2`).

---

## When to run

| Event | Action |
| ----- | ------ |
| After `configure.yml` | Optional `test_routing.yml` |
| After manual failover (`docker kill irisa`) | **Required** `update_haproxy_primary.yml` |
| Before demo using `:8080` | Run update + test |

---

## Troubleshooting

| Symptom | Action |
| ------- | ------ |
| `:8080` serves wrong node | Run `update_haproxy_primary.yml` |
| 502 from HAProxy | Check target gateway healthy; verify CSP.ini |
| Test routing fails content check | Gateway up but IRIS not responding — check `docker logs webgatewaya` |
| Wrong URL 404 | Use `UtilHome.csp` not `.cs` |

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/update_haproxy_primary.yml` | Primary detection + HAProxy reload |
| `playbooks/test_routing.yml` | HAProxy smoke test |
| `tasks/detect_mirror_primary.yml` | ObjectScript primary probe |
| `tasks/resolve_haproxy_primary.yml` | Map primary → backend |
| `config/haproxy/haproxy.cfg.j2` | HAProxy template |
| `group_vars/all.yml` | Backend IPs and gateway mapping |
