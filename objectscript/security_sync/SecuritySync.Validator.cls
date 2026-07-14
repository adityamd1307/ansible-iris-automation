/// Pre/post validation for SecuritySync export/import files and state.
Class SecuritySync.Validator Extends %RegisteredObject
{

/// Verify export/import XML files exist before import.
ClassMethod ValidateFiles(config As SecuritySync.Config, result As SecuritySync.Result) As %Boolean
{
    Set ok=1
    Set ok=..ValidateOneFile(config.RolesPath,"roles",result)&&ok
    Set ok=..ValidateOneFile(config.UsersPath,"users",result)&&ok
    If 'ok {
        Set result.Step = "validate_files"
    }
    Quit ok
}

ClassMethod ValidateOneFile(path As %String, label As %String, result As SecuritySync.Result) As %Boolean
{
    If '##class(%Library.File).Exists(path) {
        Do result.AddError("Missing "_label_" XML file: "_path)
        Quit 0
    }
    Quit 1
}

/// Assert required roles/users exist after import; populate counts via Export API.
ClassMethod ValidatePostImport(config As SecuritySync.Config, result As SecuritySync.Result) As %Boolean
{
    Set result.Step = "validate_post_import"
    Set ok=1
    Set result.RoleCount = ..CountViaExport("roles")
    Set result.UserCount = ..CountViaExport("users")
    Set ok=..ValidateRequiredList(config.RequiredRoles,"role",result)&&ok
    Set ok=..ValidateRequiredList(config.RequiredUsers,"user",result)&&ok
    If 'ok {
        Set result.OK = 0
    }
    Quit ok
}

ClassMethod ValidateRequiredList(list As %String, kind As %String, result As SecuritySync.Result) As %Boolean
{
    If list="" {
        Quit 1
    }
    Set ok=1
    Set i=0
    For {
        Set item=$PIECE(list,",",i+1)
        Quit:item=""
        Set i=i+1
        If kind="role" {
            If '##class(Security.Roles).Exists(item) {
                Do result.AddError("Required role missing: "_item)
                Set ok=0
            }
        } Else {
            If '##class(Security.Users).Exists(item) {
                Do result.AddError("Required user missing: "_item)
                Set ok=0
            }
        }
    }
    Quit ok
}

/// Return live role/user count using the official Export API (count-only temp file).
ClassMethod CountViaExport(kind As %String) As %Integer
{
    Set num=0
    Set file="/tmp/security_sync_count.xml"
    If kind="roles" {
        Set sc=##class(Security.Roles).Export(file, .num, "*")
    } Else {
        Set sc=##class(Security.Users).Export(file, .num, "*")
    }
    If ##class(%Library.File).Exists(file) {
        Do ##class(%Library.File).Delete(file)
    }
    If $SYSTEM.Status.IsOK(sc) {
        Quit num
    }
    Quit -1
}

}
