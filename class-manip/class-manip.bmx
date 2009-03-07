Strict

Import "class-manip.c"

Extern "C"
	Function objFreePtr:Int()
End Extern

'buildopt:debug

Const TAG_BYTE$    ="b"
Const TAG_SHORT$   ="s"
Const TAG_INT$     ="i"
Const TAG_LONG$    ="l"
Const TAG_FLOAT$   ="f"
Const TAG_DOUBLE$  ="d"
Const TAG_STRING$  ="$"

Global SCOPE_NAME:String[] = ["NULL", "FUNCTION", "USERTYPE", "LOCALBLOCK"]
Const SCOPE_FUNCTION=1
Const SCOPE_USERTYPE=2
Const SCOPE_LOCALBLOCK=3

Global DECL_NAME:String[] = ["END", "CONST", "LOCAL", "FIELD", "GLOBAL", "VARPARAM", "TYPEMETHOD", "TYPEFUNCTION", "NULL"]
Const DECL_END = 0
Const DECL_CONST = 1
Const DECL_LOCAL = 2
Const DECL_FIELD = 3
Const DECL_GLOBAL = 4
Const DECL_VARPARAM = 5
Const DECL_TYPEMETHOD = 6
Const DECL_TYPEFUNCTION = 7

Function TagForId$(TypeId:TTypeId)
	Select TypeId
		Case ByteTypeId
			Return "b"
		Case ShortTypeId
			Return "s"
		Case IntTypeId
			Return "i"
		Case LongTypeId
			Return "l"
		Case FloatTypeId
			Return "f"
		Case DoubleTypeId
			Return "d"
		Case StringTypeId
			Return "$"
		Case ArrayTypeId
			Return TagForId(TypeId.ElementType())+"[]"
		Default
			Return ":"+TypeId.Name()
	End Select
End Function

Type IField
	Field Name$
	Field TypeId:TTypeId=IntTypeId
	
	Field _offset:Int
	
	Method Tag$()
		Return TagForId(TypeId)
	End Method
	
	Field c_name:Byte Ptr=Null
	Method WriteName(s:TStream)
		If c_name <> Null Then
			MemFree(c_name)
		EndIf
		c_name = Name.ToCString()
		s.WriteInt(Int c_name)
	End Method
	
	Field c_tag:Byte Ptr=Null
	Method WriteTag(s:TStream)
		If c_tag <> Null Then
			MemFree(c_tag)
		EndIf
		c_tag = Tag().ToCString()
		s.WriteInt(Int c_tag)
	End Method
	
	Method Size()
		Return TypeId._size
	End Method
End Type

Type IMethod
	Field Name$
	Field Pointer@ Ptr
	Field Arguments:TList
	Field ReturnType:TTypeId=IntTypeId
	
	Field _offset:Int
	
	Method New()
		Arguments = New TList
	End Method
	
	Method Tag$()
		Local args$="("
		
		For Local arg:TTypeId = EachIn Arguments
			args :+ TagForId(arg)
			args :+ ","
		Next
		
		If args.Length > 1 Then
			args = args[..args.Length-1]
		EndIf
		
		args :+ ")"
		args :+ TagForId(ReturnType)
		
		Return args
	End Method
	
	Field c_name:Byte Ptr=Null
	Method WriteName(s:TStream)
		If c_name <> Null Then
			MemFree(c_name)
		EndIf
		c_name = Name.ToCString()
		s.WriteInt(Int c_name)
	End Method
	
	Field c_tag:Byte Ptr=Null
	Method WriteTag(s:TStream)
		If c_tag <> Null Then
			MemFree(c_tag)
		EndIf
		c_tag = Tag().ToCString()
		s.WriteInt(Int c_tag)
	End Method
	
	Method AddArgument(OfType:TTypeId)
		Arguments.AddLast(OfType)
	End Method
End Type

Function GenericNew:Int( f% Ptr )
End Function

Function GenericDelete:Int( f% Ptr )
End Function

Type IClass
	Field Name$
	Field SuperClass:TTypeId
	Field Methods:TList
	Field Fields:TList
	
	Field TypeID:TTypeId
	
	Field ClassBank:TBank
	Field Class@ Ptr = Null
	Field DebugDeclBank:TBank
	Field DebugDecl@ Ptr = Null
	Field MethodTable:Int[] = Null
	
	Method New()
		SuperClass = ObjectTypeId
		Methods = New TList
		Fields = New TList
	End Method
	
	Method Delete()
	End Method
	
	Method GenerateTypeId:TTypeId()
		TypeId = New TTypeId.Init(Name, InstanceSize(), Int Class, SuperClass )
		Return TypeId
	End Method
	
	Method Size%()
		Return InstanceSize()+8
	End Method
	
	Method InstanceSize%()
		Local size:Int = 0
		Local sc:TTypeId = SuperClass
		While sc
			size :+ sc._size
			sc = sc.SuperType()
		Wend
		For Local f:IField = EachIn Fields
			size :+ f.Size()
		Next
	End Method
	
	Method AddMethod:IMethod( name$, cb@ Ptr, returnType:TTypeId = Null )
		Local meth:IMethod = New IMethod
		meth.Name = name
		meth.Pointer = cb
		meth._offset = 16+Methods.Count()*4
		
		If returnType Then
			meth.ReturnType = returnType
		EndIf
		
		Methods.AddLast(meth)
		
		Return meth
	End Method
	
	Method AddField:IField( name$, ofType:TTypeId = Null )
		Local f:IField = New IField
		f.Name = name
		
		If ofType Then
			f.TypeId = ofType
		EndIf
		
		f._offset = Size()
		Fields.AddLast(f)
		
		Return f
	End Method
	
	Field c_name:Byte Ptr=Null
	Method WriteName(s:TStream)
		If c_name <> Null Then
			MemFree(c_name)
		EndIf
		c_name = Name.ToCString()
		s.WriteInt(Int c_name)
	End Method
	
	Method BuildClass()
		If ClassBank = Null Then
			ClassBank = TBank.Create(4)
		EndIf
		
		If Class Then
			ClassBank.Unlock()
			Class = Null
		EndIf
		
		Local stream:TStream = TBankStream.Create(ClassBank)
		
		stream.WriteInt(SuperClass._class)
		stream.WriteInt(Int objFreePtr())
		
		BuildDebugDecl()
		
		stream.WriteInt(Int DebugDecl)
		stream.WriteInt(InstanceSize())
		
		For Local m:IMethod = EachIn Methods
			stream.WriteInt(Int m.Pointer)
		Next
		
		Class = ClassBank.Lock()
	End Method
	
	Method BuildDebugDecl()
		If DebugDeclBank = Null Then
			DebugDeclBank = TBank.Create(8)
		EndIf
		
		If DebugDecl Then
			DebugDeclBank.Unlock()
			DebugDecl = Null
		EndIf
		
		Local stream:TStream = TBankStream.Create(DebugDeclBank)
		
		stream.WriteInt(SCOPE_USERTYPE)
		WriteName(stream)
		
		For Local m:IMethod = EachIn Methods
			stream.WriteInt(DECL_TYPEMETHOD)
			m.WriteName(stream)
			m.WriteTag(stream)
			stream.WriteInt(m._offset)
		Next
		
		For Local f:IField = EachIn Fields
			stream.WriteInt(DECL_FIELD)
			f.WriteName(stream)
			f.WriteTag(stream)
			stream.WriteInt(f._offset)
		Next
		
		stream.WriteInt(DECL_END)
		
		DebugDecl = DebugDeclBank.Lock()
	End Method
End Type

'#region Testing

Type DebugScope
	Field _class:Int
	
	Field kind%
	Field name$
	Field decls:TList
	
	Method New()
		kind = 0
		name = ""
		decls = New TList
	End Method
	
	Method Spit()
		Print "Kind: "+SCOPE_NAME[kind]
		Print "Name: "+name
		Print "Decls {"
		For Local i:DebugDecl = EachIn decls
			i.Spit(); Print ""
		Next
		Print "}"
	End Method
	
	Function ForClass:DebugScope(cp@ Ptr)
		Local scope:DebugScope = New DebugScope
		scope._class = Int cp
		Local p% Ptr = Int Ptr cp
		p = Int Ptr p[2]
		scope.kind = p[0]
		scope.name = String.FromCString(Byte Ptr p[1])
		
		p = p + 2
		
		While p[0]
			Local decl:DebugDecl = New DebugDecl
			decl.ref = p
			decl.kind = p[0]
			decl.name = String.FromCString(Byte Ptr p[1])
			decl.tag = String.FromCString(Byte Ptr p[2])
			decl.opaque = p[3]
			scope.decls.AddLast(decl)
			p :+ 4
		Wend
		
		Return scope
	End Function
	
	Function ForName:DebugScope(_type$)
		Local typeid:TTypeId = TTypeId.ForName(_type)
		Return DebugScope.ForClass(Byte Ptr typeid._class)
	End Function
	
	Method DeclForName:DebugDecl(declname$, declkind%)
		For Local i:DebugDecl = EachIn decls
			If i.kind = declkind And i.name = declname
				Return i
			EndIf
		Next
		Return Null
	End Method
End Type

Type DebugDecl
	Field ref@ Ptr
	Field kind%
	Field name$
	Field tag$
	Field opaque%
	
	Method New()
		kind = 8
		opaque = 0
		name = ""
		tag = ""
	End Method
	
	Method Spit()
		Print "Kind:     "+DECL_NAME[kind]
		Print "Name:     "+name
		Print "Tag:      "+tag
		Select kind
			Case DECL_FIELD
				Print "Index:    "+opaque
			Default
				Print "Opaque:   "+opaque
		End Select
	End Method
End Type

'#endregion
