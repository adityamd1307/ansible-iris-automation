/// Runtime configuration for SecuritySync export/import.
/// Populated from invoke_security_sync.cos.j2 (paths, SQL flag, required lists from Ansible inventory).
/// Override properties on the instance before calling SecuritySync.Service methods.
Class SecuritySync.Config Extends %RegisteredObject
{

/// Roles export/import XML path on the IRIS node (default matches sync_security.yml).
Property RolesPath As %String [ InitialExpression = "/tmp/iris_security_roles.xml" ];

/// Users export/import XML path on the IRIS node.
Property UsersPath As %String [ InitialExpression = "/tmp/iris_security_users.xml" ];

/// Pass through to Security.Roles/Users Export/Import IncludeSQLPrivileges parameter.
Property IncludeSQLPrivileges As %Boolean [ InitialExpression = 0 ];

/// When true, Importer uses Import Flags=1 (dry-run). Ansible usually sets action dry_run_import instead.
Property DryRun As %Boolean [ InitialExpression = 0 ];

/// Logger verbosity: 0=quiet, 1=normal, 2=verbose.
Property LogLevel As %Integer [ InitialExpression = 1 ];

/// Comma-separated role names that must exist after import/validate (from security_sync_required_roles).
/// Empty string skips required-role checks.
Property RequiredRoles As %String [ InitialExpression = "" ];

/// Comma-separated user names that must exist after import/validate (from security_sync_required_users).
Property RequiredUsers As %String [ InitialExpression = "" ];

/// Factory with repository defaults; invoke script overrides paths and required lists.
ClassMethod Default() As SecuritySync.Config
{
    Quit ##class(SecuritySync.Config).%New()
}

}
