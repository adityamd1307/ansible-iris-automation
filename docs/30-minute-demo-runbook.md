# 30-Minute Demo Runbook - IRIS Automation + Mirroring

This runbook is a presenter script for a 30-minute walkthrough of the
local Docker/Ansible IRIS topology:

- `irisa` as the primary mirror member
- `irisb` as the backup mirror member
- `TRAINING` namespace
- `TRAININGDATA` and `TRAININGCODE` mirrored databases
- Web Gateway access through `8081` and `8082`

Use WSL/Ubuntu on Windows for the Ansible commands.

```bash
cd /mnt/c/Users/adhaded/Desktop/iris-automation
export ANSIBLE_CONFIG=ansible.cfg
export INV=inventories/poc
```

## Demo Goals

By the end of the demo, the audience should understand:

- how the desired state is defined per environment
- how `configure.yml` applies that state in order
- why CPF merge and ObjectScript are both used
- how the mirror is created and validated
- how to verify the result in the Management Portal
- how to prove that new SQL changes on `irisa` replicate to `irisb`

For a deeper file-by-file explanation of the code behind this demo, see
`docs/configure-flow-explained.md`.

## 0. Pre-Demo Checklist - Before The Call

Do this before the 30-minute slot starts.

```bash
docker compose ps
$ANSIBLE_CONFIG ansible --version
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/validate_mirror.yml -i $INV
```

Expected container state:

```text
irisa       Up / healthy
irisb       Up / healthy
webgatewaya Up / healthy
webgatewayb Up / healthy
haproxy     Up
arbiter     Up / healthy
```

Expected mirror validation:

```text
irisa is_primary: true
irisb is_backup: true
failed=0
```

Portal URLs:

```text
IRISA primary: http://localhost:8081/csp/sys/UtilHome.csp
IRISB backup:  http://localhost:8082/csp/sys/UtilHome.csp
```

Login:

```text
_SYSTEM / SYS
```

Avoid `8080` for the demo unless you specifically want to show HAProxy.
For admin checks, use `8081` and `8082` so the node identity is clear.

## 1. Opening - 2 Minutes

Say:

> This demo shows repeatable IRIS environment automation using Docker
> Compose for runtime topology and Ansible for configuration. We will
> converge two IRIS containers into a primary/backup mirror, then prove
> the mirror from both CLI validation and the Management Portal.

Show the topology:

```text
irisa  -> IRIS primary
irisb  -> IRIS backup
webgatewaya -> routes to irisa, exposed on 8081
webgatewayb -> routes to irisb, exposed on 8082
arbiter -> available on 21883
haproxy -> exposed on 8080
```

## 2. Show Desired State - 4 Minutes

Open:

```text
inventories/poc/group_vars/all.yml
```

Point out:

```yaml
namespace: TRAINING
globals_db: TRAININGDATA
routines_db: TRAININGCODE
mirror_enabled: true
mirror_name: TRAININGMIRROR
mirror_databases:
  - "{{ globals_db }}"
  - "{{ routines_db }}"
```

Say:

> The important design choice is that the environment is data-driven.
> The same playbooks can target `poc`, `dev`, `sit`, or `uat` by changing
> the inventory path.

Mention:

- mirror names must be alphanumeric, so `TRAININGMIRROR` is valid
- secrets are not stored here
- `vault.example.yml` is only a shape/template

## 3. Explain The Master Workflow - 4 Minutes

Open:

```text
playbooks/configure.yml
```

Explain the order:

```yaml
- import_playbook: setup_databases.yml
- import_playbook: create_namespace.yml
- import_playbook: setup_webapp.yml
- import_playbook: setup_security.yml
- import_playbook: setup_production.yml
- import_playbook: setup_mirror.yml
- import_playbook: validate_nodes.yml
- import_playbook: validate_mirror.yml
```

Say:

> The order matters. Databases must exist before the namespace maps to
> them. The namespace and web application must exist before validation.
> Mirror setup happens after the databases and namespace are ready, then
> validation proves the final state.

Explain mechanisms:

- CPF merge: declarative IRIS configuration such as databases and namespace mappings
- guarded ObjectScript: runtime objects such as physical databases, web apps, services, roles, and mirror operations
- validation scripts: read-only ObjectScript that emits JSON for Ansible assertions

## 4. Run Full Configuration - 5 Minutes

Run:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/configure.yml -i $INV
```

Narrate the output as it runs:

```text
ok       means the task completed
changed  means Ansible applied or re-applied configuration
skipping means the other execution mode was skipped
failed=0 is the key final result
```

Call out expected warnings:

```text
Found variable using reserved name 'namespace'
```

Say:

> This warning is not fatal. It means Ansible has an internal term named
> `namespace`. The playbook still works. A cleanup improvement would be
> renaming that variable to `iris_namespace`.

Call out expected production output:

```text
SKIP interop-not-enabled-or-missing-class: <CLASS DOES NOT EXIST> Ens.Director
```

Say:

> This image does not expose the Interoperability production class in
> the `TRAINING` namespace, so production auto-start is skipped. That is
> separate from database mirroring, which is configured and validated.

Expected final recap:

```text
failed=0
```

## 5. Explain Database And Namespace Output - 3 Minutes

Use these output markers:

```text
EXISTS TRAININGDATA /usr/irissys/mgr/trainingdata
EXISTS TRAININGCODE /usr/irissys/mgr/trainingcode
RESEXISTS %DB_TRAININGDATA
RESEXISTS %DB_TRAININGCODE
BOUNDALREADY TRAININGDATA
BOUNDALREADY TRAININGCODE
```

Say:

> The CPF merge registers database definitions. The guarded ObjectScript
> creates the actual physical IRIS.DAT files and binds database security
> resources. That prevents the namespace from pointing at a non-mountable
> database.

For namespace:

```text
IRIS Merge of /tmp/namespace-merge.cpf into /iris-shared/durable/iris.cpf
IRIS Merge completed successfully
```

Say:

> The `TRAINING` namespace maps globals to `TRAININGDATA` and routines
> to `TRAININGCODE`.

## 6. Explain Mirror Output - 4 Minutes

Open:

```text
playbooks/setup_mirror.yml
objectscript/setup_mirror_primary.cos.j2
objectscript/setup_mirror_backup.cos.j2
```

Primary output should include:

```text
EXISTS MIRROR MEMBER type=Failover
EXISTS MIRROR STARTED TRAININGMIRROR
EXISTS PRIMARY
EXISTS FAILOVER irisb
EXISTS DATABASE TRAININGDATA
EXISTS DATABASE TRAININGCODE
```

Backup output should include:

```text
EXISTS MIRROR MEMBER type=Failover
EXISTS MIRROR STARTED TRAININGMIRROR
PRIMARY JOURNAL POSITION ...
EXISTS DATABASE TRAININGDATA
EXISTS DATABASE TRAININGCODE
```

Say:

> Primary setup creates or confirms the mirror set, starts it, confirms
> `irisa` is primary, adds `irisb` as the failover member, and adds the
> databases to the mirror. Backup setup joins or confirms membership and
> registers the non-primary database copies so new changes replicate.

Important note:

> If you create a table before the backup databases are active in the
> mirror, that old DDL may not appear on `irisb`. After `configure.yml`
> has completed successfully, create new test tables or rows on `irisa`;
> those changes should replicate to `irisb`.

## 7. Management Portal Verification - 5 Minutes

Open both portal URLs:

```text
IRISA primary: http://localhost:8081/csp/sys/UtilHome.csp
IRISB backup:  http://localhost:8082/csp/sys/UtilHome.csp
```

### Check Namespace

Go to:

```text
System Administration > Configuration > System Configuration > Namespaces
```

Verify:

```text
TRAINING
```

Open it and confirm:

```text
Globals database:  TRAININGDATA
Routines database: TRAININGCODE
```

### Check Databases

Go to:

```text
System Administration > Configuration > System Configuration > Local Databases
```

Verify:

```text
TRAININGDATA
TRAININGCODE
```

### Check Mirror

Go to:

```text
System Administration > Configuration > Mirror Settings
```

On `8081`:

```text
This member is IRISA
This member is the primary
```

On `8082`:

```text
This member is IRISB
This member is the backup
```

Verify the mirror member table:

```text
IRISA Failover
IRISB Failover
Mirror name TRAININGMIRROR
```

Notes:

- SSL/TLS warning is expected for this local POC.
- `arping command is missing` only matters if Virtual IP is enabled.
- If `Use Arbiter` is unchecked, that means the arbiter container is up
  but not configured into the mirror settings. The mirror still has a
  working primary/backup pair.

## 8. Portal-Based Replication Test - 3 Minutes

Use the SQL page in the portal.

On `IRISA` at `8081`, switch namespace to:

```text
TRAINING
```

Run:

```sql
CREATE TABLE SQLUser.DemoMirrorTest (
  ID INTEGER IDENTITY PRIMARY KEY,
  Note VARCHAR(100),
  CreatedAt TIMESTAMP
)
```

Then:

```sql
INSERT INTO SQLUser.DemoMirrorTest (Note, CreatedAt)
VALUES ('created on IRISA primary during demo', CURRENT_TIMESTAMP)
```

Then:

```sql
SELECT * FROM SQLUser.DemoMirrorTest
```

On `IRISB` at `8082`, switch namespace to:

```text
TRAINING
```

Run:

```sql
SELECT * FROM SQLUser.DemoMirrorTest
```

Expected:

```text
The row created on IRISA appears on IRISB.
```

Optional negative test on `IRISB`:

```sql
INSERT INTO SQLUser.DemoMirrorTest (Note, CreatedAt)
VALUES ('attempted write on backup', CURRENT_TIMESTAMP)
```

Expected:

```text
The write should fail or be rejected because the backup mirrored DB is read-only.
```

## 9. CLI Verification - 2 Minutes

Run:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/validate_mirror.yml -i $INV
```

Expected JSON:

```text
irisa:
  is_mirror_member: true
  is_primary: true
  is_backup: false

irisb:
  is_mirror_member: true
  is_primary: false
  is_backup: true
```

Expected recap:

```text
failed=0
```

## 10. Close - 1 Minute

Say:

> The demo proves that a single Ansible command converges IRIS database,
> namespace, web app, security, and mirror state. The Management Portal
> confirms `irisa` is primary and `irisb` is backup, and the SQL test
> proves new data changes replicate from primary to backup.

## Quick Presenter Script

Use this as spoken narration.

> We start with a Docker Compose topology: two IRIS containers, two web
> gateways, HAProxy, and an arbiter container. Docker is the runtime
> source of truth, and Ansible configures the IRIS state.

> The desired state lives in `inventories/poc/group_vars/all.yml`. Here
> we define the `TRAINING` namespace, the `TRAININGDATA` and
> `TRAININGCODE` databases, and the mirror name `TRAININGMIRROR`.

> `configure.yml` is the master flow. It creates database definitions,
> creates physical databases, maps the namespace, configures web apps and
> security, configures mirroring, and then validates everything.

> The reason we use both CPF and ObjectScript is practical. CPF is good
> for declarative configuration like database and namespace definitions.
> ObjectScript is needed for runtime objects and guarded operations:
> physical database creation, CSP applications, security resources, and
> mirror APIs.

> The mirror setup is idempotent. On rerun, it says `EXISTS MIRROR
> MEMBER`, `EXISTS PRIMARY`, and `EXISTS DATABASE`, rather than creating
> duplicates.

> In the portal, `8081` shows `IRISA` as primary and `8082` shows `IRISB`
> as backup. We use direct gateway ports to avoid HAProxy switching nodes
> during admin checks.

> Finally, we create a SQL table and row on the primary. Then we query it
> from the backup. That proves actual data replication, not just
> configuration.

## Possible Q&A

### Why do we use WSL instead of native PowerShell?

Ansible expects a UTF-8 shell. Native Windows PowerShell can report code
page 1252 and fail before running the playbook. WSL/Ubuntu avoids that.

### Why is there a warning about `namespace` being reserved?

The variable name `namespace` overlaps with an Ansible internal concept.
It is a warning, not a failure. A future cleanup could rename it to
`iris_namespace`.

### Why do some tasks show `changed` even when the system is already configured?

Some IRIS CPF merges report as changed because the merge operation ran
successfully. The important part is that guarded ObjectScript emits
`EXISTS` markers and validation ends with `failed=0`.

### Why are there many `USER>` and `%SYS>` lines in the output?

Those are IRIS terminal prompts. Ansible feeds ObjectScript into
`iris session`, and IRIS echoes prompt transitions.

### Why does production auto-start skip?

The current IRIS image does not expose `Ens.Director` in the `TRAINING`
namespace. The namespace, databases, and mirroring work; Interoperability
production startup is separate and requires an interop-enabled image or
namespace.

### Why did an old table not appear on the backup?

It was created before the backup databases were registered as active
mirrored copies. After `configure.yml` completes successfully, create a
new table or recreate the old table on `irisa`; new changes replicate to
`irisb`.

### Why use `8081` and `8082` instead of `8080`?

`8080` goes through HAProxy and can route requests to either gateway.
For admin verification, direct ports make the node identity clear:
`8081` is `irisa`, `8082` is `irisb`.

### Why is SSL/TLS not enabled for the mirror?

This is a local POC. The portal warning is valid: production mirrors
should use SSL/TLS. The demo focuses on automation and replication.

### Why is Virtual IP not enabled?

Virtual IP requires extra OS/network support. The portal warning about
`arping` only matters if Virtual IP is enabled. This local Docker POC
uses direct container and gateway addressing instead.

### Is the arbiter used?

The arbiter container is running and reachable. If the portal shows
`Use Arbiter` unchecked, the current mirror is a primary/backup pair
without the arbiter configured into mirror settings. That can be added
as a hardening step.

### How do we prove idempotency?

Run:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/configure.yml -i inventories/poc
```

again. The run should complete with `failed=0` and show `EXISTS` markers
instead of duplicate creation.

### How do we prove failover?

First prove normal replication. Then, as an advanced test, stop `irisa`
and promote/check `irisb` in the portal. This changes mirror state and
may require cleanup or rejoin, so do it after the main demo.

```bash
docker stop irisa
docker start irisa
```

### What is the main takeaway?

One command converges the environment:

```bash
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/configure.yml -i inventories/poc
```

The portal and validation prove:

```text
TRAINING namespace exists
TRAININGDATA and TRAININGCODE exist
IRISA is primary
IRISB is backup
new SQL changes replicate from IRISA to IRISB
```
