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

Function genToString(ob@ Ptr)
	Print "Razzleberry"
End Function

Function GenCons(ob:Object)
	Print "Constructor called"
'	ob[0] = Int genClass.Class
End Function

Function GenDest(ob:Object)
	Print "Destructor called"
'	ob[0] = 0
End Function

Local scope:DebugScope = DebugScope.ForName("IClass")
scope.Spit()
Global genClass:IClass
Local c:IClass = New IClass
genClass = c

c.Name = "GenericClass"
c.SuperClass = ObjectTypeId
c.AddField("_name", StringTypeId)
c.AddMethod("New", genCons)
c.AddMethod("Delete", genDest)
c.AddMethod("ToString", genToString, StringTypeId)
c.BuildClass()
c.RegisterClass()

scope = DebugScope.ForClass(c.Class)
scope.Spit()

c.GenerateTypeId()
'DebugStop
Local t:TTypeId = TTypeId.ForName("DebugScope")
Print "Type: "+t.Name()

Local boo:Object = t.NewObject()
'Print "Object created"
'Print boo.ToString()

For Local f:TField = EachIn t.EnumFields()
	Print f.Name()+":"+f.TypeId().Name()
Next

For Local m:TMethod = EachIn t.EnumMethods()
	Print m.Name()+":"+m.TypeId().Name()
Next
