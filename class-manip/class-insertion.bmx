Strict

Import "class-manip.bmx"

Function genToString(ob@ Ptr)
	Print "Razzleberry"
End Function

Function GenCons(ob% Ptr)
	ob[0] = Int genClass.Class
	Return True
End Function

Function GenDest(ob% Ptr)
	ob[0] = 0
	Return True
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

scope = DebugScope.ForClass(c.Class)
scope.Spit()

c.GenerateTypeId()

Local t:TTypeId = TTypeId.ForName("GenericClass")
Print "Type: "+t.Name()
Local boo:Object = t.NewObject()
Print "Object created"
Print boo.ToString()
For Local f:TField = EachIn t.Fields()
	Print f.Name()+":"+f.TypeId().Name()
Next
For Local m:TMethod = EachIn t.Methods()
	Print m.Name()+":"+m.TypeId().Name()
Next
