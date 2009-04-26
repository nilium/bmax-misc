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

Public

Type TNotification
	Field _name:String {Restricted}
	Field _object:Object {Restricted}
	Field _userinfo:Object {Restricted}
	
	Rem:doc
		Initializes the notification with a {param:name},
		{param:associated object|obj}, and {param:user-info object|info}.
		@param:name The name of the notification.
		@param:obj The object associated with the notification.
		@param:info User info that accompanies the notification.
		@returns The notification.
	EndRem
	Method InitWithName:TNotification(name$, obj:Object, info:Object)
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

' TODO: Notification center of sorts
