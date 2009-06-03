Rem
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

Import brl.Reflection
Import pub.Lua
Import "lua-reflection.c"

Rem:doc
	The following attributes can be applied to BMax Types:

	 {expose} - When applied to a type, this will result in the type being exposed
	to Lua when ImplementTypes or ImplementType is called on it and any BMax objects
	pushed onto the stack will have their methods and field metatable attached to
	the object unless specified otherwise. Regular object instances can have their
	methods accessed via varname.methodName() or varname:methodName(). For
	instances, it is better to use the second unless you are calling the method as
	if it were a delegate.

		{static} - When applied to a type, the type acts as a static class or namespace
	in Lua. An instance of the type is created and the type is created as a global
	table in Lua. These are accessed either via TypeName.methodName() or
	TypeName:methodName() - either works, but I recommend using the first. The
	fields of the instance this static object is based off of are accessible.

		{noclass} - Requires {static}. When applied to a type, the behavior is the same
	as {static}, except that the functions are pushed as global variables/functions
	in Lua rather than as fields of a table. Only methodName() is required to call
	them. Fields are inaccessible using this attribute, even if static is not set.

		{rename="newName"} - A form of aliasing. Renames a method or type such that
	access to the type or method in Lua must use the new name, not the one used by
	BlitzMax source code.  Does not apply to fields.

		{hidden} - When applied to a method or field, will not expose the method/field
	to Lua. This is useful if you would like to only expose methods of a type to
	Lua.

		{hidefields} - When applied to a type, not a field, this will hide all fields
	without exception. As a result, no metatable is set on instances of objects
	created with the type this is applied to.
	
		{binding="late"|"immediate"} - When applied to a type, this option specifies
	what type of binding the type uses when pushing the object/retrieving methods.
	
		In the case of "late" binding, this will not add the methods to the object's
	table until the method something tries to get the method from the object.  This
	can remove some bottlenecks surrounding the pushing of objects, but may present
	a minor speed hit when 
End Rem

Private

Extern "C"
	Function lref_pushrawobject(state@ Ptr, obj:Object)
	Function lref_releaserawobject(state@ Ptr, idx:Int)
	Function lref_torawobject:Object(state@ Ptr, idx:Int)
	Function lref_disposeobject%(state@ Ptr)
End Extern

Const LREF_OBJECT_FIELD:String = "LREF_object_field"
Const LREF_METATABLE_FIELDS:String = "LREF_metatable_fields"	' Field access metatable
Const LREF_METATABLE_OBJECTS:String = "LREF_metatable_objects"  ' Userdata collection metatable
Const LREF_USE_EXCEPTIONS:Int = True

Const LREF_META_EXPOSE$ = "expose"
Const LREF_META_HIDDEN$ = "hidden"
Const LREF_META_HIDEFIELDS$ = "hidefields"
Const LREF_META_RENAME$ = "rename"
Const LREF_META_NOCLASS$ = "noclass"
Const LREF_META_STATIC$ = "static"
Const LREF_META_BINDING$ = "binding"
Const LREF_META_CONSTRUCTOR$ = "constructor"

Const LREF_BINDING_DEFAULT%=-1
Const LREF_BINDING_LATE%=0
Const LREF_BINDING_IMMEDIATE%=1

Const LREF_BINDING_MIN% = LREF_BINDING_DEFAULT-1
Const LREF_BINDING_MAX% = LREF_BINDING_IMMEDIATE+1

Public

' Exception when an error occurs
Type ILREFException Final
	Field m_stack:String
	Field m_msg:String

	Method Stack:String()
		Return m_stack
	End Method

	Method Message:String()
		Return m_msg
	End Method

	Method ToString:String()
		Return m_msg
	End Method
End Type


Function LREF_Exception:ILREFException( msg$="", state:Byte Ptr )
	Local ex:ILREFException = New ILREFException

	If state <> Null Then
		ex.m_stack = LREF_DumpStack( state, False )
	Else
		ex.m_stack = ""
	EndIf

	ex.m_msg = msg

	Return ex
End Function


Private

' Currently not implemented in axe.lua
Function LREF_lua_upvalueindex:Int(idx:Int) NoDebug
	Return LUA_GLOBALSINDEX-idx
End Function


Function LREF_AttachMetatable( state:Byte Ptr, idx:Int, metatable$ )
	If idx < 1 And idx > LUA_REGISTRYINDEX Then
		idx = lua_gettop(state) - (idx+1)
	EndIf

	lua_pushstring( state, metatable )
	lua_gettable( state, LUA_REGISTRYINDEX )

	If lua_type( state, -1 ) = LUA_TNIL Then
		lua_pop( state, 1 )
		LREF_CreateMetaTables(state)

		lua_pushstring( state, metatable )
		lua_gettable( state, LUA_REGISTRYINDEX )
	EndIf

	lua_setmetatable( state, idx )
End Function


Function LREF_PushMethodClosure(state:Byte Ptr, _method:TMethod, objectIndex:Int, name$ )
	lref_pushrawobject( state, _method )
	lua_pushvalue( state, objectIndex )
	lua_pushcclosure( state, LREF_TypeCall, 2 )
End Function


Private

Rem
The type cache stores information about all types as they relate to Lua
EndRem

Global LREF_TypeCache:TMap

'#region Type info classes
Type LREF_TypeInfo
	Field name$					' name of type, default is typeid.Name()
	Field constructor$			' name of constructor, default = New[name]
	Field exposed%
	Field static%
	Field noclass%
	Field hidefields%
	Field binding%
	Field methods:TMap
	Field fields:TMap
	Field typeid:TTypeId
	
	Method Init:LREF_TypeInfo(t:TTypeId)
		name = t.Metadata(LREF_META_RENAME)
		If Not name Then
			name = t.Name()
		EndIf
		
		typeid = t
		
		exposed = t.Metadata(LREF_META_EXPOSE).ToInt()
		static = t.Metadata(LREF_META_STATIC).ToInt()
		noclass = t.Metadata(LREF_META_NOCLASS).ToInt()
		hidefields = t.Metadata(LREF_META_HIDEFIELDS).ToInt()
		
		constructor = t.Metadata(LREF_META_CONSTRUCTOR)
		If Not constructor Then
			constructor = "New"+name
		EndIf
		
		Select t.Metadata(LREF_META_BINDING)
			Case "late", "default", ""
				binding = LREF_BINDING_LATE
			Case "immediate"
				binding = LREF_BINDING_IMMEDIATE
			Default
				Throw LREF_Exception(t.Name()+": Invalid binding '"+t.Metadata(LREF_META_BINDING)+"'", Null)
		End Select
		
		methods = New TMap
		fields = New TMap
		
		For Local meth:TMethod = EachIn t.Methods()
			Local info:LREF_MethodInfo = New LREF_MethodInfo.Init(meth)
			methods.Insert(info.name, info)
		Next
		
		For Local tf:TField = EachIn t.Fields()
			Local info:LREF_FieldInfo = New LREF_FieldInfo.Init(tf)
			methods.Insert(info.name, info)
		Next
		
		Return Self
	End Method
End Type

Type LREF_MethodInfo
	Field name$
	Field hidden%
	Field _method:TMethod
	
	Method Init:LREF_MethodInfo(m:TMethod)
		name = m.Metadata(LREF_META_RENAME)
		If Not name Then
			name = m.Name()
		EndIf
		
		Local tn$ = m.Name().ToLower()
		If tn = "new" Or tn = "delete" Then
			hidden = True
		Else
			hidden = m.Metadata(LREF_META_HIDDEN).ToInt()
		EndIF
		
		_method = m
		Return Self
	End Method
End Type

Type LREF_FieldInfo
	Field name$
	Field hidden%
	Field _field:TField
	
	Method Init:LREF_FieldInfo(f:TField)
		name = f.Name()
		hidden = f.Metadata(LREF_META_HIDDEN).ToInt()
		_field = f
		Return Self
	End Method
End Type
'#endregion

Function LREF_BuildTypeCache:TMap()
	Local typecache:TMap = New TMap
	Local info:LREF_TypeInfo
	
	For Local typeid:TTypeId = EachIn TTypeId.EnumTypes()
		info = New LREF_TypeInfo.Init(typeid)
		typecache.Insert(typeid, info)
	Next
	
	Return typecache
End Function

Function LREF_FindMethod:TMethod(typeid:TTypeID, name$)
	Local typecache:TMap
	Local typeinfo:LREF_TypeInfo
	Local methinfo:LREF_MethodInfo
	
	typecache = LREF_TypeCache
	While typeid
		typeinfo = LREF_TypeInfo(typecache.ValueForKey(typeid))
		
		If typeinfo.exposed Then
			methinfo = LREF_MethodInfo(typeinfo.methods.ValueForKey(name))
			If methinfo Then
				If methinfo.hidden Then
					Return Null
				EndIf
				Return methinfo._method
			EndIf
		EndIf
		typeid = typeid.SuperType()
	Wend
	Return Null
End Function

Function LREF_FindField:TField(typeid:TTypeID, name$)
	Local typecache:TMap
	Local typeinfo:LREF_TypeInfo
	Local fieldinfo:LREF_FieldInfo
	
	typecache = LREF_TypeCache
	While typeid
		typeinfo = LREF_TypeInfo(typecache.ValueForKey(typeid))
		
		If typeinfo.exposed And (Not typeinfo.hidefields) Then
			fieldinfo = LREF_FieldInfo(typeinfo.fields.ValueForKey(name))
			If fieldinfo Then
				If fieldinfo.hidden Then
					Return Null
				EndIf
				Return fieldinfo._field
			EndIf
		EndIf
		typeid = typeid.SuperType()
	Wend
	Return Null
End Function


' TypeNew([object])
Function LREF_TypeNew:Int(state:Byte Ptr)
	Const ERROR_NO_TYPEID$ = "Unable to construct object: no TTypeId attached to class constructor"
	Const ERROR_OBJ_NULL$ = "Unable to construct object: object passed to constructor is Null"
	Const ERROR_CANNOT_ALLOCATE_OBJ$ = "Unable to construct object: object could not be allocated"

	Local typeinfo:LREF_TypeInfo
	Local obj:Object
	Local expose:Int, noclass:Int, static:Int, hidefields:Int
	Local objIdx:Int = -1

	typeinfo = LREF_TypeInfo(lref_torawobject(state, LREF_lua_upvalueindex(1)))

	If typeinfo = Null Then
		If LREF_USE_EXCEPTIONS Then
			Throw LREF_Exception( ERROR_NO_TYPEID, state )
		EndIf

		lua_pushstring( state, ERROR_NO_TYPEID )
		lua_error(state)

		Return 0
	Else
		If lua_gettop(state) = 1 And lua_type( state, 1 ) = LUA_TUSERDATA Then
			objIdx = 1
			obj = lref_torawobject(state, objIdx)

			If obj = Null Then
				If LREF_USE_EXCEPTIONS Then
					Throw LREF_Exception( ERROR_OBJ_NULL, state )
				EndIf

				lua_pushstring( state, ERROR_OBJ_NULL )
				lua_error(state)

				Return 0
			EndIf
		Else
			obj = typeinfo.typeid.NewObject()
		EndIf

		If obj = Null Then
			If LREF_USE_EXCEPTIONS Then
				Throw LREF_Exception( ERROR_CANNOT_ALLOCATE_OBJ, state )
			EndIf

			lua_pushstring( state, ERROR_CANNOT_ALLOCATE_OBJ )
			lua_error(state)

			Return 0
		Else
			LREF_PushBMaxObject( state, obj, typeinfo.typeid, typeinfo.exposed, typeinfo.static, typeinfo.noclass, typeinfo.hidefields, typeinfo.binding, objIdx )

			Return 1
		EndIf
	EndIf
End Function


' TypeFieldSet( table, key, value ) [obj.field = newvalue]
Function LREF_TypeFieldSet:Int(state:Byte Ptr)
	Local obj:Object
	Local rfield:TField
	Local name:String
	Local typeid:TTypeId
	Local superid:TTypeId = Null
	Local hidden:Int = 0

	If lua_type( state, 2 ) <> LUA_TSTRING Then
		lua_rawset( state, 1 )
		Return 0
	EndIf

	name = lua_tostring( state, 2 )
	obj = LREF_GetValue( state, 1 )

	If obj Then typeid = TTypeId.ForObject(obj)
	
	If typeid Then
		rfield = LREF_FindField(typeid, name)
	
		If rfield <> Null Then
			rfield.Set( obj, LREF_GetValue( state, 3 ) )					' Is a type field
		Else
			lua_rawset( state, 1 )										  ' Not a type field
		EndIf
	EndIf

	Return 0
End Function


' TypeFieldGet( table, key ) [someVar = obj.field]
Function LREF_TypeFieldGet:Int(state:Byte Ptr)
	If lua_type( state, 2 ) <> LUA_TSTRING Then
		lua_rawget( state, 1 )  ' Not a string (name), so not a field
		Return 1
	EndIf
	
	Local obj:Object
	Local typeid:TTypeId = Null
	Local superid:TTypeId = Null
	Local hidden:Int = 0
	Local rfield:TField = Null
	Local name:String
	
	name = lua_tostring( state, 2 )
	lua_pushvalue( state, 2 )
	lua_rawget( state, 1 )
	
	If lua_type( state, -1 ) <> LUA_TNIL Then
		Return 1
	EndIf
	
	lua_pushstring( state, LREF_OBJECT_FIELD )
	lua_rawget( state, 1 )
	obj = lref_torawobject( state, -1 )
	
	If obj Then
		typeid = TTypeId.ForObject(obj)
	EndIf
	
	If typeid Then
		rfield = LREF_FindField(typeid, name)
	
		If rfield <> Null Then
				Select rfield.TypeId()
				Case FloatTypeId
					lua_pushnumber( state, rfield.GetFloat(obj) )

				Case DoubleTypeId
					lua_pushnumber( state, rfield.GetDouble(obj) )

				Case ByteTypeId, ShortTypeId, IntTypeId
					lua_pushnumber( state, rfield.GetInt(obj) )

				Case LongTypeId
					lua_pushnumber( state, rfield.GetLong(obj) )

				Case StringTypeId
					lua_pushstring( state, rfield.GetString(obj) )

				Case ArrayTypeId
					lua_pushbmaxarray( state, rfield.Get(obj), False )

				Default
					Local fval:Object = rfield.Get(obj)
					If fval = Null Then
						lua_pushnil(state)
					Else
						LREF_ConstructBMaxObject( state, fval, Null )
					EndIf
			End Select
			
			Return 1
		EndIf
		
		' check for cached method
		lua_pushvalue(state, 2)
		lua_rawget(state, 1)
		If lua_type(state, -1) = LUA_TFUNCTION Then
			Return 1
		EndIf
		lua_pop(state, 1)
		
		Local rmeth:TMethod = LREF_FindMethod(typeid, name)
		LREF_PushMethodClosure(state, rmeth, 4, name)
		
		Return 1
	EndIf

	lua_pop(state, 1)

	Return 1
End Function

' Called when any method is called.  Provides a generic interface to all methods
' through the reflection module.
Function LREF_TypeCall:Int(state:Byte Ptr)
	Const ERROR_NULL_METHOD$ = "Unable to call method: Null TMethod object attached to closure"
	Const ERROR_NUM_ARGUMENTS$ = "Error calling $1::$2(): Expected $3 arguments, only received $4"

	Local obj:Object
	Local meth:TMethod
	Local typeid:TTypeId
	Local result:Object
	Local argOffset:Int

	obj = lref_torawobject( state, LREF_lua_upvalueindex(2) )

	typeid = TTypeId.ForObject(obj)
	meth = TMethod(lref_torawobject( state, LREF_lua_upvalueindex(1) ))

	If meth = Null Then
		If LREF_USE_EXCEPTIONS Then
			Throw LREF_Exception( ERROR_NULL_METHOD, state )
		EndIf

		lua_pushstring( state, ERROR_NULL_METHOD )
		lua_error(state)

		Return 0
	EndIf

	Local argTypes:TTypeId[] = meth.ArgTypes()
	Local args:Object[meth.ArgTypes().Length]
	Local argIdx:Int
	Local numArgs:Int = args.Length

	If numArgs > 0 And lua_type( state, 1 ) = LUA_TTABLE And LREF_GetValue( state, 1 ) = obj Then
		argOffset = 2
	Else
		argOffset = 1
	EndIf

	If numArgs > lua_gettop(state)-(argOffset-1) Then
		If LREF_USE_EXCEPTIONS Then
			Throw LREF_Exception( "Error calling "+typeid.Name()+"::"+meth.Name()+"(): Expected "+numArgs+" arguments, only received "+(lua_gettop(state)-(argOffset-1)), state )
			' this happens to be the only exception to storing the error as a constant in the function header
		EndIf

		lua_pushstring( state, "Error calling "+typeid.Name()+"::"+meth.Name()+"(): Expected "+numArgs+" arguments, only received "+(lua_gettop(state)-(argOffset-1)) )
		lua_error(state)
		' numArgs = lua_gettop(state)-(argOffset-1) ' No more default arguments
	EndIf

	For argIdx = 0 Until numArgs
		args[argIdx] = LREF_GetValue( state, argOffset+argIdx )
	Next

	result = meth.Invoke( obj, args )

	If result <> Null Then
		Select meth.TypeId()
			Case LongTypeId,IntTypeId,ByteTypeId,ShortTypeId
				lua_pushinteger( state, result.ToString().ToLong() )
				Return 1

			Case StringTypeId
				lua_pushstring( state, result.ToString() )
				Return 1

			Case FloatTypeId,DoubleTypeId
				lua_pushnumber( state, result.ToString().ToDouble() )
				Return 1

			Case ArrayTypeId
				lua_pushbmaxarray( state, result, False )
				Return 1

			Default
				LREF_ConstructBMaxObject( state, result, Null )
				Return 1
		End Select
	Else
		lua_pushnil(state)
		Return 1
	EndIf
End Function

' Pushes a BMax object onto the stack, using either the class's lua constructor,
' any of its superclasses' constructors, or finally pushing a raw object without
' methods or fields
Function LREF_ConstructBMaxObject( state:Byte Ptr, obj:Object, typeId:TTypeId )
	If typeId = Null Then
		typeId = TTypeId.ForObject(obj)
	EndIf
	
	Local info:LREF_TypeInfo = LREF_TypeInfo(LREF_TypeCache.ValueForKey(typeId))

	lua_pushstring( state, info.constructor )
	lua_gettable( state, LUA_GLOBALSINDEX )

	If lua_type( state, -1 ) = LUA_TFUNCTION Then
		' In the event that a constructor for the object's type already exists, use that

		lref_pushrawobject( state, obj )

		LREF_AttachMetaTable( state, -1, LREF_METATABLE_OBJECTS )

		If lua_pcall( state, 1, 1, 0 ) <> 0 Then
			If LREF_USE_EXCEPTIONS Then
				Throw LREF_Exception( "Error calling constructor for "+typeId.Name()+"~nLua error: "+lua_tostring( state, -1 ), state )
			EndIf

			' I understand there is some pointlessness to handling an error here only to produce another error.
			lua_pushstring( state, "Error calling constructor for "+typeId.Name()+"~nLua error: "+lua_tostring( state, -1 ) )
			lua_error(state)

			Return
		EndIf
	Else
		lua_pop( state, 1 )

		If typeId.SuperType() Then
			' If the object extends another class, check to see if its base class has been implemented
			LREF_ConstructBMaxObject( state, obj, typeId.SuperType() )
		Else
			' If no constructor for the class exists, push it as just an object without methods
			lua_pop( state, 1 )
			LREF_PushBMaxObject( state, obj, Null, False, False, False, True, LREF_BINDING_LATE, -1 )
		EndIf
	EndIf
End Function

' Auxiliary function to clear a table of its contents.  Not sure if there's a
' Lua-provided way to do this yet.
Function LREF_ClearTable( state:Byte Ptr, idx:Int )
	Local top:Int = lua_gettop(state)

	lua_pushnil(state)
	While lua_next( state, idx ) <> 0
		lua_pop( state, 1 )
		lua_pushvalue( state, -1 )
		lua_pushnil(state)
		lua_rawset( state, idx )		' Do not want metatables here.
	Wend
	
	top = lua_gettop(state)-top

	If top > 0 Then
		lua_pop( state, top )
	EndIf
End Function

' Gets the equivalent BMax value off the lua stack
Function LREF_GetValue:Object( state:Byte Ptr, idx:Int )
	Local obj:Object

	Select lua_type( state, idx )
		Case LUA_TNIL
			Return Null

		Case LUA_TSTRING
			Return lua_tostring( state, idx )

		Case LUA_TNUMBER
			Return String(lua_tonumber( state, idx ))

		Case LUA_TFUNCTION
			Return Null

		Case LUA_TTABLE
			' check if the table is an object
			lua_pushstring( state, LREF_OBJECT_FIELD )
			lua_rawget( state, idx )

			If lua_type( state, -1 ) <> LUA_TUSERDATA Then	   ' Treat value as an array
				lua_pop( state, 1 )
				Local arr:Object[] = lua_tobmaxarray( state, idx )
				
				Return arr
			ElseIf lua_type(state, -1) = LUA_TUSERDATA Then
				' Otherwise, it's an object
				obj = lref_torawobject(state, -1)
				lua_pop( state, 1 )
				
				Return obj
			Else
				lua_pop(state, 1)
				Return Null
			EndIf

		Case LUA_TBOOLEAN
			Return String(lua_toboolean( state, idx ))

		Case LUA_TUSERDATA,LUA_TLIGHTUSERDATA
			Return String(Int(lua_topointer( state, idx )))

		Default
			Return Null
	End Select
End Function


' NOTE: consider rewriting this such that the method table is an upvalue to the
' New*() function that is then copied and modified for the object.  (May pose
' issues for method-pointer style functions.)
Function LREF_PushBMaxObject( state:Byte Ptr, obj:Object, from:TTypeId, expose:Int=-1, static:Int=-1, noclass:Int=-1, hidefields:Int=-1, binding%=LREF_BINDING_DEFAULT, objidx:Int=-1 )
	Local methIter:TMethod
	Local tableIdx:Int
	Local rename:String = Null
	Local name:String = Null
	Local ownObjIdx:Int = False
	
	If expose = -1 Then
		expose = from.MetaData(LREF_META_EXPOSE).ToInt()
	EndIf
	
	If static = -1 Then
		static = from.MetaData(LREF_META_STATIC).ToInt()
	EndIf
	
	If noclass = -1 Then
		noclass = from.MetaData(LREF_META_NOCLASS).ToInt()
	EndIf
	
	If hidefields = -1 Then
		hidefields = from.MetaData(LREF_META_HIDEFIELDS).ToInt()
	EndIf
	
	If objIdx = -1 Then
		lref_pushrawobject(state, obj)
		objIdx = lua_gettop(state)
		ownObjIdx = True
		
		LREF_AttachMetaTable( state, objIdx, LREF_METATABLE_OBJECTS )
	EndIf
	
	If noclass And static Then
		tableIdx = LUA_GLOBALSINDEX
		hidefields = True ' No exceptions
	Else
		' Create the new object table if it's an instance or regular static class
		tableIdx = -3
		
		lua_createtable( state, 0, 1 )
		
		lua_pushstring( state, LREF_OBJECT_FIELD )
		lua_pushvalue( state, objIdx )
		
		lua_settable(state, tableIdx)
	EndIf
	
	If binding = LREF_BINDING_DEFAULT Then
		Select from.Metadata(LREF_META_BINDING)
			Case "late"
				binding = LREF_BINDING_LATE
			Case "immediate"
				binding = LREF_BINDING_IMMEDIATE
			Default
				binding = LREF_BINDING_LATE
		End Select
	EndIf
	
	' This is a hold-over from prior versions where binding of methods was immediate.
	If expose And (binding = LREF_BINDING_IMMEDIATE Or (static And noclass)) Then
		' This is not something I'm particularly fond of, and I would like to
		' see if I can do this better.  Currently, the methods are iterated
		' over and pushed onto the stack each time you push an object.  This
		' doesn't apply to unexposed objects, but this may be a problem if you
		' rely heavily on Lua.
		For methIter = EachIn from.EnumMethods()
			name = methIter.Name()

			If from.MetaData(LREF_META_HIDDEN).ToInt() Or name.ToLower() = "delete" Or name.ToLower() = "new" Then
				Continue
			EndIf

			rename = methIter.MetaData(LREF_META_RENAME)
			If rename <> "" Then
				name = rename
			EndIf
			rename = Null

			' {Type}::{Name}
			lua_pushstring( state, name )

			'lua_pushstring( state, methIter.Name() )
			lref_pushrawobject( state, methIter )
			lua_pushvalue( state, objIdx )

			lua_pushcclosure( state, LREF_TypeCall, 2 )

			lua_settable( state, tableIdx )

			' NOTE: An unintended side-effect of the object being passed as an
			' upvalue is that you sort of have delegates in Lua...
		Next
	EndIf
	
	If expose = True And hidefields = False And noclass = False Then  ' If the type is not exposed or if it's regular functions, fields will be inaccessible
		LREF_AttachMetaTable( state, -1, LREF_METATABLE_FIELDS )
	EndIf

	If ownObjIdx Then
		lua_remove( state, objIdx )
	EndIf
End Function

' Creates meta-tables for garbage collection and class field access and places
' them in the registry.
' This should only be called once for each Lua state, never by the user.  It
' should not affect anything if it's called as many times as you want, but
' there's no reason to do so.
Function LREF_CreateMetaTables(state:Byte Ptr)
	' Fields
	lua_pushstring( state, LREF_METATABLE_FIELDS )
	lua_createtable( state, 0, 2 )

	lua_pushstring( state, "__newindex" )
	lua_pushcclosure( state, LREF_TypeFieldSet, 0 )
	lua_rawset( state, -3 )

	lua_pushstring( state, "__index" )
	lua_pushcclosure( state, LREF_TypeFieldGet, 0 )
	lua_rawset( state, -3 )

	lua_settable( state, LUA_REGISTRYINDEX )

	' Userdata collection
	lua_pushstring( state, LREF_METATABLE_OBJECTS )
	lua_createtable( state, 0, 1 )

	lua_pushstring( state, "__gc" )
	lua_pushcclosure( state, lref_disposeobject, 0 )
	lua_rawset( state, -3 )

	lua_settable( state, LUA_REGISTRYINDEX )
End Function


' Debugging code, probably going to remove this at a later date.  Ironically,
' the debugging code does not get debugged.
Function LREF_DumpStack$( lua:Byte Ptr, output%=True ) NoDebug
	Local sout:String = ""
	Local lout:String
	Local idx:Int
	
	For idx = 1 To lua_gettop(lua)
		sout :+ "  "+("["+idx+"]")[..5]+" "
		
		Select lua_type( lua, idx )
			Case LUA_TBOOLEAN
				sout :+ "boolean   "+lua_toboolean( lua, idx )
			Case LUA_TNIL
				sout :+ "nil"
			Case LUA_TNUMBER
				sout :+ "number	"+lua_tonumber( lua, idx )
			Case LUA_TFUNCTION
				sout :+ "function"
			Case LUA_TUSERDATA,LUA_TLIGHTUSERDATA
				sout :+ "userdata  0x"+Hex(Int(lua_topointer( lua, idx )))
			Case LUA_TSTRING
				sout :+ "string	"+lua_tostring( lua, idx )
			Case LUA_TTABLE
				sout :+ "table	 "+LREF_TableToString( lua, idx, 6  )
			Default
				sout :+"object/unknown/null"
		End Select
		
		sout :+ "~n"
	Next

	If output Then
		Print sout
	EndIf

	Return sout
End Function


' Debugging code
' Converts a table to a string for visualization purposes.
Function LREF_TableToString$( lua:Byte Ptr, idx:Int, indent%=0 ) NoDebug
	Local out$ = "{ "
	Local idn$ = " "[..indent]
	Local top% = lua_gettop(lua)
	Local key$ = Null
	Local value$ = Null

	lua_pushnil(lua)

	While lua_next( lua, idx ) <> 0
		key = lua_tostring( lua, -2 )

		If lua_type( lua, -1 ) = LUA_TFUNCTION Then
			value = "function"
		ElseIf lua_type( lua, -1 ) = LUA_TNIL Then
			value = "nil"
		ElseIf lua_type( lua, -1 ) = LUA_TNUMBER Then
			value = lua_tonumber(lua, -1)
		ElseIf lua_type( lua, -1 ) = LUA_TBOOLEAN Then
			If lua_toboolean(lua, -1) Then
				value="true"
			Else
				value="false"
			EndIf
		ElseIf lua_type( lua, -1 ) = LUA_TUSERDATA Then
			value = "userdata"
		ElseIf lua_type( lua, -1 ) = LUA_TLIGHTUSERDATA Then
			value = "0x"+Hex(Int(lua_touserdata(lua,-1)))
		Else
			lua_tostring( lua, -1 )
		EndIf

		out :+ idn+key+"="+value+", ~n"
		lua_pop( lua, 1 )
	Wend

	If key <> Null Then
		out = out[..out.Length-3]
	EndIf

	If lua_gettop(lua)-top > 0 Then
		lua_pop(lua, lua_gettop(lua)-top)
	EndIf

	out :+ " }"

	Return out
End Function


Public

Function LREF_Init()
	LREF_TypeCache = LREF_BuildTypeCache()
End Function

Rem:doc
	Low-level function to expose/implement a type in Lua.
	
	@param state The Lua state you'll be exposing the Type to.
	@param from The TTypeID for the Type you're exposing to Lua.
	@param expose Whether or not to expose the type. Left at -1, this value will be
retrieved from the Type's LREF_META_EXPOSE attribute.
	@param static Whether or not the type is exposed as a static class. Left at -1,
this value will be retrieved from the Type's LREF_META_STATIC attribute.
	@param noclass Whether or not the type is exposed as a set of functions or
static class. This parameter only takes effect if the type is also static. Left
at -1, this value will be retrieved from the Type's LREF_META_NOCLASS attribute.
	@param hidefields Whether or not the type is exposed with accessible fields. If
this is set to true (or the Type has its LREF_META_HIDEFIELDS attribute set to a
non-zero value), the Type's fields will be inaccessible in Lua. Left at -1, this
value will be retrieved from the Type's LREF_META_HIDEFIELDS attribute.
	@param binding The type of binding to use.  See LREF_BINDING_* constants.
	@param name The name of the type to use.  Defaults to the name specified
	by the type or its alias.
	@param constructor The name of the constructor.  Defaults to "New[name]"
	
	@note Changing the attribute values from their default will replace the old
	cached values.
EndRem
Function lua_implementtype( state:Byte Ptr, from:TTypeId, expose:Int=-1, static:Int=-1, noclass:Int=-1, hidefields%=-1, binding%=LREF_BINDING_DEFAULT, name$="", constructor$="" )
	Local info:LREF_TypeInfo = LREF_TypeInfo(LREF_TypeCache.ValueForKey(from))
	
	If expose = -1 Then
		expose = info.exposed
	Else
		info.exposed = expose
	EndIf

	If static = -1 Then
		static = info.static
	Else
		info.static = static
	EndIf

	If noclass = -1 Then
		noclass = info.noclass
	Else
		info.noclass = noclass
	EndIf

	If hidefields = -1 Then
		hidefields = info.hidefields
	Else
		info.hidefields = hidefields
	EndIf
	
	If binding = LREF_BINDING_DEFAULT Then
		binding = info.binding
	Else
		If binding < LREF_BINDING_MIN Or LREF_BINDING_MAX < binding Then
			Throw LREF_Exception("Invalid binding code "+binding+" for type "+from.Name(), state)
		EndIf
		info.binding = binding
	EndIf
	
	If Not name Then
		name = info.name
	Else
		info.name = name
	EndIf
	
	If Not constructor Then
		constructor = info.constructor
	Else
		info.constructor = constructor
	EndIf

	If expose Then
		If static Then
			If noclass Then
				LREF_PushBMaxObject( state, from.NewObject(), from )
			Else
				lua_pushstring( state, name )
				LREF_PushBMaxObject( state, from.NewObject(), from, expose, static, noclass )
				lua_settable( state, LUA_GLOBALSINDEX )
			EndIf
		Else
			' function NewName()
			lua_pushstring( state, info.constructor )
			' upvalues - a lot of them
			lref_pushrawobject( state, info )	  ' uv 1
			lua_pushboolean( state, expose )
			lua_pushboolean( state, static )
			lua_pushboolean( state, noclass )
			lua_pushboolean( state, hidefields )
			' closure
			lua_pushcclosure( state, LREF_TypeNew, 5 )

			lua_settable( state, LUA_GLOBALSINDEX )
		EndIf
	EndIf
End Function

Rem:doc
	Auxiliary function to iterate over all types and implement them based on their
attributes.

	@param state The Lua state to expose the Types to.
EndRem
Function lua_implementtypes(state:Byte Ptr)
	Local typeIter:TTypeId

	For typeIter = EachIn TTypeId.EnumTypes()
		lua_implementtype( state, typeIter )
	Next
End Function


' Convenience functions

Rem:doc
	Pushes a BMax object onto the Lua stack.

	@param state The Lua state
	@param obj The object to push onto the stack
	@param excludeMethods Whether or not to include access to methods when
pushing the object onto the stack.  Some speed may be gained in setting this to
True.  Defaults to False.
EndRem
Function lua_pushbmaxobject( state:Byte Ptr, obj:Object, excludeMethods:Int=False )
	If excludeMethods = False Then
		LREF_ConstructBMaxObject( state, obj, Null )
	Else
		LREF_PushBMaxObject( state, obj, Null, False, False, False, True, LREF_BINDING_LATE )
	EndIf
End Function


Rem:doc
	Retrieves an object from the Lua stack.
EndRem
Function lua_tobmaxobject:Object( state:Byte Ptr, idx:Int )
	lua_pushstring(state, LREF_OBJECT_FIELD)
	lua_gettable(state, idx)
	Local obj:Object = lref_torawobject(state, -1)
	lua_pop(state, 1)
	Return obj
End Function


' Can be an array of objects, so excludeMethods is still an argument here
Rem:doc
	Pushes a BMax array of objects as a table.
EndRem
Function lua_pushbmaxarray( state:Byte Ptr, obj:Object, excludeMethods:Int = False )
	Local typeid:TTypeId = TTypeId.ForObject(obj)
	Local idx:Int
	Local arrLen:Int

	If typeid <> ArrayTypeId Then
		If LREF_USE_EXCEPTIONS Then
			Throw LREF_Exception( "lua_pushbmaxarray: obj is not an array", Null )
		EndIf

		lua_pushstring( state, "Error calling lua_pushbmaxarray: obj is not an array" )
		lua_error(state)

		Return
	EndIf

	arrLen = typeid.ArrayLength(obj)
	lua_createtable( state, arrLen, 0 )
	
	Select typeid.ElementType()
		Case FloatTypeId, DoubleTypeId, LongTypeId, IntTypeId, ShortTypeId, ByteTypeId ' These are all numbers!  ('-'\)  .('-')/  (.'-')/
			For idx = 0 To arrLen-1
				lua_pushnumber( state, idx )
				lua_pushnumber( state, String(typeid.GetArrayElement( obj, idx )).ToDouble() )
				lua_settable( state, -3 )
			Next
			
		Case StringTypeId	   ' And this is a ball of yarn.
			For idx = 0 To arrLen-1
				lua_pushnumber( state, idx )
				lua_pushstring( state, String(typeid.GetArrayElement( obj, idx )) )
				lua_settable( state, -3 )
			Next
			
		Case ArrayTypeId
			For idx = 0 To arrLen-1
				lua_pushnumber( state, idx )
				lua_pushbmaxarray( state, typeid.GetArrayElement( obj, idx ) )
				lua_settable( state, -3 )
			Next
			
		Default				 ' This is el presidente.
			For idx = 0 To arrLen-1
				lua_pushnumber( state, idx )
				lua_pushbmaxobject( state, typeid.GetArrayElement( obj, idx ), excludeMethods )
				lua_settable( state, -3 )
			Next
	End Select
End Function

Rem:doc
	Converts a Lua table to a BMax array.
EndRem
Function lua_tobmaxarray:Object[]( state:Byte Ptr, idx:Int )
	Local tableLen:Int
	Local tableInner:Int
	Local arr:Object[]

	If idx < 1 And idx > LUA_REGISTRYINDEX Then
		idx = lua_gettop(state) - (idx+1)
	EndIf

	If lua_type( state, idx ) <> LUA_TTABLE Then
		Return Null
	EndIf

	tableLen = lua_objlen( state, idx )
	If tableLen = 0 Then
		Return New Object[0]
	EndIf

	arr = New Object[tableLen]
	For tableInner = 1 To tableLen
		lua_pushnumber( state, tableInner )
		lua_gettable( state, idx )

		arr[tableInner - 1] = LREF_GetValue( state, idx )
	Next

	Return arr
End Function


' Your key must either BE a string or override ToString to have any meaningful key
Rem:doc
	Pushes a TMap object onto the stack as a table.
EndRem
Function lua_pushbmaxtmap( state:Byte Ptr, map:TMap, excludeMethods:Int = False )
	Local keyval:TNode

	lua_newtable(state)

	For keyval = EachIn map
		lua_pushstring( state, keyval.Key().ToString() )

		If keyval.Value() = Null Then
			lua_pushnil(state)
		ElseIf TTypeId.ForObject(keyval.Value()) = StringTypeId Then
			lua_pushstring( state, String(keyval.Value()) )
		ElseIf TTypeId.ForObject(keyval.Value()) = ArrayTypeId Then
			lua_pushbmaxarray( state, keyval.Value(), excludeMethods )
		Else
			lua_pushbmaxobject( state, keyval.Value(), excludeMethods )
		EndIf

		lua_settable( state, -3 )
	Next
End Function

Rem:doc
	Pushes a TList object onto the stack as a table.
EndRem
Function lua_pushbmaxtlist( state:Byte Ptr, list:TList, excludeMethods:Int = False )
	Local item:Object
	Local idx:Int = 1

	lua_createtable( state, list.Count(), 0 )

	For item = EachIn list
		lua_pushnumber( state, idx )

		If item = Null Then
			lua_pushnil(state)
		ElseIf TTypeId.ForObject(item) = StringTypeId Then
			lua_pushstring( state, String(item) )
		ElseIf TTypeId.ForObject(item) = ArrayTypeId Then
			lua_pushbmaxarray( state, item, excludeMethods )
		Else
			lua_pushbmaxobject( state, item, excludeMethods )
		EndIf

		lua_settable( state, -3 )
		idx :+ 1
	Next
End Function
