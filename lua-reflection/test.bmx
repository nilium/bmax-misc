Strict

''buildopt:gui

Import Brl.Blitz
Import Brl.Reflection
Import Brl.Max2D
Import Brl.GLMax2D
Import pub.Lua

Import "lua-reflection.bmx"

Global Running:Int = False

SetGraphicsDriver( GLMax2DDriver() )
If Graphics(800, 600, 0, 0) Then
	Running = True
EndIf

Local lvm@ Ptr = luaL_newstate()
If lvm = Null Then
	DebugLog("Failed to create Lua state")
	Running = False
EndIf

lua_implementtypes(lvm)
' force settings for these two
lua_implementtype(lvm, TTypeId.ForName("Object"), True, False, False, True)
lua_implementtype(lvm, TTypeId.ForName("TEvent"), True, False, False, False)

luaopen_base(lvm)
luaL_dofile(lvm, "test.lua")

While Running
	While PollEvent()
		Select CurrentEvent.id
			Case EVENT_KEYDOWN
				If CurrentEvent.data = KEY_ESCAPE Then
					Running = False
				EndIf
				
			Case EVENT_APPTERMINATE
				Running = False
				
			Default
				lua_pushstring(lvm, "HandleEvent")
				lua_gettable(lvm, LUA_GLOBALSINDEX)
				lua_pushbmaxobject(lvm, CurrentEvent)
				lua_call(lvm, 1, 1)
				If lua_type(lvm, -1) = LUA_TBOOLEAN Then
					Running = lua_toboolean(lvm, -1)
					Print "Running set to: "+Running
				EndIf
				lua_pop(lvm, 1)
		End Select
	Wend
	
	Cls
	
	lua_pushstring(lvm, "DrawScreen")
	lua_gettable(lvm, LUA_GLOBALSINDEX)
	lua_call(lvm, 0, 0)
	
	Flip
Wend

EndGraphics()
End


' ----- Exposed

Type GraphicsClass {expose noclass static}
	Method SetColor2D( r@, g@, b@ )
		SetColor(r, g, b)
	End Method
	
	Method DrawRect2D( x@@, y@@, w@@, h@@ )
		DrawRect(x, y, w, h)
	End Method
	
	Method NotAccessible:Int() {hidden}
		Print "No worky"
	End Method
End Type
