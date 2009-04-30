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

Private

Function kvp_valueForKeyInObject:Object(obj:Object, key:String)
	If key.StartsWith("_") Then
		Throw TKeyValueException.Exception(eValueAccessRestrictedException)
	EndIf
	
	key = key.ToLower()
	Local dot:Int = key.Find(".")
	Local keyname$
	If dot = -1 Then
		Local tid:TTypeId = TTypeId.ForObject(obj)
		Local elemIndex:Int = key.Find("[")
		If elemIndex <> -1 Then
			Local idx:Int = key[elemIndex+1..key.Find("]")].ToInt()
			key = key[..elemIndex]
			elemIndex = idx
		EndIf
		
		Local suffix$ = ""
		If elemIndex > -1 Then
			suffix :+ "atindex"
		EndIf
		
		Local tm:TMethod = tid.FindMethod("get"+key+suffix)
		If Not tm Then tm = tid.FindMethod(key+suffix)
		If Not tm Then tm = tid.FindMethod("is"+key+suffix)
		
		If tm Then			
			If elemIndex > -1 Then
				Return tm.Invoke(obj, [String(elemIndex)])
			EndIf
			
			Return tm.Invoke(obj, Null)
		EndIf
		
		If elemIndex = -1 Then
			Local counter:TMethod = tid.FindMethod("countof"+key)
			tm = tid.FindMethod("objectin"+key+"atindex")
			If counter And tm Then
				Local count:Int = String(counter.Invoke(obj, Null)).ToInt()
				Local arr:Object[count]
				For Local i:Int = 0 Until count
					arr[i] = tm.Invoke(obj, [String(i)])
				Next
				Return arr
			EndIf
		EndIf
		
		If tid.Metadata("AccessInstanceVariablesDirectly").ToInt() Then
			Local keyField:TField = tid.FindField("_"+key)
			If Not keyField Then keyField = tid.FindField("_is"+key)
			If Not keyField Then keyField = tid.FindField(key)
			If Not keyField Then keyField = tid.FindField("is"+key)
		
			If keyField And keyField.Metadata("Restricted").ToInt() = 0 Then
				If elemIndex > -1 Then
					Return keyfield.TypeId().GetArrayElement(keyfield.Get(obj), elemIndex)
				Else
					Return keyfield.Get(obj)
				EndIf
			EndIf
		EndIf
		
		tm = tid.FindMethod("valueforundefinedkey")
		If tm Then
			Return tm.Invoke(obj, [key])
		EndIf
		
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

Function kvp_setValueForKeyInObject(obj:Object, key:String, value:Object)
	If key.StartsWith("_") Then
		Throw TKeyValueException.Exception(eValueAccessRestrictedException)
	EndIf
	
	key = key.ToLower()
	Local dot:Int = key.Find(".")
	Local keyname$
	If dot = -1 Then
		Local tid:TTypeId = TTypeId.ForObject(obj)
		
		Local elemIndex:Int = key.Find("[")
		If elemIndex <> -1 Then
			Local idx:Int = key[elemIndex+1..key.Find("]")].ToInt()
			key = key[..elemIndex]
			elemIndex = idx
		EndIf
		
		Local setter:String = "set"+key
		
		If elemIndex > -1 Then
			setter :+ "atindex"
		EndIf
		
		Local tm:TMethod = tid.FindMethod(setter)
		
		If tm Then
			If elemIndex > -1 Then
				tm.Invoke(obj, [value, Object(String(elemIndex))])
			Else
				tm.Invoke(obj, [value])
			EndIf
			Return
		EndIf
		
		If tid.Metadata("AccessInstanceVariablesDirectly").ToInt() Then
			Local keyField:TField = tid.FindField("_"+key)
			If Not keyField Then keyField = tid.FindField("_is"+key)
			If Not keyField Then keyField = tid.FindField(key)
			If Not keyField Then keyField = tid.FindField("is"+key)
		
			If keyField And keyfield.Metadata("Restricted").ToInt() = 0 And keyfield.Metadata("ReadOnly").ToInt() = 0 Then
				If elemIndex > -1 Then
					keyfield.TypeId().SetArrayElement(keyfield.Get(obj), elemIndex, value)
					Return
				Else
					keyfield.Set(obj, value)
					Return
				EndIf
			EndIf
		EndIf
		
		tm = tid.FindMethod("setvalueforundefinedkey")
		If tm Then
			tm.Invoke(obj, [Object key, value])
			Return
		EndIf
		
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
		kvp_setValueForKeyInObject(Self, key, value)
	End Method
	
	Rem:doc
		Gets the value for {param:key} of the object.
	EndRem
	Method ValueForKey:Object(key:String)
		Return kvp_valueForKeyInObject(Self, key) 
	End Method
End Type

Rem:doc
	Gets the value for {param:key} in the {param:specified object|obj}. 
EndRem
Function ValueForKeyInObject:Object(obj:Object, key:String)
	Local kvo:TKeyValueProtocol = TKeyValueProtocol(obj)
	If kvo Then
		Return kvo.ValueForKey(key)
	EndIf
	
	Return kvp_valueForKeyInObject(obj, key)
End Function

Rem:doc
	Sets the {param:value} of the {param:key} in the
	{param:specified object|obj}.
EndRem
Function SetValueForKeyInObject(obj:Object, key:String, value:Object)
	Local kvo:TKeyValueProtocol = TKeyValueProtocol(obj)
	If kvo Then
		kvo.SetValueForKey(key, value)
		Return
	EndIf
	
	kvp_setValueForKeyInObject(obj, key, value)
End Function
