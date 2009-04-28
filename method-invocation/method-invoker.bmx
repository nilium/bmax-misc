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

Rem
Note: There is no guarantee that when you are not using the threaded GC that
an object will not go out of scope and be collected.  You should be doing
something to retain all of your objects prior to setting them as arguments.
EndRem

Import "-lffi"
Import "fin-support.c"

Private
Function fin_objptr:Byte Ptr(p:Byte Ptr) NoDebug
	Return p-8
End Function


Rem
' unused for the time being
Function fin_objretain:Byte Ptr(p:Byte Ptr) NoDebug
	?Threaded
	Return p-8
	?Not Threaded
	p :- 4
	(Int Ptr p)[0] :+ 1
	Return p-4
	?
End Function

Function fin_objrelease(p:Byte Ptr) NoDebug
	?Not Threaded
	p :- 4
	(Int Ptr p)[0] :- 1
	?
End Function
EndRem

Function fin_ffi_type_for_typeid:Byte Ptr(id:TTypeId, size:Int Ptr=Null)
	Select id
		Case ByteTypeID
			If size Then size[0] = 1
			Return ptr_ffi_type_uint8
		Case ShortTypeID
			If size Then size[0] = 2
			Return ptr_ffi_type_uint16
		Case IntTypeID
			If size Then size[0] = 1
			Return ptr_ffi_type_sint32
		Case LongTypeID
			If size Then size[0] = 2
			Return ptr_ffi_type_sint64
		Case FloatTypeID
			If size Then size[0] = 1
			Return ptr_ffi_type_float
		Case DoubleTypeID
			If size Then size[0] = 2
			Return ptr_ffi_type_double
		Default
			If size Then size[0] = 1
			Return ptr_ffi_type_pointer
	End Select
End Function


Extern "C" ' the following globals are pointers to their actual values because I am lazy
	Global ptr_ffi_type_void:Byte Ptr       = "ptr_ffi_type_void"
	Global ptr_ffi_type_uint8:Byte Ptr      = "ptr_ffi_type_uint8"
	Global ptr_ffi_type_sint8:Byte Ptr      = "ptr_ffi_type_sint8"
	Global ptr_ffi_type_uint16:Byte Ptr     = "ptr_ffi_type_uint16"
	Global ptr_ffi_type_sint16:Byte Ptr     = "ptr_ffi_type_sint16"
	Global ptr_ffi_type_uint32:Byte Ptr     = "ptr_ffi_type_uint32"
	Global ptr_ffi_type_sint32:Byte Ptr     = "ptr_ffi_type_sint32"
	Global ptr_ffi_type_uint64:Byte Ptr     = "ptr_ffi_type_uint64"
	Global ptr_ffi_type_sint64:Byte Ptr     = "ptr_ffi_type_sint64"
	Global ptr_ffi_type_float:Byte Ptr      = "ptr_ffi_type_float"
	Global ptr_ffi_type_double:Byte Ptr     = "ptr_ffi_type_double"
	Global ptr_ffi_type_longdouble:Byte Ptr = "ptr_ffi_type_longdouble"
	Global ptr_ffi_type_pointer:Byte Ptr    = "ptr_ffi_type_pointer"
	
	Function ffi_prep_cif:Int(cif:Byte Ptr, abi:Int, nargs:Int, rtype:Byte Ptr, atypes:Byte Ptr Ptr)
	Function ffi_prep_closure:Int(closure:Byte Ptr, cif:Byte Ptr, fun(cif:Byte Ptr, result:Byte Ptr, args:Byte Ptr Ptr, user_data:Byte Ptr), user_data:Byte Ptr)
	Function ffi_call(cif:Byte Ptr, fn:Byte Ptr, rvalue:Byte Ptr, avalue:Byte Ptr Ptr)
End Extern

Type ffi_abi Final {CEnum}
	Const FFI_FIRST_ABI% = 0
	Const FFI_SYSV% = 1
	?Win32
	Const FFI_STDCALL% = 2
	Const FFI_DEFAULT_ABI% = FFI_SYSV
	?MacOSPPC
	Const FFI_AIX% = 2
	Const FFI_DARWIN% = 3
	Const FFI_DEFAULT_ABI% = FFI_AIX
	?MacOSX86
	Const FFI_UNIX64% = 2
	Const FFI_DEFAULT_ABI% = FFI_SYSV
	?Linux
	Const FFI_UNIX64% = 2
	Const FFI_DEFAULT_ABI% = FFI_SYSV
	?
	Const FFI_LAST_ABI% = FFI_DEFAULT_ABI+1
End Type

Type ffi_cif Final {CStruct}
	Field abi:Int
	Field nargs:Int
	Field arg_types:Byte Ptr Ptr	' ffi_type**
	Field rtype:Byte Ptr
	Field bytes:Int
	Field flags:Int
	' extra fields?
End Type

Type ffi_status Final {CEnum}
	Const FFI_OK%=0, FFI_BAD_TYPEDEF%=1, FFI_BAD_ABI%=2
End Type

Public

Type CMethodInvocation
	Field _name$=""
	Field _fn:Byte Ptr = Null
	Field _target:Object = Null
	Field _cif:ffi_cif
	Field _args:Int[] = Null
	Field _argPtrs:Byte Ptr[] = Null
	Field _argOffsets:Int[] = Null
	Field _argTypes:Byte Ptr[] = Null
	Field _returnType:Byte Ptr
	Field _returnValue:Int[] = Null
	Field _returnObject:Object = Null
	
	Method New()
		_cif = New ffi_cif
	End Method
	
	Method _retPtr:Byte Ptr()
		If _returnType = ptr_ffi_type_pointer Then
			Return ((Byte Ptr Varptr _returnType)+8)
		Else
			Return Varptr _returnValue[0]
		EndIf
	End Method
	
	Method Copy:CMethodInvocation()
		Local nmi:CMethodInvocation = New CMethodInvocation
		nmi._name = _name
		nmi._fn = _fn
		nmi._target = _target
		nmi._cif.abi = _cif.abi
		nmi._cif.nargs = _cif.nargs
		nmi._cif.arg_types = _cif.arg_types
		nmi._cif.rtype = _cif.rtype
		nmi._cif.bytes = _cif.bytes
		nmi._cif.flags = _cif.flags
		nmi._args = _args[..]
		nmi._argOffsets = _argOffsets[..]
		nmi._argPtrs = New Byte Ptr[nmi._argOffsets.Length]
		For Local idx:Int = 0 Until nmi._argPtrs.Length
			nmi._argPtrs[idx] = Varptr nmi._args[nmi._argOffsets[idx]]
		Next
		nmi._argTypes = _argTypes[..]
		nmi._returnType = _returnType
		If _returnValue Then
			nmi._returnValue = New Int[_returnValue.Length]
		EndIf
		Return nmi
	End Method
	
	Method InitWithNamedMethod:CMethodInvocation(name$, argTypes:TTypeID[], returnType:TTypeID)
		_name = name
		Local offset:Int = 1
		Local argDim:Int = 0
		
		_argTypes = New Byte Ptr[argTypes.Length+1]
		_argOffsets = New Int[_argTypes.Length]
		_argPtrs = New Byte Ptr[_argTypes.Length]
		_argTypes[0] = ptr_ffi_type_pointer
		_argOffsets[0] = 0
		
		For Local idx:Int = 0 Until argTypes.Length
			_argOffsets[idx+1] = offset
			_argTypes[idx+1] = fin_ffi_type_for_typeid(argTypes[idx], Varptr argDim)
			offset :+ argDim
		Next
		
		_args = New Int[offset]
		For Local idx:Int = 0 Until _argOffsets.Length
			_argPtrs[idx] = Varptr _args[_argOffsets[idx]]
		Next
		
		_returnType = fin_ffi_type_for_typeid(returnType, Varptr argDim)
		If _returnType <> ptr_ffi_type_pointer Then
			_returnValue = New Int[argDim]
		EndIf
		
		Local stat:Int = ffi_prep_cif(_cif, ffi_abi.FFI_DEFAULT_ABI, _argTypes.Length, _returnType, _argTypes)
		If stat = ffi_status.FFI_BAD_TYPEDEF Then
			Throw "FFI_BAD_TYPEDEF"
		ElseIf stat = ffi_status.FFI_BAD_ABI Then
			Throw "FFI_BAD_ABI"
		EndIf
		
		Return Self
	End Method
	
	Method InitWithMethod:CMethodInvocation(meth:TMethod)
		Return InitWithNamedMethod(meth.Name(), meth.ArgTypes(), meth.TypeID())
	End Method
	
	Method MethodPointer:Byte Ptr()
		If _target = Null Then
			Return Null
		Else
			If _fn = Null Then
				Local typeid:TTypeID = TTypeId.ForObject(_target)
				Local meth:TMethod = typeid.FindMethod(_name)
				Assert meth, "Method for name ~q"+_name+"~q not found"
				
				' verify that the method matches the invocation specs
				Local argTypes:TTypeId[] = meth.ArgTypes()
				Assert argTypes.Length = (_argTypes.Length-1), "Method parameters do not match invocation parameters"
				For Local idx:Int = 0 Until argTypes.Length
					Assert fin_ffi_type_for_typeid(argTypes[idx]) = _argTypes[idx+1], "Method parameters do not match invocation parameters"
				Next
				
				Assert _returnType = fin_ffi_type_for_typeid(meth.TypeId()), "Method return type does not match invocation return type"
				
				_fn = (Byte Ptr Ptr(Byte Ptr(typeid._class)+meth._index))[0]
			EndIf
			Return _fn
		EndIf
	End Method
	
	Method SetTarget(o:Object)
		If _target <> o Then
			_fn = Null
		EndIf
		_target = o
		SetObjectArgument(o, 0)
		MethodPointer()
	End Method
	
	Method Target:Object()
		Return _target
	End Method
	
	Method ReturnedObject:Object()
		If _returnType <> ptr_ffi_type_pointer Then
			Throw "Invalid Operation"
		EndIf
		Return _returnObject
	End Method
	
	Method ReturnedValue(buf@ Ptr)
		Select _returnType
			Case ptr_ffi_type_uint8, ptr_ffi_type_sint8
				(Byte Ptr buf)[0] = _returnValue[0]
			Case ptr_ffi_type_uint16, ptr_ffi_type_sint16
				(Short Ptr buf)[0] = _returnValue[0]
			Case ptr_ffi_type_uint32, ptr_ffi_type_sint32, ptr_ffi_type_float
				(Int Ptr buf)[0] = _returnValue[0]
			Case ptr_ffi_type_uint64, ptr_ffi_type_sint64, ptr_ffi_type_double
				(Int Ptr buf)[0] = _returnValue[0]
				(Int Ptr buf)[1] = _returnValue[1]
			Default
				Throw "Invalid Operation"
		End Select
	End Method
	
	Method ReturnedInt:Int()
		If _returnType = ptr_ffi_type_pointer Or _returnType = ptr_ffi_type_void Then
			Throw "Invalid operation"
		EndIf
		Return _returnValue[0]
	End Method
	
	Method ReturnedFloat:Float()
		If _returnType = ptr_ffi_type_pointer Or _returnType = ptr_ffi_type_void Then
			Throw "Invalid operation"
		EndIf
		Return (Float Ptr Varptr _returnValue[0])[0]
	End Method
	
	Method ReturnedLong:Long()
		If _returnType = ptr_ffi_type_pointer Or _returnType = ptr_ffi_type_void Then
			Throw "Invalid operation"
		EndIf
		Local l:Long
		ReturnedValue(Varptr l)
		Return l
	End Method
	
	Method ReturnedDouble:Double()
		If _returnType = ptr_ffi_type_pointer Or _returnType = ptr_ffi_type_void Then
			Throw "Invalid operation"
		EndIf
		Local d:Double
		ReturnedValue(Varptr d)
		Return d
	End Method
	
	Method ReturnedPointer:Byte Ptr()
		If _returnType = ptr_ffi_type_pointer Or _returnType = ptr_ffi_type_void Then
			Throw "Invalid operation"
		EndIf
		Return Byte Ptr _returnValue[0]
	End Method
	
	Method SetByteArgument( b:Int, index:Int )
		SetIntArgument(b,index)
	End Method
	
	Method SetShortArgument( s:Int, index:Int )
		SetIntArgument(s,index)
	End Method
	
	Method SetIntArgument( i:Int, index:Int )
		Local sz:Int = ArgumentSize(index)
		If sz = 0 Then
			Throw "Invalid Operation"
		EndIf
		Local offset:Int = _argOffsets[index]
		If sz > 4 Then
			_args[offset+1]=%0
		EndIf
		_args[offset] = i
	End Method
	
	Method SetPointerArgument( p:Byte Ptr, index:Int )
		Local sz:Int = ArgumentSize(index)
		If sz = 0 Then
			Throw "Invalid Operation"
		EndIf
		Local offset:Int = _argOffsets[index]
		If sz > 4 Then
			_args[offset+1]=%0
		EndIf
		_args[offset] = Int p
	End Method
	
	Method SetLongArgument( l:Long, index:Int )
		If ArgumentSize(index) < 8 Then
			Throw "Invalid Operation"
		EndIf
		Local p:Int Ptr = Int Ptr Varptr l
		Local offset:Int = _argOffsets[index]
		_args[offset] = p[0]
		_args[offset+1] = p[1]
	End Method
	
	Method SetFloatArgument( f:Float, index:Int )
		Local sz:Int = ArgumentSize(index)
		If sz < 1 Then
			Throw "Invalid Operation"
		EndIf
		Local offset:Int = _argOffsets[index]
		If sz > 4 Then
			_args[offset+1]=%0
		EndIf
		_args[offset] = (Int Ptr Varptr f)[0]
	End Method
	
	Method SetDoubleArgument( d:Double, index:Int )
		If ArgumentSize(index) < 8 Then
			Throw "Invalid Operation"
		EndIf
		Local p:Int Ptr = Int Ptr Varptr d
		Local offset:Int = _argOffsets[index]
		_args[offset] = p[0]
		_args[offset+1] = p[1]
	End Method
	
	Method SetObjectArgument( o:Object, index:Int )
		Local sz:Int = ArgumentSize(index)
		If sz < 1 Then
			Throw "Invalid Operation"
		EndIf
		Local offset:Int = _argOffsets[index]
		If sz > 4 Then
			_args[offset+1]=%0
		EndIf
		_args[offset] = Int fin_objptr(o)
	End Method
	
	Method ArgumentSize:Int( index:Int )
		Select _argTypes[index]
			Case ptr_ffi_type_uint8, ptr_ffi_type_sint8
				Return 1
			Case ptr_ffi_type_uint16, ptr_ffi_type_sint16
				Return 2
			Case ptr_ffi_type_uint32, ptr_ffi_type_sint32, ptr_ffi_type_float, ptr_ffi_type_pointer
				Return 4
			Case ptr_ffi_type_uint64, ptr_ffi_type_sint64, ptr_ffi_type_double
				Return 8
			Default
				Return 0
		End Select
	End Method
	
	Method Invoke()
		Local fp:Byte Ptr = MethodPointer()
		Assert _target, "Target is Null"
		Assert fp, "Method pointer not found"
		Local stat:Int = ffi_call(_cif, _fn, _retPtr(), _argPtrs)
	End Method
End Type
