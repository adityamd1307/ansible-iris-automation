# SecuritySync ObjectScript module

Primary → backup **roles and users** sync for mirrored IRIS environments where
`IRISSECURITY` is **not** replicated.

## Purpose

Ansible orchestrates export on the primary, file transfer, and import on the
backup. All security logic lives in these `%SYS` classes; Ansible only decides
**when**, **where**, **transfer**, and **cleanup**.

## Scope

| Included | Excluded |
| -------- | -------- |
| `Security.Roles` Export/Import | Services |
| `Security.Users` Export/Import | Resources |
| | Applications |
| | SSL/TLS, LDAP, audit, etc. |

## Import order

1. **Roles** — must exist before users that reference them.
2. **Users** — imported after roles.

## API façade

Ansible invoke scripts call only `SecuritySync.Service` methods:

| Method | Action |
| ------ | ------ |
| `RunExport()` | Export roles + users XML on primary |
| `RunImport()` | Import roles then users on backup |
| `DryRunImport()` | Validate import files (`Flags=1`, no mutation) |
| `RunValidate()` | Post-sync read-only checks (counts + required roles/users) |
| `CreateTestDelta()` | E2E helper — test role/user on primary only |

Each method emits one line: `SECURITY_SYNC_JSON:{...}`.

## Default XML paths

- `/tmp/iris_security_roles.xml`
- `/tmp/iris_security_users.xml`

Override via `SecuritySync.Config` properties (wired from Ansible vars).

## Dry-run

`DryRunImport()` passes `Flags=1` to `Security.Roles.Import` and
`Security.Users.Import`. IRIS validates the XML and returns counts without
applying changes.

## Mirror caveat

Mirroring replicates **application database data**, not `%SYS` security. Both
nodes need converged security for failover readiness; this module syncs primary
state to backup after initial bootstrap.

## Sensitive data

User export XML contains password **hashes and metadata**, not plaintext
passwords. Treat exported XML as sensitive; playbooks use `no_log` and delete
files after each run.
