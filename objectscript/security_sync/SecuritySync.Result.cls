/// Structured result for SecuritySync operations.
/// Serialized by ToJSON() and emitted as one stdout line:
///   SECURITY_SYNC_JSON:{...}
/// Ansible playbooks regex-select that line and parse with from_json.
Class SecuritySync.Result Extends %RegisteredObject
{

/// false when any AddError was called or upstream status failed.
Property OK As %Boolean [ InitialExpression = 1 ];

/// Pipeline step name (export, import_complete, validate, create_test_delta, etc.).
Property Step As %String [ InitialExpression = "" ];

/// true when Importer ran with dryRun=1 (Flags=1).
Property DryRun As %Boolean [ InitialExpression = 0 ];

/// Count from primary Security.Roles.Export (export play).
Property RolesExported As %Integer [ InitialExpression = 0 ];

/// Count from primary Security.Users.Export (export play).
Property UsersExported As %Integer [ InitialExpression = 0 ];

/// Count from Security.Roles.Import on backup (import / dry-run play).
Property RolesImported As %Integer [ InitialExpression = 0 ];

/// Count from Security.Users.Import on backup (import / dry-run play).
Property UsersImported As %Integer [ InitialExpression = 0 ];

/// Live role count on this node after import (Validator CountViaExport).
Property RoleCount As %Integer [ InitialExpression = -1 ];

/// Live user count on this node after import (Validator CountViaExport).
Property UserCount As %Integer [ InitialExpression = -1 ];

/// Human-readable error messages; also sets OK=0 when populated via AddError.
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

/// JSON field names match ansible-runbook / security-overview expected markers
/// (ok, roles_imported, users_imported, role_count, user_count, errors, ...).
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
