/// Export roles and users via official Security.* Export APIs (fail fast).
/// Called from SecuritySync.Service.RunExport on the mirror primary only.
/// Writes XML to config.RolesPath / UsersPath for Ansible fetch → backup import.
Class SecuritySync.Exporter Extends %RegisteredObject
{

/// Export all roles then all users ("*" selector). Sets result.RolesExported / UsersExported.
ClassMethod Run(config As SecuritySync.Config, result As SecuritySync.Result, logger As SecuritySync.Logger) As %Status
{
    Set result.Step = "export"
    Do logger.SetStep("export")
    Do logger.Log(1,"Exporting roles to "_config.RolesPath)
    Set numRoles=0, numSQLRoles=0
    Set sc=##class(Security.Roles).Export(config.RolesPath,.numRoles,"*","*",config.IncludeSQLPrivileges,.numSQLRoles)
    If '##class(SecuritySync.Util).CheckStatus(sc,result,"roles_export") {
        Quit sc
    }
    Set result.RolesExported = numRoles
    Do logger.Log(1,"Roles exported: "_numRoles)
    Do logger.SetStep("export_users")
    Do logger.Log(1,"Exporting users to "_config.UsersPath)
    Set numUsers=0, numSQLUsers=0
    Set sc=##class(Security.Users).Export(config.UsersPath,.numUsers,"*","*",config.IncludeSQLPrivileges,.numSQLUsers)
    If '##class(SecuritySync.Util).CheckStatus(sc,result,"users_export") {
        Quit sc
    }
    Set result.UsersExported = numUsers
    Do logger.Log(1,"Users exported: "_numUsers)
    Set result.Step = "export_complete"
    Quit $$$OK
}

}
