/// Façade for SecuritySync export/import orchestration.
/// Ansible entry point: invoke_security_sync.cos.j2 calls these ClassMethods.
/// Every public Run* method finishes with EmitResult → SECURITY_SYNC_JSON line
/// on stdout for playbook parsing (see docs/security-overview.md).
Class SecuritySync.Service Extends %RegisteredObject
{

ClassMethod BuildConfig() As SecuritySync.Config
{
    Quit ##class(SecuritySync.Config).Default()
}

ClassMethod BuildLogger(config As SecuritySync.Config) As SecuritySync.Logger
{
    Set logger=##class(SecuritySync.Logger).%New()
    Set logger.Level = config.LogLevel
    Quit logger
}

/// Write machine-readable result for Ansible (single line, prefix SECURITY_SYNC_JSON:).
ClassMethod EmitResult(result As SecuritySync.Result)
{
    Write !,"SECURITY_SYNC_JSON:"_result.ToJSON()
}

/// Primary-side export: roles XML then users XML via official Security.* Export APIs.
/// Populates result.RolesExported / UsersExported; fails fast on first error.
ClassMethod RunExport(config As SecuritySync.Config = "") As SecuritySync.Result
{
    If config="" Set config=..BuildConfig()
    Set result=##class(SecuritySync.Result).%New()
    Set logger=..BuildLogger(config)
    Set sc=##class(SecuritySync.Exporter).Run(config,result,logger)
    If '$SYSTEM.Status.IsOK(sc) {
        Set result.OK = 0
    }
    Do ..EmitResult(result)
    Quit result
}

/// Backup-side real import (Flags=0). Runs Validator after successful import.
ClassMethod RunImport(config As SecuritySync.Config = "") As SecuritySync.Result
{
    If config="" Set config=..BuildConfig()
    Set result=##class(SecuritySync.Result).%New()
    Set logger=..BuildLogger(config)
    Set sc=##class(SecuritySync.Importer).Run(config,result,logger,0)
    If '$SYSTEM.Status.IsOK(sc) {
        Set result.OK = 0
    } Else {
        Do ##class(SecuritySync.Validator).ValidatePostImport(config,result)
    }
    Do ..EmitResult(result)
    Quit result
}

/// Backup-side dry-run (Import Flags=1) — validates files and counts without mutating IRISSECURITY.
ClassMethod DryRunImport(config As SecuritySync.Config = "") As SecuritySync.Result
{
    If config="" Set config=..BuildConfig()
    Set result=##class(SecuritySync.Result).%New()
    Set logger=..BuildLogger(config)
    Set sc=##class(SecuritySync.Importer).Run(config,result,logger,1)
    If '$SYSTEM.Status.IsOK(sc) {
        Set result.OK = 0
    }
    Do ..EmitResult(result)
    Quit result
}

/// Export on this node then import (single-node helper; mirror sync uses Ansible file transfer instead).
ClassMethod RunSync(config As SecuritySync.Config = "") As SecuritySync.Result
{
    If config="" Set config=..BuildConfig()
    Set exportResult=..RunExport(config)
    If 'exportResult.IsOK() {
        Quit exportResult
    }
    Quit ..RunImport(config)
}

/// Read-only validation: required roles/users from config + live counts via Export API.
/// Used by validate_security_sync.yml on all nodes.
ClassMethod RunValidate(config As SecuritySync.Config = "") As SecuritySync.Result
{
    If config="" Set config=..BuildConfig()
    Set result=##class(SecuritySync.Result).%New()
    Do ##class(SecuritySync.Validator).ValidatePostImport(config,result)
    Set result.Step = "validate"
    Do ..EmitResult(result)
    Quit result
}

/// E2E demo helper: deliberate primary-only delta before export/sync.
/// Creates SYNC_TEST_ROLE and sync_test_user; bumps TRAINING_APP description timestamp.
ClassMethod CreateTestDelta() As SecuritySync.Result
{
    Set result=##class(SecuritySync.Result).%New()
    Set result.Step = "create_test_delta"
    If '##class(Security.Roles).Exists("SYNC_TEST_ROLE") {
        Set sc=##class(Security.Roles).Create("SYNC_TEST_ROLE","E2E security sync test role","")
        If '$SYSTEM.Status.IsOK(sc) {
            Do result.AddError("create SYNC_TEST_ROLE: "_$SYSTEM.Status.GetErrorText(sc))
            Do ..EmitResult(result)
            Quit result
        }
        Write !,"CREATED ROLE SYNC_TEST_ROLE"
    } Else {
        Write !,"EXISTS ROLE SYNC_TEST_ROLE"
    }
    If '##class(Security.Users).Exists("sync_test_user") {
        Set sc=##class(Security.Users).Create("sync_test_user","E2E sync test user","SyncTestOnly!", "SYNC_TEST_ROLE")
        If '$SYSTEM.Status.IsOK(sc) {
            Do result.AddError("create sync_test_user: "_$SYSTEM.Status.GetErrorText(sc))
            Do ..EmitResult(result)
            Quit result
        }
        Write !,"CREATED USER sync_test_user"
    } Else {
        Write !,"EXISTS USER sync_test_user"
    }
    If ##class(Security.Roles).Exists("TRAINING_APP") {
        Kill props
        Set props("Description")="TRAINING sync delta "_$ZDATETIME($HOROLOG,3)
        Set sc=##class(Security.Roles).Modify("TRAINING_APP",.props)
        If '$SYSTEM.Status.IsOK(sc) {
            Do result.AddError("modify TRAINING_APP: "_$SYSTEM.Status.GetErrorText(sc))
        } Else {
            Write !,"UPDATED ROLE TRAINING_APP description"
        }
    }
    Set result.Step = "create_test_delta_complete"
    Do ..EmitResult(result)
    Quit result
}

}
