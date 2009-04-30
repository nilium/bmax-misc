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

Import "exception.bmx"
Import "notification.bmx"
Import "utility.bmx"

Import Brl.Reflection
Import Brl.LinkedList

Import "-lffi"
Import "kvobserver.c"

Private

Rem
	Functions to create closures for getter/setter methods, so it's possible
	to wrap their execution in code that signals their values are being
	updated.
EndRem
Extern "C"	
	Function setterForObserverMethod:Byte Ptr(observer:TObserverMethod)
	?Threaded
	Function getterForObserverMethod:Byte Ptr(observer:TObserverMethod)
	?
End Extern

Private

' Locking it here is probably unnecessary
?Threaded
Global kvo_changeMutex:TMutex = TMutex.Create()
kvo_changeMutex.Lock()
?
Global kvo_changeList:TList = New TList
?Threaded
kvo_changeMutex.Unlock()
?

' For recursive/super/etc. calls where Set<Key> is perhaps called by itself.
Type TObserverLock
	Field _lock:Int = 0 {Restricted}
	Method Lock:TObserverLock()
		_lock :+ 1
		Return Self
	End Method
	
	Method Unlock:TObserverLock()
		Assert _lock>0, "Invalid Operation: Cannot unlock TObserverLock"
		_lock :- 1
		If _lock = 0 Then
			Return Null
		EndIf
		Return Self
	End Method
End Type

Type TObserverMethod {ManualObserving}
	Field _key:String {Restricted}
	Field _indexed:Int {Restricted}
	Field _method:Byte Ptr {Restricted}
 	Field _type:TTypeId {Restricted}
	Field _cif:Byte Ptr
	Field _closure:Byte Ptr
	
	?Threaded
	Field _lock:TMutex {Restricted} ' definitely restricted
	
	' placeholder stuff until I can decide a nice way to handle recursive
	' locking without resorting to writing my own threading module
	
	Method Lock()
		Rem
		If _lock Then
			_lock.Lock()
		EndIf
		EndRem
	End Method
	
	Method Unlock()
		Rem
		If _lock Then
			_lock.Unlock()
		EndIf
		EndRem
	End Method
	?
End Type

Public

Rem:doc
	Registers a {param:type|id} for key-value observing.  Technically, you can
	call this multiple times and it shouldn't really cause a problem, but
	**you do _not_ want to do that**.
EndRem
Function AddObservingForType( id:TTypeId )
	Local setter$, key$
	Local mp:Byte Ptr Ptr, mc:Byte Ptr
	Local observer:TObserverMethod, closure:Byte Ptr
	' getter name, setter name, key name, 
	Local fields:TList = id.Fields()
	Local methods:TList = id.Methods()
	Local argTypes:TTypeId[]
	
	Local keysString:String = id.Metadata("Keys")
	If Not keysString Then
		Return
	EndIf
	
	Local keys:String[][]
	If keysString.Find(",") <> -1 Then
		Local spkeys:String[] = keysString.Split(",")
		keys = New String[][spkeys.Length]
		Local key:String
		For Local idx:Int = 0 Until spkeys.Length
			key = spkeys[idx].Trim().ToLower()
			keys[idx] = [key, "set"+key, "set"+key+"forindex"]
		Next
	Else
		keysString = keysString.Trim().ToLower()
		keys = [[keysString, "set"+keysString, "set"+keysString+"forindex"]]
	EndIf
	
	Local methName:String
	For Local tm:TMethod = EachIn methods
		methName = tm.Name().ToLower()
		
		For Local key:String[] = EachIn keys
			If key[1] <> methName And key[2] <> methName Then
				Continue
			EndIf
			
			mp = Byte Ptr Ptr(Byte Ptr(id._class)+tm._index)
			mc = mp[0]
			
			observer = New TObserverMethod
			observer._key = key[0]
			observer._method = mc
		
			If methName = key[1] Then
				observer._indexed = False
			ElseIf methName = key[2] Then
				observer._indexed = True
			EndIf
		
			argTypes = tm.ArgTypes()
			If tm.TypeId() <> IntTypeId Or argTypes.Length <> 1+observer._indexed Then
				DebugLog "Cannot apply automatic observing to "+id.Name()+"@"+key[0]
				Exit
			EndIf
		
			observer._type = argTypes[0]
			
			closure = setterForObserverMethod(observer)
			Assert closure, "Could not create closure for observing key"
			
			mp[0] = closure
			
			Exit
		Next
	Next
End Function

Const WillChangeValueForKeyNotification$="WillChangeValueForKeyNotification"
Const DidChangeValueForKeyNotification$="DidChangeValueForKeyNotification"

Rem:doc
	Sends a notification that the value of the {param:key} in the
	{param:specified object|obj} will change.
EndRem
Function WillChangeValueForKey(obj:Object, key:String)
	?Threaded
	kvo_changeMutex.Lock()
	?
	key = key.ToLower()
	For Local change:Object[] = EachIn kvo_changeList
		If change[0] <> obj Then
			Continue
		EndIf
		
		If String(change[1]) = key Then
			TObserverLock(change[2]).Lock()
			?Threaded
			kvo_changeMutex.Unlock()
			?
			Return
		EndIf
	Next
	kvo_changeList.AddFirst([obj, Object key, Object New TObserverLock.Lock()])
	?Threaded
	kvo_changeMutex.Unlock()
	?
	
	' Send notification
	TNotificationCenter.DefaultCenter().PostNotificationWithName( ..
										 WillChangeValueForKeyNotification, ..
										 obj, MapWithKeysAndValues(["Key"], [key]))
End Function

Rem:doc
	Sends a notification that the value of the {param:key} in the
	{param:specified object|obj} changed.
EndRem
Function DidChangeValueForKey(obj:Object, key:String)
	?Threaded
	kvo_changeMutex.Lock()
	?
	key = key.ToLower()
	Local link:TLink = kvo_changeList.FirstLink()
	While link
		Local change:Object[] = Object[](link.Value())
		
		If change[0] = obj And String(change[1]) = key Then
			Local lock:TObserverLock = TObserverLock(change[2])
			If Not lock.Unlock() Then
				link.Remove()
				?Threaded
				kvo_changeMutex.Unlock()
				?
				TNotificationCenter.DefaultCenter().PostNotificationWithName( ..
													 DidChangeValueForKeyNotification, ..
													 obj, MapWithKeysAndValues(["Key"], [key]))
				Return
			Else
				?Threaded
				kvo_changeMutex.Unlock()
				?
				Return
			EndIf
		EndIf
		
		link = link.NextLink()
	Wend
	?Threaded
	kvo_changeMutex.Unlock()
	?
End Function
