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

Import Brl.Reflection

Import "exception.bmx"

Public

Rem:doc
	Base class for types that want to provide their own implementation of
	{method:SetValueForKey} and {method:ValueForKey}.
EndRem
Type TKeyValueProtocol
	Rem:doc
		Sets the {param:value} of the {param:key} in the object.
	EndRem
	Method SetValueForKey(key:String, value:Object)
		Try
			SetValueForKeyInObject(Self, key, value)
		Catch ex:TKeyValueException
			Throw ex
		End Try
	End Method
	
	Rem:doc
		Gets the value for {param:key} of the object.
	EndRem
	Method ValueForKey:Object(key:String)
		Return ValueForKeyInObject(Self, key)
	End Method
End Type

Rem:doc
	Gets the value for {param:key} in the {param:specified object|obj}. 
EndRem
Function ValueForKeyInObject:Object(obj:Object, key:String)
	If key.StartsWith("_") Then
		Throw TKeyValueException.Exception(eValueAccessRestrictedException)
	EndIf
	
	key = key.ToLower()
	Local dot:Int = key.Find(".")
	Local keyname$
	If dot = -1 Then
		Local tid:TTypeId = TTypeId.ForObject(obj)
		
		For Local keyfield:TField = EachIn tid.EnumFields()
			keyname = keyfield.Metadata("Key").ToLower()
			If keyname = Null Then
				keyname = keyfield.Name().ToLower()
				If keyname.StartsWith("_") Then
					keyname = keyname[1..]
				EndIf
			EndIf
			
			If keyname <> key Then
				Continue
			EndIf
			
			If keyfield.Metadata("Deprecated") Then
				DebugLog "Accessing deprecated key @"+key
			EndIf
			
			If keyfield.Metadata("Restricted").ToInt() Then
				Throw TKeyValueException.Exception(eValueAccessRestrictedException)
			EndIf
			
			Local getter:String = keyfield.Metadata("Getter")
			If getter = Null Then
				getter = "Get"+key
			EndIf
			
			Local tm:TMethod = tid.FindMethod(getter)
			If tm Then
				Return tm.Invoke(obj, New Object[0])
			Else
				Return keyfield.Get(obj)
			EndIf
		Next
		
		Return Null
	Else
		keyname = key[..dot]
		key = key[dot+1..]
		Local val:TKeyValueProtocol = TKeyValueProtocol(ValueForKeyInObject(obj, keyname))
		
		If val Then
			Return val.ValueForKey(key)
		Else
			Return ValueForKeyInObject(val, key)
		EndIf
	EndIf
End Function

Rem:doc
	Sets the {param:value} of the {param:key} in the
	{param:specified object|obj}.
EndRem
Function SetValueForKeyInObject(obj:Object, key:String, value:Object)
	If key.StartsWith("_") Then
		Throw TKeyValueException.Exception(eValueAccessRestrictedException)
	EndIf
	
	key = key.ToLower()
	Local dot:Int = key.Find(".")
	Local keyname$
	If dot = -1 Then
		Local tid:TTypeId = TTypeId.ForObject(obj)
		
		For Local keyfield:TField = EachIn tid.EnumFields()			
			keyname = keyfield.Metadata("Key").ToLower()
			If keyname = Null Then
				keyname = keyfield.Name().ToLower()
				If keyname.StartsWith("_") Then
					keyname = keyname[1..]
				EndIf
			EndIf
		
			If keyname <> key Then
				Continue
			EndIf
			
			If keyfield.Metadata("Restricted").ToInt() Then
				Throw TKeyValueException.Exception(eValueAccessRestrictedException)
			EndIf
		
			Local setter:String = keyfield.Metadata("Setter")
			If setter = Null Then
				setter = "Set"+Key
			EndIf
		
			Local tm:TMethod = tid.FindMethod(setter)
			If tm Then
				tm.Invoke(obj, [value])
				Return
			Else
				keyfield.Set(obj, value)
				Return
			EndIf
		Next
		Throw TKeyValueException.Exception(eCannotSetKeyValueException)
	Else
		keyname = key[..dot]
		Local keypath:String = key[dot+1..]
		Local val:TKeyValueProtocol = TKeyValueProtocol(ValueForKeyInObject(obj, keyname))
		
		Try
			If val Then
				val.SetValueForKey(keypath, value)
			Else
				SetValueForKeyInObject(val, keypath, value)
			EndIf
		Catch ex:Object
			Throw TKeyValueException.Exception(eCannotSetKeyValueException)
		End Try
	EndIf
End Function
