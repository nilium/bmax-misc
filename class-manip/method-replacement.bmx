Rem
Copyright (c) 2009 Noel R. Cower

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
EndRem

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

Function ReplaceMethod@ Ptr( _method:String, inClass:String, with@ Ptr, searchSuperTypes:Int = False )
	Local result@ Ptr = Null
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
		
		Local mp@ Ptr Ptr = Byte Ptr Ptr(Byte Ptr(class)+decl.opaque)
		result = mp[0]
		mp[0] = with
		
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

Local oldMethod:String( obj:Object )
oldMethod = ReplaceMethod( "ToString", "Foobar", newToString, False )

Print "New method: "+foo.ToString()
Print "Old method: "+oldMethod( foo )

Function newToString:String( _self:Foobar )
	Return "Foo._name = "+_self._name
End Function
