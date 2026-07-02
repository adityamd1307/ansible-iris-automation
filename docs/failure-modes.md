# Failure Modes & Partial-Failure Handling

This document describes how the automation behaves when things go wrong,
and how an engineer recovers. Because every step is **idempotent**, the
general recovery strategy is: *fix the root cause, then re-run the same
playbook.*

---

## 1. General principles

- **Fail fast, fail loud.** Pre-flight checks (license key present, docker
  compose config valid, arbiter reachable) stop the run before making
  partial changes.
- **Converge, don't accumulate.** CPF merge and guarded ObjectScript both
  re-apply the desired state, so a half-finished run is corrected by the
  next run rather than compounding.
- **Read-only validation is safe** to run at any time to see current
  state without changing anything.

---

## 2. Partial failure across nodes

The configure flow targets a group (`iris_nodes`). By default Ansible uses
the **linear** strategy: it runs each task on all hosts before moving on.

Scenario: `irisa` succeeds, `irisb` fails part-way through `configure.yml`.

- What you have: `irisa` fully converged; `irisb` converged up to the
  failing task.
- Recovery:
  1. Inspect the failing task output for the root cause on `irisb`.
  2. Fix it (e.g. missing directory, image not ready).
  3. Re-run the same playbook. `irisa` reports `changed=0` (already in
     desired state); `irisb` continues to convergence.
- Optional: limit the re-run to the affected node:

```bash
ansible-playbook playbooks/configure.yml -i inventories/poc --limit irisb
```

To stop the entire run on the first failing host instead of continuing:

```bash
ansible-playbook playbooks/configure.yml -i inventories/poc -e any_errors_fatal=true
```

---

## 3. Failure-mode catalogue

| # | Failure | Detection | Blast radius | Recovery |
|---|---------|-----------|--------------|----------|
| 1 | Missing `iris.key` | Assertion in `prepare.yml` | None (stops before start) | Provide key via `-e iris_key_source=` or `-e require_iris_key=false` |
| 2 | Docker compose config invalid | `docker compose config --quiet` in `prepare.yml` | None | Fix `docker-compose.yml` / `.env` |
| 3 | Container fails to become healthy | `wait_for` timeout in `verify.yml` | Config steps not reached | `docker compose logs <svc>`; fix image/ports; re-run |
| 4 | Database directory missing before merge | CPF merge `ERROR` | That node only | `setup_databases.yml` creates dirs first; re-run it, then `create_namespace.yml` |
| 5 | Namespace merged before its databases exist | CPF merge `ERROR` / namespace maps to missing DB | That node only | Run `setup_databases.yml` before `create_namespace.yml` (configure.yml enforces order) |
| 6 | Web app / role creation error | `sc=` shows error text in ObjectScript output | That node only | Read output; fix params in group_vars; re-run `setup_webapp.yml` / `setup_security.yml` |
| 7 | Password rotation fails | Task fails (output suppressed by `no_log`) | That node only | Verify vault value/user; re-run with `-e rotate_admin_password=true --ask-vault-pass` |
| 8 | Arbiter unreachable | `wait_for` in `validate_mirror.yml` | Mirror not ready | Start/repair arbiter; check `mirror_arbiter_host/port`; re-run |
| 9 | Journaling disabled on a node | Assertion in `validate_mirror.yml` | Mirror not ready | Enable journaling, or set `mirror_requires_journaling=false` for pre-mirror nodes |
| 10 | Validation JSON not parseable | `from_json` error | Reporting only | Inspect raw `session_result.stdout`; ensure only expected banner text; re-run |

---

## 3a. Required minimum failure scenarios (brief §3.3)

The eight mandated scenarios, with how the automation **detects** and how
you **recover**. Recovery is almost always "fix cause, re-run" thanks to
idempotency (optionally `--limit <host>`).

| # | Scenario | Detection | Recovery |
|---|----------|-----------|----------|
| 1 | **Node 2 unreachable** | Task fails on `irisb` with connection/`docker`/SSH error; `irisa` unaffected | Restore connectivity (container up / SSH key / host); re-run `--limit irisb` |
| 2 | **IRIS up on node 1, stopped on node 2** | `verify.yml` `wait_for` on node 2 ports times out; or `iris session` on node 2 errors | Start IRIS on node 2 (`docker compose up -d irisb` / start instance); re-run `configure.yml --limit irisb` |
| 3 | **Namespace on node 1 but not node 2** | `validate_nodes.yml` asserts `namespace_exists==true`; fails only on node 2 (JSON shows which) | Re-run `create_namespace.yml` (idempotent on node 1, creates on node 2); re-validate |
| 4 | **Database exists but mapping wrong** | `validate_nodes.yml` passes DB existence but namespace default global/routine points elsewhere; routing/app errors | Re-run `create_namespace.yml` - the `[Map.<ns>]` merge corrects `Global_Default`/`Routine_Default`; re-validate |
| 5 | **Web app on one node only** | `validate_nodes.yml` asserts `web_app_exists==true`; fails on the node missing it | Re-run `setup_webapp.yml` (guarded create where missing); re-validate |
| 6 | **Production auto-start on one node only** | `validate_nodes.yml` reports `production_configured` per node; mismatch visible in JSON (assert when `production_enforce=true`) | Re-run `setup_production.yml` on both nodes (guarded; sets only where different) |
| 7 | **Credential failure** | Auth error (SSH key / vault / IRIS user). Password-rotation output is `no_log`, so the task simply fails without leaking | Fix SSH key / `--ask-vault-pass` / IRIS account; re-run. Never commit or echo the secret |
| 8 | **CPF merge applied but IRIS restart failed** | Merge task succeeds, but a setting needing restart isn't active; `verify.yml`/validation shows the instance down or setting not applied | Bring the instance back up, re-run the merge if needed, then re-validate. See the restart note in `docs/mechanism-mapping.md` |

Validation output is both human-readable (assert messages) and
machine-readable JSON, so a portal/CI/monitoring tool can consume the
per-node results to pinpoint which node/scenario failed.

## 4. Idempotency & re-run safety

Every mutating operation is guarded:

- CPF merges converge and are marked `changed` only on real changes.
- ObjectScript setup checks existence before create; re-running an
  already-applied step produces `EXISTS`/`UPDATED` and no duplication.
- Staged/rendered files are per-host and overwritten each run; the
  security script (which may be templated with a password) is deleted
  from both the node and the control node after it runs.

Therefore the safe default after **any** failure is: fix the cause and
re-run the same playbook (optionally with `--limit <host>`).

---

## 5. Rollback notes

This POC is convergent rather than transactional. To "roll back":

- **Databases/namespace**: remove or re-point definitions in group_vars
  and re-apply, or drop them manually via the Management Portal / SMP.
- **Web apps/roles**: delete via SMP or extend the ObjectScript to a
  removal mode. They are not destroyed automatically to avoid data loss.
- **Whole POC**: `stack_down.yml` stops and removes the containers; the
  durable volumes (`irisa/`, `irisb/`, ...) persist unless deleted.
