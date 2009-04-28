SuperStrict

Import Brl.Map

Public

Function MapWithKeysAndValues:TMap( keys:Object[], values:Object[] )
	If keys.Length <> values.Length Then
		Throw New TArrayBoundsException
	EndIf
	Local map:TMap = New TMap
	For Local idx:Int = 0 Until keys.Length
		map.Insert(keys[idx], values[idx])
	Next
	Return map
End Function
