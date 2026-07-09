/// Configuration for SecuritySync export/import paths and options.
/// All properties are overridable on the instance before calling Service methods.
Class SecuritySync.Config Extends %RegisteredObject
{

/// Path for roles export/import XML file
Property RolesPath As %String [ InitialExpression = "/tmp/iris_security_roles.xml" ];

/// Path for users export/import XML file
Property UsersPath As %String [ InitialExpression = "/tmp/iris_security_users.xml" ];

/// Include SQL privileges in export/import (Security.* Export/Import parameter)
Property IncludeSQLPrivileges As %Boolean [ InitialExpression = 0 ];

/// Default dry-run mode for imports (Flags=1 on Security.*.Import)
Property DryRun As %Boolean [ InitialExpression = 0 ];

/// Log verbosity: 0=quiet, 1=normal, 2=verbose
Property LogLevel As %Integer [ InitialExpression = 1 ];

/// Comma-separated required role names validated after import (empty = skip)
Property RequiredRoles As %String [ InitialExpression = "" ];

/// Comma-separated required user names validated after import (empty = skip)
Property RequiredUsers As %String [ InitialExpression = "" ];

/// Return a new Config with repository defaults.
ClassMethod Default() As SecuritySync.Config
{
    Quit ##class(SecuritySync.Config).%New()
}

}
