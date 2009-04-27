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

Rem:doc
	Exception thrown when it is not possible to set the value for a key.
EndRem
Const eCannotSetKeyValueException:String = "CannotSetKeyValueException"

Rem:doc
	Exception thrown when trying to get/set the value of a key that has the
	{code:Restricted} metadata set.
EndRem
Const eValueAccessRestrictedException:String = "ValueAccessRestrictedException"

Rem:doc
	Key for the related object in the user info array.
EndRem
Const kKVEObject:String = "object"
Rem:doc
	Key for the key name in the user info array.
EndRem
Const kKVEKey:String = "key"
Rem:doc
	Key for the key value in the user info array.
EndRem
Const kKVEValue:String = "value"

Type TKeyValueException
	Field _name:String {Restricted}
	Field _reason:String {Restricted}
	Field _userinfo:Object {Restricted}
	
	Method InitWithName:TKeyValueException(name$, reason$="", info:Object=Null) NoDebug
		_name = name
		_userinfo = info
		Return Self
	End Method
	
	Function Exception:TKeyValueException(name$, reason$="", info:Object=Null) NoDebug
		Return (New TKeyValueException.InitWithName(name, reason, info))
	End Function
	
	Method ToString$()
		Return "<"+Name()+"> "+Reason()
	End Method
	
	Rem:doc
		Returns the userinfo object for the exception.
	EndRem
	Method UserInfo:Object()
		Return _userinfo
	End Method
	
	Rem:doc
		Returns the name of the exception.
	EndRem
	Method Name:String()
		Return _name
	End Method
	
	Rem:doc
		Returns the reason for the exception.
	EndRem
	Method Reason:String()
		Return _reason
	End Method
End Type
