/// Shared helpers for SecuritySync modules.
Class SecuritySync.Util Extends %RegisteredObject
{

/// Return $SYSTEM.Status.GetErrorText(status) or empty string when OK.
ClassMethod ErrorText(status As %Status) As %String
{
    If $SYSTEM.Status.IsOK(status) {
        Quit ""
    }
    Quit $SYSTEM.Status.GetErrorText(status)
}

/// Quit with status when not OK; otherwise return 1.
ClassMethod CheckStatus(status As %Status, result As SecuritySync.Result, step As %String) As %Boolean
{
    If $SYSTEM.Status.IsOK(status) {
        Quit 1
    }
    Do result.AddError(step_": "_$SYSTEM.Status.GetErrorText(status))
    Set result.Step = step
    Quit 0
}

}
