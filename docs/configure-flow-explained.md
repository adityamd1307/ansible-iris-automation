# Configure Flow Explained

This document explains every file used by `playbooks/configure.yml` and
how the code fits together.

The short version:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/configure.yml -i inventories/poc
```

That single command converges the IRIS nodes to the desired state:

- physical databases exist
- `TRAINING` namespace exists
- `/csp/training` web application exists
- security service and role exist
- mirror `TRAININGMIRROR` exists
- `irisa` is primary
- `irisb` is backup
- validation passes

## 1. The Master File: `playbooks/configure.yml`

The file:

```yaml
# =====================================================================
# Full Topic-1 configuration flow (order matters)
# =====================================================================
# databases -> namespace/mappings -> web app -> security -> production
# auto-start -> validation. Every step is idempotent, so this whole
# playbook is safe to re-run.
#
# Run against an environment inventory, e.g.:
#   ansible-playbook playbooks/configure.yml -i inventories/poc
#
# To also rotate the admin password from the vault:
#   ansible-playbook playbooks/configure.yml -i inventories/poc \
#     -e rotate_admin_password=true --ask-vault-pass
- import_playbook: setup_databases.yml
- import_playbook: create_namespace.yml
- import_playbook: setup_webapp.yml
- import_playbook: setup_security.yml
- import_playbook: setup_production.yml
- import_playbook: setup_mirror.yml
- import_playbook: validate_nodes.yml
- import_playbook: validate_mirror.yml
```

What each line means:

| Line | Meaning |
| --- | --- |
| `import_playbook: setup_databases.yml` | Creates/registers physical IRIS databases. |
| `import_playbook: create_namespace.yml` | Creates the namespace and maps globals/routines to those databases. |
| `import_playbook: setup_webapp.yml` | Creates or updates CSP/web application definitions. |
| `import_playbook: setup_security.yml` | Enables services, creates roles, optionally rotates `_SYSTEM` password. |
| `import_playbook: setup_production.yml` | Attempts interop production auto-start setup when supported. |
| `import_playbook: setup_mirror.yml` | Builds/checks the primary/backup mirror. |
| `import_playbook: validate_nodes.yml` | Verifies namespace, databases, web app, and production status. |
| `import_playbook: validate_mirror.yml` | Verifies mirror membership and exact primary/backup roles. |

The order matters. If the namespace is created before the databases, it
can point to missing database definitions. If mirror setup runs before
the databases exist, there is nothing useful to mirror. The final two
playbooks are read-only validation.

## 2. Inventory And Desired State

Main file:

```text
inventories/poc/group_vars/all.yml
```

This file is the input data for the whole flow.

Important values:

```yaml
iris_env: poc
iris_instance: IRIS
iris_exec_mode: docker

namespace: TRAINING
globals_db: TRAININGDATA
routines_db: TRAININGCODE
db_directory_root: /usr/irissys/mgr
```

What they mean:

| Variable | Purpose |
| --- | --- |
| `iris_env` | Environment label used in evidence/output names. |
| `iris_instance` | IRIS instance name inside the container. |
| `iris_exec_mode` | Tells helper tasks whether to use Docker or direct host execution. |
| `namespace` | IRIS namespace to create. Currently `TRAINING`. |
| `globals_db` | Default globals database for the namespace. |
| `routines_db` | Default routines/classes database for the namespace. |
| `db_directory_root` | Base directory for physical database folders. |

Database list:

```yaml
databases:
  - name: "{{ globals_db }}"
    directory: "{{ db_directory_root }}/{{ globals_db | lower }}"
    size_mb: 10
  - name: "{{ routines_db }}"
    directory: "{{ db_directory_root }}/{{ routines_db | lower }}"
    size_mb: 10
```

This expands to:

```text
TRAININGDATA -> /usr/irissys/mgr/trainingdata
TRAININGCODE -> /usr/irissys/mgr/trainingcode
```

Mirror values:

```yaml
mirror_enabled: true
mirror_name: TRAININGMIRROR
mirror_databases:
  - "{{ globals_db }}"
  - "{{ routines_db }}"
```

`TRAININGMIRROR` is alphanumeric because IRIS mirror names cannot contain
underscores.

Host roles come from:

```text
inventories/poc/hosts.yml
```

Important groups:

```yaml
iris_primary:
  hosts:
    irisa: {}

iris_backup:
  hosts:
    irisb: {}
```

Those groups are what `setup_mirror.yml` uses to run primary work only on
`irisa` and backup work only on `irisb`.

## 3. Shared Helper Role

Reusable task helpers live in the `iris_common` role. Feature roles call
these helpers with `include_role`, while the top-level playbooks stay as
thin entry points.

### `roles/iris_common/tasks/push_file.yml`

Purpose:

1. Create a staging directory on the control machine.
2. Render a Jinja template into a real `.cpf` or `.cos` file.
3. Copy that rendered file into the target IRIS container.

Typical use:

```yaml
- name: Stage and push namespace CPF merge file
  ansible.builtin.include_role:
    name: iris_common
    tasks_from: push_file
  vars:
    src_template: "{{ playbook_dir }}/../cpf/namespace-template.cpf.j2"
    staged_name: "namespace-merge.cpf"
    remote_path: "/tmp/namespace-merge.cpf"
```

Meaning:

- `src_template` is the source template in the repo.
- `staged_name` is the temporary rendered filename.
- `remote_path` is where the file lands inside the container.

### `roles/iris_common/tasks/iris_merge.yml`

Purpose:

Run an IRIS CPF merge:

```bash
docker exec <container> iris merge IRIS /tmp/something.cpf
```

CPF merge is used for declarative configuration such as:

- database definitions
- namespace mappings

### `roles/iris_common/tasks/iris_session.yml`

Purpose:

Run ObjectScript through `iris session`:

```bash
docker exec -i <container> sh -c "iris session IRIS < /tmp/script.cos"
```

ObjectScript is used for runtime operations that are not cleanly handled
by CPF merge, such as:

- physical database file creation
- CSP application setup
- security service/role setup
- mirror API calls
- validation JSON generation

## 4. Step 1: `setup_databases.yml`

File:

```text
playbooks/setup_databases.yml
```

Purpose:

Create and register the physical databases.

Main tasks:

1. Create database directories inside each container as `root`.
2. Change ownership to `irisowner`.
3. Render and apply `cpf/database-template.cpf.j2`.
4. Render and run `objectscript/create_databases.cos.j2`.

Why `root` first?

The parent directory `/usr/irissys/mgr` is owned by `irisowner`, but the
container user may not be able to create child directories there directly
from `docker exec`. The playbook creates the directory as root and then
hands ownership back to `irisowner`:

```yaml
- docker
- exec
- --user
- root
- "{{ iris_container | default(inventory_hostname) }}"
- mkdir
- -p
- "{{ item.directory }}"
```

Then:

```yaml
- chown
- irisowner:irisowner
- "{{ item.directory }}"
```

Why both CPF and ObjectScript?

CPF merge registers database definitions:

```ini
[Databases]
TRAININGDATA=/usr/irissys/mgr/trainingdata
TRAININGCODE=/usr/irissys/mgr/trainingcode
```

But a runtime CPF merge does not reliably create the physical `IRIS.DAT`
file. The guarded ObjectScript creates the actual database if missing:

```objectscript
if ##class(SYS.Database).%ExistsId("/usr/irissys/mgr/trainingdata/") {
  write !,"EXISTS TRAININGDATA"
} else {
  set d=##class(SYS.Database).CreateDatabase("/usr/irissys/mgr/trainingdata/",.sc)
}
```

It also creates database resources:

```text
%DB_TRAININGDATA
%DB_TRAININGCODE
```

Expected output:

```text
EXISTS TRAININGDATA /usr/irissys/mgr/trainingdata
RESEXISTS %DB_TRAININGDATA
BOUNDALREADY TRAININGDATA
```

## 5. Step 2: `create_namespace.yml`

File:

```text
playbooks/create_namespace.yml
```

Purpose:

Create the `TRAINING` namespace and map it to the default databases.

It renders:

```text
cpf/namespace-template.cpf.j2
```

Template content:

```ini
[Namespaces]
%ALL={{ globals_db }}
{{ namespace }}={{ globals_db }}

[Map.{{ namespace }}]
Global_Default={{ globals_db }}
Routine_Default={{ routines_db }}
```

For POC, this becomes:

```ini
[Namespaces]
%ALL=TRAININGDATA
TRAINING=TRAININGDATA

[Map.TRAINING]
Global_Default=TRAININGDATA
Routine_Default=TRAININGCODE
```

Expected output:

```text
IRIS Merge of /tmp/namespace-merge.cpf into /iris-shared/durable/iris.cpf
IRIS Merge completed successfully
```

Portal check:

```text
System Administration > Configuration > System Configuration > Namespaces
```

Look for:

```text
TRAINING
```

## 6. Step 3: `setup_webapp.yml`

File:

```text
playbooks/setup_webapp.yml
```

Purpose:

Create or update CSP web applications.

It renders:

```text
objectscript/setup_webapp.cos.j2
```

Important logic:

```objectscript
if '##class(Security.Applications).Exists("/csp/training") {
  set sc=##class(Security.Applications).Create("/csp/training",.p)
  write !,"CREATED /csp/training sc="_$system.Status.GetErrorText(sc)
} else {
  set sc=##class(Security.Applications).Modify("/csp/training",.p)
  write !,"UPDATED /csp/training sc="_$system.Status.GetErrorText(sc)
}
```

Why ObjectScript?

CSP application definitions are runtime security/application objects. They
are more reliably managed through `Security.Applications` than CPF merge.

Expected output:

```text
UPDATED /csp/training sc=
```

Portal check:

```text
System Administration > Security > Applications > Web Applications
```

Look for:

```text
/csp/training
```

## 7. Step 4: `setup_security.yml`

File:

```text
playbooks/setup_security.yml
```

Purpose:

- enable web gateway service
- create application roles
- optionally rotate the admin password

It renders:

```text
objectscript/setup_security.cos.j2
```

Expected output:

```text
EXISTS SERVICE %Service_WebGateway
EXISTS ROLE TRAINING_APP
```

Password rotation is opt-in:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/configure.yml -i inventories/poc \
  -e rotate_admin_password=true --ask-vault-pass
```

When rotation is enabled, sensitive output is suppressed with `no_log`.

## 8. Step 5: `setup_production.yml`

File:

```text
playbooks/setup_production.yml
```

Purpose:

Try to configure interoperability production auto-start.

It renders:

```text
objectscript/setup_production.cos.j2
```

Expected output in this POC:

```text
SKIP interop-not-enabled-or-missing-class: <CLASS DOES NOT EXIST> Ens.Director
```

Meaning:

The current image/namespace does not expose Interoperability production
classes in `TRAINING`. That does not block database mirroring. It only
means production auto-start is not configured.

Validation does not fail because:

```yaml
production_enforce: false
```

## 9. Step 6: `setup_mirror.yml`

File:

```text
playbooks/setup_mirror.yml
```

Purpose:

Configure the IRIS mirror in two phases:

1. Primary setup on `iris_primary` (`irisa`)
2. Backup setup on `iris_backup` (`irisb`)

### Primary Phase

Template:

```text
objectscript/setup_mirror_primary.cos.j2
```

Important behavior:

- create or confirm mirror set `TRAININGMIRROR`
- start or confirm the mirror is started
- confirm `irisa` is primary
- add or confirm `irisb` as failover member
- add or confirm `TRAININGDATA` and `TRAININGCODE` as mirrored databases

Expected output:

```text
EXISTS MIRROR MEMBER type=Failover
EXISTS MIRROR STARTED TRAININGMIRROR
EXISTS PRIMARY
EXISTS FAILOVER irisb
EXISTS DATABASE TRAININGDATA
EXISTS DATABASE TRAININGCODE
```

### Backup Phase

Template:

```text
objectscript/setup_mirror_backup.cos.j2
```

Important behavior:

- join or confirm `irisb` is in the mirror
- start or confirm the mirror is started
- read the current primary journal position
- add or confirm the backup-side non-primary mirrored database copies

Expected output:

```text
EXISTS MIRROR MEMBER type=Failover
EXISTS MIRROR STARTED TRAININGMIRROR
PRIMARY JOURNAL POSITION ...
EXISTS DATABASE TRAININGDATA
EXISTS DATABASE TRAININGCODE
```

Why backup database registration matters:

If the backup is a mirror member but does not have active mirrored
database copies, old or new SQL changes may not appear as expected. The
backup script registers those non-primary database copies so new changes
from `irisa` replicate to `irisb`.

## 10. Step 7: `validate_nodes.yml`

File:

```text
playbooks/validate_nodes.yml
```

Purpose:

Read-only validation that each node is application-ready.

It renders:

```text
objectscript/validate_readiness.cos.j2
```

That script emits one JSON line:

```text
READINESS_JSON:{...}
```

The playbook extracts it:

```yaml
readiness: >-
  {{ (session_result.stdout_lines
      | select('match', '^READINESS_JSON:')
      | list | last | regex_replace('^READINESS_JSON:', '')) | from_json }}
```

Then asserts:

```yaml
- readiness.namespace_exists == true
- readiness.globals_db_exists == true
- readiness.routines_db_exists == true
- readiness.web_app_exists == true
```

Expected output:

```text
Validation PASSED: irisa is application-ready.
Validation PASSED: irisb is application-ready.
```

## 11. Step 8: `validate_mirror.yml`

File:

```text
playbooks/validate_mirror.yml
```

Purpose:

Read-only validation of mirror membership and exact roles.

It renders:

```text
objectscript/validate_mirror.cos.j2
```

That script emits:

```text
MIRROR_JSON:{...}
```

Important fields:

```json
{
  "is_mirror_member": true,
  "is_primary": true,
  "is_backup": false,
  "journaling_enabled": true
}
```

For `irisa`, expected:

```text
is_mirror_member: true
is_primary: true
is_backup: false
```

For `irisb`, expected:

```text
is_mirror_member: true
is_primary: false
is_backup: true
```

The playbook asserts:

```yaml
- not (mirror_enabled | bool) or (mirror.is_mirror_member == true)
- (mirror.expected_role != 'primary') or (mirror.is_primary == true)
- (mirror.expected_role != 'backup') or (mirror.is_backup == true)
```

Expected output:

```text
Mirror readiness OK on irisa (role: primary).
Mirror readiness OK on irisb (role: backup).
```

## 12. CPF Templates

### `cpf/database-template.cpf.j2`

Creates `[Databases]` entries:

```ini
[Databases]
{{ db.name }}={{ db.directory }}
```

Used by:

```text
setup_databases.yml
```

### `cpf/namespace-template.cpf.j2`

Creates namespace and mappings:

```ini
[Namespaces]
{{ namespace }}={{ globals_db }}

[Map.{{ namespace }}]
Global_Default={{ globals_db }}
Routine_Default={{ routines_db }}
```

Used by:

```text
create_namespace.yml
```

## 13. ObjectScript Templates

| File | Used by | Purpose |
| --- | --- | --- |
| `objectscript/create_databases.cos.j2` | `setup_databases.yml` | Creates physical database files and DB resources. |
| `objectscript/setup_webapp.cos.j2` | `setup_webapp.yml` | Creates/updates `/csp/training`. |
| `objectscript/setup_security.cos.j2` | `setup_security.yml` | Enables services, creates roles, optionally rotates password. |
| `objectscript/setup_production.cos.j2` | `setup_production.yml` | Configures interop production auto-start when supported. |
| `objectscript/setup_mirror_primary.cos.j2` | `setup_mirror.yml` | Configures primary mirror side on `irisa`. |
| `objectscript/setup_mirror_backup.cos.j2` | `setup_mirror.yml` | Configures backup mirror side on `irisb`. |
| `objectscript/validate_readiness.cos.j2` | `validate_nodes.yml` | Emits node readiness JSON. |
| `objectscript/validate_mirror.cos.j2` | `validate_mirror.yml` | Emits mirror role/status JSON. |

## 14. Why The Flow Is Idempotent

The playbooks are safe to re-run because they check before changing:

- directories are created with `mkdir -p`
- CPF merge converges definitions
- ObjectScript uses `Exists()` checks
- mirror setup converts known duplicate states into `EXISTS ...` output
- validation is read-only

Examples:

```text
EXISTS TRAININGDATA
EXISTS ROLE TRAINING_APP
EXISTS MIRROR MEMBER type=Failover
EXISTS DATABASE TRAININGDATA
```

Those are good signs on repeat runs.

## 15. How To Explain The Run Output

Common Ansible words:

| Output | Meaning |
| --- | --- |
| `ok` | Task completed and did not need to report a change. |
| `changed` | Task applied or re-applied a configuration operation. |
| `skipping` | Task was not applicable, usually because `iris_exec_mode` is `docker` not `direct`. |
| `failed=0` | The run succeeded. |

Common IRIS prompt lines:

```text
USER>
%SYS>
TRAINING>
```

These are normal `iris session` prompts. They are not errors.

Common expected warning:

```text
Found variable using reserved name 'namespace'
```

This is not fatal. It can be cleaned up later by renaming `namespace` to
`iris_namespace`.

Common expected production skip:

```text
SKIP interop-not-enabled-or-missing-class: <CLASS DOES NOT EXIST> Ens.Director
```

This only means interop production auto-start was skipped. It does not
mean namespace, databases, or mirror setup failed.

## 16. Management Portal Verification Map

Use direct gateways:

```text
IRISA primary: http://localhost:8081/csp/sys/UtilHome.csp
IRISB backup:  http://localhost:8082/csp/sys/UtilHome.csp
```

Verify namespace:

```text
System Administration > Configuration > System Configuration > Namespaces
```

Verify databases:

```text
System Administration > Configuration > System Configuration > Local Databases
```

Verify web app:

```text
System Administration > Security > Applications > Web Applications
```

Verify mirror:

```text
System Administration > Configuration > Mirror Settings
```

Expected:

```text
8081 / IRISA: primary
8082 / IRISB: backup
Mirror name: TRAININGMIRROR
Members: IRISA and IRISB
Member type: Failover
```

## 17. Replication Test

After `configure.yml` completes, create a new table on `irisa`:

```sql
CREATE TABLE SQLUser.DemoMirrorTest (
  ID INTEGER IDENTITY PRIMARY KEY,
  Note VARCHAR(100),
  CreatedAt TIMESTAMP
)
```

Insert:

```sql
INSERT INTO SQLUser.DemoMirrorTest (Note, CreatedAt)
VALUES ('created on IRISA primary', CURRENT_TIMESTAMP)
```

Query on `irisb`:

```sql
SELECT * FROM SQLUser.DemoMirrorTest
```

Expected:

```text
The row created on irisa appears on irisb.
```

If an old table does not appear on `irisb`, recreate it after
`configure.yml` completes. Tables created before the backup databases
were active mirrored copies may not replay onto the backup.

## 18. File Map For Demo Explanation

| Area | Files |
| --- | --- |
| Master flow | `playbooks/configure.yml` |
| Desired state | `inventories/poc/group_vars/all.yml`, `examples/desired-state.example.yml` |
| Inventory roles | `inventories/poc/hosts.yml` |
| Database setup | `playbooks/setup_databases.yml`, `cpf/database-template.cpf.j2`, `objectscript/create_databases.cos.j2` |
| Namespace setup | `playbooks/create_namespace.yml`, `cpf/namespace-template.cpf.j2` |
| Web app setup | `playbooks/setup_webapp.yml`, `objectscript/setup_webapp.cos.j2` |
| Security setup | `playbooks/setup_security.yml`, `objectscript/setup_security.cos.j2` |
| Production setup | `playbooks/setup_production.yml`, `objectscript/setup_production.cos.j2` |
| Mirror setup | `playbooks/setup_mirror.yml`, `objectscript/setup_mirror_primary.cos.j2`, `objectscript/setup_mirror_backup.cos.j2` |
| Node validation | `playbooks/validate_nodes.yml`, `objectscript/validate_readiness.cos.j2` |
| Mirror validation | `playbooks/validate_mirror.yml`, `objectscript/validate_mirror.cos.j2` |
| Shared helpers | `roles/iris_common/tasks/push_file.yml`, `roles/iris_common/tasks/iris_merge.yml`, `roles/iris_common/tasks/iris_session.yml` |
