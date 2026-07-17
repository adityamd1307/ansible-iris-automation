# Web Application Overview — CSP `/csp/training`

How Ansible creates and updates IRIS web (CSP) application definitions.

**Related:** [namespace-overview.md](namespace-overview.md) · [security-overview.md](security-overview.md) · [mechanism-mapping.md](mechanism-mapping.md)

---

## Playbook

```bash
ansible-playbook playbooks/setup_webapp.yml -i inventories/poc
```

**Role:** `roles/iris_webapp/tasks/main.yml`

**Mechanism:** Guarded ObjectScript — `Security.Applications` API (not CPF).

**Prerequisites:** Namespace `TRAINING` must exist (`create_namespace.yml`).

---

## Desired state

```yaml
web_apps:
  - path: /csp/training
    namespace: TRAINING
    description: "TRAINING POC CSP application"
    authentication_methods: 32   # Password authentication bitmask
    enabled: true
```

Add entries to `web_apps` to create more applications — the ObjectScript loop
is data-driven.

---

## Expected output markers

| Marker | Meaning |
| ------ | ------- |
| `CREATED /csp/training` | New web app |
| `UPDATED /csp/training` | Existing app modified to match desired state |
| `EXISTS /csp/training` | Already converged (idempotent re-run) |

---

## Portal verification

http://localhost:8081/csp/sys/UtilHome.csp →

**System Administration → Security → Applications → Web Applications**

Look for `/csp/training` mapped to namespace `TRAINING`.

Application URL (after gateway routing):

```text
http://localhost:8081/csp/training/...
```

Repeat on `:8082` — bootstrap runs on **both** nodes so each has the app definition.

---

## Validation

`validate_nodes.yml` checks `web_app_exists: true` in `READINESS_JSON` for
each configured `web_apps` path.

---

## Why ObjectScript, not CPF

Web application security objects are runtime `Security.Applications` entries.
They are not reliably expressed in CPF merge for this IRIS version — same
pattern as roles and services.

---

## Files

| File | Purpose |
| ---- | ------- |
| `playbooks/setup_webapp.yml` | Entry playbook |
| `objectscript/setup_webapp.cos.j2` | Guarded create/modify |
| `roles/iris_webapp/` | Push script, session, cleanup |
