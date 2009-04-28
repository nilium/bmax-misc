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

Import Brl.Blitz
Import Brl.Reflection
Import Brl.Threads

Import "keyvalueobserving.bmx"
Import "keyvalueprotocol.bmx"

Type Observed Extends TKeyValueProtocol
	Field _name:String = "Default Value"
	Field _values:String[] = ["foo 1", "bar 2", "baz 3", "big 4"] {Key="Rabble" SetterForIndex="SetSomethingForIndex" GetterForIndex="SomethingForIndex"}
	
	Method Name:String()
		Return _name
	End Method
	
	Method SetName(name:String)
		_name = name
	End Method
	
	Method SomethingForIndex:Object(idx:Int)
		Return _values[idx]
	End Method
	
	Method SetSomethingForIndex(val:String, idx:Int)
		_values[idx] = val
	End Method
End Type

Type Observer
	Method itsValueDidChange(notification:TNotification)
		Print "Value has changed to "+ValueForKeyInObject(notification.AssociatedObject(), String(TMap(notification.UserInfo()).ValueForKey("Key"))).ToString()
	End Method
	
	Method willChange(notification:TNotification)
		Print "Value is going to change"
	End Method
End Type

TNotificationCenter.DefaultCenter().AddObserver(New Observer, "willChange", WillChangeValueForKeyNotification)
TNotificationCenter.DefaultCenter().AddObserver(New Observer, "itsValueDidChange", DidChangeValueForKeyNotification)

AddObservingForType(TTypeId.ForName("Observed"))

' test

Local f:Observed = New Observed

Print f.Name()
f.SetName("Bernard")
Print f.Name()

f.SetValueForKey("Name", "Dr. Davis")
Print String(f.ValueForKey("Name"))

Print String(f.ValueForKey("Rabble[0]"))
Print String(f.ValueForKey("Rabble[1]"))
Print String(f.ValueForKey("Rabble[2]"))
Print String(f.ValueForKey("Rabble[3]"))
f.SetValueForKey("Rabble[3]", "Foobar")
Print String(f.ValueForKey("Rabble[3]"))
