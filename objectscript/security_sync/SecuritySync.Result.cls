/// Structured result object emitted as SECURITY_SYNC_JSON by Service methods.
Class SecuritySync.Result Extends %RegisteredObject
{

Property OK As %Boolean [ InitialExpression = 1 ];

Property Step As %String [ InitialExpression = "" ];

Property DryRun As %Boolean [ InitialExpression = 0 ];

Property RolesExported As %Integer [ InitialExpression = 0 ];

Property UsersExported As %Integer [ InitialExpression = 0 ];

Property RolesImported As %Integer [ InitialExpression = 0 ];

Property UsersImported As %Integer [ InitialExpression = 0 ];

Property RoleCount As %Integer [ InitialExpression = -1 ];

Property UserCount As %Integer [ InitialExpression = -1 ];

Property Errors As list Of %String;

Method %OnNew() As %Status
{
    Set ..Errors = ##class(%ListOfDataTypes).%New()
    Quit $$$OK
}

Method IsOK() As %Boolean
{
    Quit ..OK
}

Method AddError(msg As %String)
{
    Do ..Errors.Insert(msg)
    Set ..OK = 0
}

Method ToJSON() As %String
{
    Set q=$CHAR(34)
    Set j="{"
    Set j=j_q_"ok"_q_":"_$SELECT(..OK:"true",1:"false")_","
    Set j=j_q_"step"_q_":"_q_..Step_q_","
    Set j=j_q_"dry_run"_q_":"_$SELECT(..DryRun:"true",1:"false")_","
    Set j=j_q_"roles_exported"_q_":"_..RolesExported_","
    Set j=j_q_"users_exported"_q_":"_..UsersExported_","
    Set j=j_q_"roles_imported"_q_":"_..RolesImported_","
    Set j=j_q_"users_imported"_q_":"_..UsersImported_","
    Set j=j_q_"role_count"_q_":"_..RoleCount_","
    Set j=j_q_"user_count"_q_":"_..UserCount_","
    Set j=j_q_"errors"_q_":["
    Set first=1
    For i=1:1:..Errors.Count() {
        Set err=..Errors.GetAt(i)
        Set err=$REPLACE(err,q,"\"_q)
        If 'first Set j=j_","
        Set j=j_q_err_q
        Set first=0
    }
    Set j=j_"]}"
    Quit j
}

}
