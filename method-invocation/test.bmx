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

SuperStrict

'buildopt:threads

Import "method-invoker.bmx"

Type Foobar
	Method Wibble:Int( x:Int, y:Float, z:Object[] )
		Print "Wimbleton "+x+" "+y
		For Local i:Object = EachIn z
			Print i.ToString()
		Next
		Return 50
	End Method
	
	Method ToString$()
		Return "Executive Order"
	End Method
End Type

Type Blabber
	Method Wibble( x:Int, y:Float, z:Object[] )
		Print "Nope, no go for you, sonny"
	End Method
End Type


Local invoker:CMethodInvocation


Local wibble_meth:TMethod = TTypeID.ForName("Foobar").FindMethod("Wibble")
'invoker = New CMethodInvocation.InitWithMethod(wibble_meth)

' or for specifying something without getting an actual definition
invoker = New CMethodInvocation..
				.InitWithNamedMethod("Wibble", ..
									[IntTypeID,FloatTypeID,ObjectTypeID], ..
									IntTypeID)

' set arguments
invoker.SetIntArgument(256, 1)
invoker.SetFloatArgument(123.456, 2)
invoker.SetObjectArgument(["x", "y", "z"], 3)

' set target and invoke
invoker.SetTarget(New Foobar)
invoker.Invoke()

' print returned value
Print invoker.ReturnedInt()

' switch object types and invoke
invoker.SetTarget(New Blabber)
invoker.Invoke()

' copy invoker..
invoker = invoker.Copy()
invoker.Invoke()

' get return value
Print invoker.ReturnedInt()
