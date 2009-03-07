Strict

Import "class-manip.bmx"

Type Foobar
	Field _name$
	
	Method setName( n$ )
		_name = n
	End Method
	
	Method ToString$()
		Return "Normal"
	End Method
End Type

Local foo:Foobar = New Foobar

Local scope:DebugScope = DebugScope.ForName("Foobar")
scope.Spit()

Local decl:DebugDecl = scope.DeclForName("ToString", DECL_TYPEMETHOD)

Print foo.ToString()
foo.setName("razzledazzlerootbeer")

' Methods are located at class+offset, so modify the method there
Local methPtr:Byte Ptr Ptr = (Byte Ptr Ptr(Int(scope._class)+decl.opaque))
methPtr[0] = newToString

Print foo.ToString()

Function newToString:String( _self:Foobar )
	Print "Foo._name = "+_self._name
End Function
