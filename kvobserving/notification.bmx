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

Import "../method-invocation/method-invoker.bmx"

Public

Type TNotification {Immutable}
	Field _name:String {ReadOnly}
	Field _object:Object {ReadOnly}
	Field _userinfo:Object {ReadOnly}
	
	Rem:doc
		Initializes the notification with a {param:name},
		{param:associated object|obj}, and {param:user-info object|info}.
		@param:name The name of the notification.
		@param:obj The object associated with the notification.
		@param:info User info that accompanies the notification.
		@returns The notification.
	EndRem
	Method InitWithName:TNotification(name$, obj:Object, info:Object)
		name = name.Trim()
		Assert name.Length,"Cannot create notification with empty name"
		_name = name
		_object = obj
		_userinfo = info
		Return Self
	End Method
	
	Rem:doc
	Returns the name of the notification.
	EndRem
	Method Name$()
		Return _name
	End Method
	
	Rem:doc
	Returns the object associated with the notification.
	EndRem
	Method AssociatedObject:Object()
		Return _object
	End Method
	
	Rem:doc
	Returns the user-info object for the notification.
	EndRem
	Method UserInfo:Object()
		Return _userinfo
	End Method
End Type

Global NotificationTypeId:TTypeId = TTypeId.ForName("TNotification")

Private

Type TNotificationObserver {Immutable}
	Field name$ {ReadOnly}
	Field invocation:CMethodInvocation {ReadOnly}
	Field forObject:Object {ReadOnly}
End Type

Public
'buildopt:threads
Type TNotificationCenter
	Field _queue:TList = New TList {Restricted}
	Field _observers:TList = New TList {Restricted}
	
	?Threaded
	Global _defaults:TMap = New TMap
	Global _defaultsMutex:TMutex = TMutex.Create()
	
	Field _lock:TMutex = TMutex.Create()
	
	Function LockDefaults()
		_defaultsMutex.Lock()
	End Function
	
	Function UnlockDefaults()
		_defaultsMutex.Unlock()
	End Function
	
	Method LockCenter()
		_lock.Lock()
	End Method
	
	Method UnlockCenter()
		_lock.Unlock()
	End Method
	
	?Not Threaded
	Global _default:TNotificationCenter
	?
	
	Function DefaultCenter:TNotificationCenter()
		?Threaded
		Local curThread:TThread = CurrentThread()
		LockDefaults()
		Local center:TNotificationCenter = TNotificationCenter(_defaults.ValueForKey(curThread))
		If center = Null Then
			center = New TNotificationCenter
			_defaults.Insert(curThread, center)
		EndIf
		UnlockDefaults()
		Return center
		
		?Not Threaded
		If _default = Null Then
			_default = New TNotificationCenter
		EndIf
		Return _default
		?
	End Function
	
	Method Dispose()
		ProcessQueue()
		?Threaded
		Local thread:TThread = CurrentThread()
		LockDefaults()
		If _defaults.ValueForKey(thread) = Self Then
			_defaults.Remove(thread)
		EndIf
		UnlockDefaults()
		?Not Threaded
		If _default = Self Then
			_default = Null
		EndIf
		?
	End Method
	
	Method MakeDefault()
		?Threaded
		Local thread:TThread = CurrentThread()
		LockDefaults()
		_defaults.Insert(thread, Self)
		UnlockDefaults()
		?Not Threaded
		_default = Self
		?
	End Method
	
	' Handles the notification immediately and synchronously
	Method PostNotificationWithName(notification:String, obj:Object=Null, userinfo:Object=Null)
		Local n:TNotification = New TNotification
		n._name = notification
		n._object = obj
		n._userinfo = userinfo
		PostNotification(n)
	End Method
	
	Method PostNotification(notification:TNotification)
		?Threaded
		LockCenter()
		?
'		Local notifications:TList = _queue.Copy()
		Local observers:TList = _observers.Copy()
		?Threaded
		UnlockCenter()
		?
		
		Local assObj:Object = notification.AssociatedObject()
		Local assName:String = notification.Name()
		Local invoker:CMethodInvocation = Null
		For Local o:TNotificationObserver = EachIn observers
			If (o.forObject <> Null And o.forObject <> assObj) Or (o.name <> Null And o.name <> assName) Then
				Continue
			EndIf
			
			invoker = o.invocation.Copy()
			invoker.SetObjectArgument(notification,1)
			invoker.Invoke()
		Next
	End Method
	
	Method ProcessQueue()
		?Threaded
		LockCenter()
		?
		Local notifications:TList = _queue.Copy()
		_queue.Clear()
		?Threaded
		UnlockCenter()
		?
		
		For Local n:TNotification = EachIn notifications
			PostNotification(n)
		Next
	End Method
	
	' Used to post notifications from different threads
	Method EnqueueNotificationWithName(notification:String, obj:Object=Null, userinfo:Object=Null)
		?Threaded
		LockCenter()
		?
		EnqueueNotification(New TNotification.InitWithName(notification, obj, userinfo))
		?Threaded
		UnlockCenter()
		?
	End Method
	
	Method EnqueueNotification(notification:TNotification)
		?Threaded
		LockCenter()
		?
		_queue.AddLast(notification)
		?Threaded
		UnlockCenter()
		?
	End Method
	
	Method AddObserver(observer:Object, methodName:String, notification:String=Null, forObject:Object=Null)
		Assert observer, "Null observer"
		
		methodName = methodName.Trim()
		Assert methodName.Length, "Empty method name"
		
		Local o:TNotificationObserver = New TNotificationObserver
		o.invocation = New CMethodInvocation.InitWithNamedMethod(methodName, [NotificationTypeId], IntTypeId)
		o.invocation.SetTarget(observer)
		o.forObject = forObject
		o.name = notification
		
		?Threaded
		LockCenter()
		?
		_observers.AddLast(o)
		?Threaded
		UnlockCenter()
		?
	End Method
	
	Method RemoveObserver(observer:Object, notification:String=Null, forObject:Object=Null)
		If observer = Null Then Return
		?Threaded
		LockCenter()
		?
		Local observers:TList = _observers.Copy()
		If notification And forObject Then
			For Local o:TNotificationObserver = EachIn observers
				If o.invocation.Target() <> observer Then
					Continue
				EndIf
				
				If o.name = notification And o.forObject = forObject Then
					_observers.Remove(o)
				EndIf
			Next
		ElseIf notification Then
			For Local o:TNotificationObserver = EachIn observers
				If o.invocation.Target() <> observer Then
					Continue
				EndIf
				
				If o.name = notification Then
					_observers.Remove(o)
				EndIf
			Next
		ElseIf forObject Then
			For Local o:TNotificationObserver = EachIn observers
				If o.invocation.Target() <> observer Then
					Continue
				EndIf
				
				If o.forObject = forObject Then
					_observers.Remove(o)
				EndIf
			Next
		Else
			For Local o:TNotificationObserver = EachIn observers
				If o.invocation.Target() = observer Then
					_observers.Remove(o)
				EndIf
			Next
		EndIf
		?Threaded
		UnlockCenter()
		?
	End Method
	
	?Threaded
	Function PruneDefaults()
		LockDefaults()
		Local defaults:TMap = _defaults.Copy()
		For Local thread:TThread = EachIn defaults.Keys()
			If thread.Running() Then
				Continue
			EndIf
			_defaults.Remove(thread)
		Next
		UnlockDefaults()
	End Function
	?
End Type
