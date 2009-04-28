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

'buildopt:threads
'builtopt:verbose

Import Brl.Blitz
Import Brl.Reflection
Import Brl.Threads

Import "keyvalueobserving.bmx"
Import "keyvalueprotocol.bmx"

Type Observed Extends TKeyValueProtocol {Keys="Name, Rabble"}
	Field _name:String = "Default Value"
	Field _values:String[] = ["foo 1", "bar 2", "baz 3", "big 4"] {Key="Rabble" SetterForIndex="SetSomethingForIndex" GetterForIndex="SomethingForIndex"}
	
	Method Name:String()
		Return _name
	End Method
	
	Method SetName(name:String)
		_name = name
	End Method
	
	Method RabbleForIndex:Object(idx:Int)
		Return _values[idx]
	End Method
	
	Method SetRabbleForIndex(val:String, idx:Int)
		_values[idx] = val
	End Method
End Type

Type Observer
	Method itsValueDidChange(notification:TNotification)
		Local info:TMap = TMap(notification.UserInfo())
		Local key:String = String(info.ValueForKey("Key"))
		Local obj:Object = notification.AssociatedObject()
		Local value:Object = ValueForKeyInObject(obj, key)
		Print "Value of @"+key+" has changed to "+value.ToString()
	End Method
	
	Method willChange(notification:TNotification)
			Local info:TMap = TMap(notification.UserInfo())
			Local key:String = String(info.ValueForKey("Key"))
		Print "Value of @"+key+" is going to change"
	End Method
	
	Method anyNotification(notification:TNotification)
		Print "From anyNotification"
	End Method
	
	Method anyNotification2(notification:TNotification)
		Print "From anyNotification2"
	End Method
End Type

AddObservingForType(TTypeId.ForName("Observed"))

' test

Local f:Observed = New Observed

Local nc:TNotificationCenter = TNotificationCenter.DefaultCenter()
Local obs:Observer = New Observer
' obs is watching for the WillChangeValueForKeyNotification from any object
nc.AddObserver(obs, "willChange", WillChangeValueForKeyNotification)
' obs is watching for any notification from the 'f' object
nc.AddObserver(obs, "anyNotification2", Null, f)
' obs watching for a specific notification from any object
nc.AddObserver(obs, "itsValueDidChange", DidChangeValueForKeyNotification)

Print f.Name()
f.SetName("Bernard")
Print f.Name()

f.SetValueForKey("Name", "Dr. Davis")
Print String(f.ValueForKey("Name"))

' Observers expecting info from the old f won't be called anymore
f:Observed = New Observed

Print "Wimbleton"
Print String(f.ValueForKey("Rabble[0]"))
Print String(f.ValueForKey("Rabble[1]"))
Print String(f.ValueForKey("Rabble[2]"))
Print String(f.ValueForKey("Rabble[3]"))
f.SetValueForKey("Rabble[3]", "Foobar")
Print String(f.ValueForKey("Rabble[3]"))
