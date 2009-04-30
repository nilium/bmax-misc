Rem:license
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

Import "keyvalueprotocol.bmx"
Import "keyvalueobserving.bmx"



Type Foobar {Keys="Name, Value"}
	Field _name$ {Restricted}
	Field _value:Object {Restricted}
	
	Method SetName(n$)
		_name = n
	End Method
	
	Method Name$()
		Return _name
	End Method
	
	Method SetValue(val:Object)
		_value = val
	End Method
	
	Method Value:Object()
		Return _value
	End Method
End Type

Type FoobarObserver
	Method NameWillChange(n:TNotification)
		If String(TMap(n.UserInfo()).ValueForKey("Key")) = "name" Then
			Print "Preparing for name change"
		EndIf
	End Method
	
	Method NameChanged(n:TNotification)
		Local userinfo:TMap = TMap(n.UserInfo())
		Local obj:Object = n.AssociatedObject()
		Local key:String = String(userinfo.ValueForKey("Key"))
		
		If key = "name" Then
			Print key+" changed to "+String(ValueForKeyInObject(obj, key))
		EndIf
	End Method
End Type

AddObservingForType(TTypeId.ForName("Foobar"))

Local nc:TNotificationCenter = TNotificationCenter.DefaultCenter()

Local observer:Object = New FoobarObserver
Local foo:Foobar = New Foobar

nc.AddObserver(observer, "NameWillChange", WillChangeValueForKeyNotification, foo)
nc.AddObserver(observer, "NameChanged", DidChangeValueForKeyNotification, foo)

foo.SetName("Name")
Print foo.Name()
foo.SetValue("Foo")
Print String(foo.Value())
foo.SetName("Wimbleton")
Print foo.Name()
foo.SetValue(Null)
Print foo.Name()
