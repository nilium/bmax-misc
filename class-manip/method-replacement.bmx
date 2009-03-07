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

Function ReplaceMethod( _method:String, inClass:String, with@ Ptr, searchSuperTypes:Int = False )
	Local result:Int = False
	Local scope:DebugScope = DebugScope.ForName(inClass)
	Local class:Int Ptr = Int Ptr scope._class
	While scope And class
		Local decl:DebugDecl = scope.DeclForName(_method, DECL_TYPEMETHOD)
		
		If decl = Null And searchSuperTypes Then
			class = Int Ptr class[0]
			scope = DebugScope.ForClass(class)
			Continue
		ElseIf decl = Null
			scope = Null
			class = Null
			Exit
		EndIf
		
		Byte Ptr Ptr(Byte Ptr(class)+decl.opaque)[0] = with
		result = True
		
		scope = Null
		class = Null
	Wend
	
	Return result
End Function

Local foo:Foobar = New Foobar

Local scope:DebugScope = DebugScope.ForName("Foobar")
scope.Spit()

Local decl:DebugDecl = scope.DeclForName("ToString", DECL_TYPEMETHOD)

Print foo.ToString()
foo.setName("razzledazzlerootbeer")

' Methods are located at class+offset, so modify the method there
ReplaceMethod( "ToString", "Foobar", newToString, False )

Print foo.ToString()

Function newToString:String( _self:Foobar )
	Print "Foo._name = "+_self._name
End Function
