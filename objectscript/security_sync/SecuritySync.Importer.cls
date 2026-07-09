/// Import roles then users via official Security.* Import APIs (fail fast).
Class SecuritySync.Importer Extends %RegisteredObject
{

ClassMethod Run(config As SecuritySync.Config, result As SecuritySync.Result, logger As SecuritySync.Logger, dryRun As %Boolean = 0) As %Status
{
    Set result.DryRun = dryRun
    Set flags=$SELECT(dryRun=1:1,1:0)
    Set result.Step = $SELECT(dryRun=1:"dry_run_import",1:"import")
    Do logger.SetStep(result.Step)
    If '##class(SecuritySync.Validator).ValidateFiles(config,result) {
        Quit $$$ERROR($$$GeneralError,"Security sync file validation failed")
    }
    Do logger.Log(1,$SELECT(dryRun=1:"Dry-run importing",1:"Importing")_" roles from "_config.RolesPath)
    Set numRoles=0, numSQLRoles=0
    Set sc=##class(Security.Roles).Import(config.RolesPath,.numRoles,flags,.numSQLRoles)
    If '##class(SecuritySync.Util).CheckStatus(sc,result,"roles_import") {
        Quit sc
    }
    Set result.RolesImported = numRoles
    Do logger.Log(1,"Roles "_$SELECT(dryRun=1:"validated",1:"imported")_": "_numRoles)
    Do logger.SetStep($SELECT(dryRun=1:"dry_run_import_users",1:"import_users"))
    Do logger.Log(1,$SELECT(dryRun=1:"Dry-run importing",1:"Importing")_" users from "_config.UsersPath)
    Set numUsers=0, numSQLUsers=0
    Set sc=##class(Security.Users).Import(config.UsersPath,.numUsers,flags,.numSQLUsers)
    If '##class(SecuritySync.Util).CheckStatus(sc,result,"users_import") {
        Quit sc
    }
    Set result.UsersImported = numUsers
    Do logger.Log(1,"Users "_$SELECT(dryRun=1:"validated",1:"imported")_": "_numUsers)
    Set result.Step = $SELECT(dryRun=1:"dry_run_import_complete",1:"import_complete")
    Quit $$$OK
}

}
