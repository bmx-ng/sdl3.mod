SuperStrict

' Unlike Assert, this check also runs in release builds.
Function Check(condition:Int, message:String = "Test condition failed")
	If Not condition Then Throw message
End Function

Function Check(value:Object, message:String = "Test object is null")
	If Not value Then Throw message
End Function
