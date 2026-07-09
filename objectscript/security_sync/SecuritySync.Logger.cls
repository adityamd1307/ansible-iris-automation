/// Timestamped step logging for SecuritySync operations.
Class SecuritySync.Logger Extends %RegisteredObject
{

Property Level As %Integer [ InitialExpression = 1 ];

Property Step As %String;

Method Log(level As %Integer, message As %String)
{
    If level > ..Level {
        Quit
    }
    Set ts=$ZDATETIME($HOROLOG,3)
    Write !,"[SecuritySync ",ts," ",..Step,"] ",message
}

Method SetStep(step As %String)
{
    Set ..Step = step
}

}
