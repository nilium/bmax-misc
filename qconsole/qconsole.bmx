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

Import brl.LinkedList

Private

Public

Type IConsole
	Field m_fade# = 0.0
	Field m_consoleLog:TList
	Field m_consoleLength:Int
	Field m_commandRecord:TList
	Field m_commandCount:Int
	Field m_state:Int = ST_CLOSED
	Field m_input:TLink
	Field m_inputPos%=0
	Field m_tempInput%=0
	Field m_cvars:TMap
	Field m_hooked:Int=False

	Const ST_OPEN%		 =1
	Const ST_OPENING%	 =2
	Const ST_CLOSED%	 =3
	Const ST_CLOSING%	 =4

	Const CONSOLE_SPEED# = .01

	Method New()
		m_commandRecord = New TList
		m_commandCount = 0

		m_input = m_commandRecord.AddFirst("")

		m_consoleLog = New TList
		m_consoleLength = 0

		m_cvars = New TMap
	End Method
	
	Method Delete()
		m_cvars.Clear()
		m_commandRecord.Clear()
		m_consoleLog.Clear()
	End Method
	
	Method Hook()
		If m_hooked Then
			Return
		EndIf

		AddHook(EmitEventHook, ConsoleEventHook, Self)
		m_hooked = True
	End Method

	Method Unhook()
		If Not m_hooked Then
			Return
		EndIf

		RemoveHook(EmitEventHook, ConsoleEventHook, Self)
		m_hooked = False
	End Method

	Method Dispose()
		Unhook()
	End Method

	Method Write( msg$ )
		If msg.Contains("~n") Then
			For Local line$ = EachIn msg.Split("~n")
				Write(line)
			Next
		Else
			If m_consoleLength = 200 Then
				m_consoleLog.Last()
				m_consoleLog.RemoveLast()
			EndIf

			m_consoleLog.AddFirst( msg )
		EndIf
	End Method

	Method Draw( ticks#=1.0 )
		If ticks > 0 Then
			Select m_state	' Transition states
				Case ST_OPENING
					m_fade = Min(1, m_fade+(ticks*CONSOLE_SPEED))

					If m_fade > .998 Then
						m_state = ST_OPEN
					EndIf

				Case ST_CLOSING
					m_fade = Max(0, m_fade-(ticks*CONSOLE_SPEED))

					If m_fade < .002 Then
						m_state = ST_CLOSED
					EndIf
			End Select
		EndIf

		If m_state = ST_CLOSED Then
			Return
		EndIf

		' This is hacky, but: render the console

		Local height% = (GraphicsHeight()/2)*m_fade

		SetBlend( ALPHABLEND )
		SetAlpha( m_fade )

		SetColor( 64, 8, 8 )
		DrawRect( 0, 0, GraphicsWidth(), height )
		SetColor( 96, 96, 96 )
		DrawRect( 0, height-2, GraphicsWidth(), 2 )

		SetColor( 255, 255, 255 )
		
		Local txt$ = String(m_input._value)
		
		Local theight% = TextHeight(txt)
		Local tpos% = height-TextHeight(txt)-4

		DrawText( txt, theight/4+8, tpos )

		Local curPos% = theight/4+8+TextWidth( txt[..m_inputPos] )
		DrawRect( 2, tpos, theight/4, theight )

		SetAlpha( Abs(Sin(Millisecs()*ticks)*m_fade) )
		SetLineWidth(2)
		DrawRect( curPos, tpos, 2, theight-1 )
		
		SetAlpha( m_fade )

		Local logPos% = tpos-2
		Local msg:TLink = m_consoleLog.FirstLink()

		While logPos > 0 And msg
			Local text$ = String msg.Value()
			theight = TextHeight(text)
			DrawText( text, 8, logPos-theight )
			logPos = logPos - theight - 4
			msg = msg.NextLink()
		Wend
	End Method

	Method Open()
		If m_state <> ST_OPEN Then
			m_state = ST_OPENING
		EndIf
	End Method

	Method Close()
		If m_state <> ST_CLOSED Then
			m_state = ST_CLOSING
		EndIf
	End Method

	Method Toggle()
		If m_state >= ST_CLOSED Then
			Open()
		Else
			Close()
		EndIf
	End Method

	' Returns whether or not the evt should continue being processed after the console has handled it
	' True if to process the event
	' False if the event has been handled and the program should not continue handling it
	Method HandleInput%( evt:TEvent )
		If evt = Null Then
			Throw "Cannot process null event"
		Else
			Local txt$ = String(m_input._value)
			Select evt.Id
				Case EVENT_KEYCHAR
					Local char$ = String.FromShorts( Short Ptr Varptr evt.Data, 1 )

					If evt.Data = 8 Then		' KEY_BACKSPACE
						If m_inputPos = txt.Length And txt.Length > 0 Then
							txt = txt[..txt.Length-1]
							m_input._value = txt
							m_inputPos :- 1
						ElseIf m_inputPos > 0 Then
							txt = txt[..m_inputPos-1]+txt[m_inputPos..]
							m_input._value = txt
							m_inputPos :- 1
						EndIf

						Return False
					ElseIf evt.Data < 32 Then
						Return False
					EndIf

					If char = "`" Or char = "~~" Then
						Toggle()
						Return False
					EndIf
					
					If m_state = ST_CLOSED Or m_state = ST_CLOSING Then
						Return True
					EndIf

					If m_input.PrevLink() <> Null Then ' Copy input to new link since we're modifying it
						Local firstLink:TLink = m_commandRecord.FirstLink()
						firstLink._value = m_input._value
						m_input = firstLink
					EndIf

					If m_inputPos = txt.Length Then
						txt :+ char
						m_input._value = txt
					ElseIf m_inputPos = 0 Then
						txt = char + txt
						m_input._value = txt
					Else
						txt = txt[..m_inputPos]+char+txt[m_inputPos..]
						m_input._value = txt
					EndIf

					m_inputPos :+ 1
					
					Return False

				Case EVENT_KEYDOWN
					If m_state = ST_CLOSED Or m_state = ST_CLOSING Then
						Return True
					EndIf

					Select evt.data
						Case KEY_BACKSPACE
							' Moved to handle repeating keys

						Case KEY_DELETE
							If m_inputPos = 0 And txt.Length > 0 Then
								txt = txt[..txt.Length=1]
								m_input._value = txt
							ElseIf m_inputPos < txt.Length Then
								txt = txt[..m_inputPos]+txt[m_inputPos+1..]
								m_input._value = txt
							EndIf

						Case KEY_LEFT
							If m_inputPos > 0 Then
								m_inputPos :- 1
							EndIf

						Case KEY_RIGHT
							If m_inputPos < txt.Length Then
								m_inputPos :+ 1
							EndIf

						Case KEY_ENTER
							If m_input.PrevLink() Then
								Local firstLink:TLink = m_commandRecord.FirstLink()
								firstLink._value = m_input._value
								m_input = firstLink
							EndIf

							ProcessCommand( txt )
							m_input = m_commandRecord.AddFirst("")
							m_inputPos = 0

						Case KEY_UP
							If m_input.NextLink() <> Null Then
								m_input = m_input.NextLink()
								m_inputPos = txt.Length
							EndIf

						Case KEY_DOWN
							If m_input.PrevLink() <> Null Then
								m_input = m_input.PrevLink()
								m_inputPos = txt.Length
							EndIf

						Case KEY_END
							m_inputPos = txt.Length

						Case KEY_HOME
							m_inputPos = 0
					End Select

					Return False	' All keyboard input is redirected to the console when open, so nothing else will get it
			End Select
		EndIf
		
		Return True
	End Method

	Method ProcessCommand( cmd$ )
		Local cmdArgs$[2]

		If cmd.Contains(" ") Then
			cmdArgs[0] = cmd[..cmd.Find(" ")].ToLower()
			cmdArgs[1] = cmd[cmdArgs[0].Length+1..].Trim()
		Else
			cmdArgs[0] = cmd.ToLower()
			cmdArgs[1] = Null
		EndIf

		Local keyval:Object = m_cvars.ValueForKey(cmdArgs[0])
		Local concmd:ICFunction = ICFunction(keyval)
		Local cvar:ICVar = ICVar(keyval)

		If keyval = Null And cmdArgs[1] <> Null Then
			cvar = New ICVar

			cvar.name = cmdArgs[0]
			cvar.value = cmdArgs[1]

			m_cvars.Insert( cmdArgs[0].ToLower(), cvar )

			Write(cvar.name+" = "+cvar.value)
		ElseIf cvar <> Null Then
			If cmdArgs[1] <> Null Then
				cvar.value = cmdArgs[1]

				Write(cvar.name+" = "+cvar.value)
			Else
				Write(cvar.name+" = "+cvar.value)
			EndIf
		ElseIf concmd <> Null Then
			concmd.Invoke( Self, cmdArgs[0], cmdArgs[1] )
		EndIf
	End Method

	Method SetCVar( name$, value$ )
		name = name.ToLower().Trim()

		Local keyval:Object = m_cvars.ValueForKey(name)
		Local cvar:ICVar = ICVar(keyval)

		If keyval <> Null And cvar = Null Then
			Throw "Invalid Operation"
		EndIf

		If cvar = Null And value <> Null Then

			cvar = New ICVar

			cvar.name = name
			cvar.value = value

			m_cvars.Insert( name, cvar )

		Else
			If value = Null Then
				m_cvars.Remove( name )
			Else
				cvar.value = value
			EndIf

		EndIf
	End Method

	Method GetCVar$( name$, defaultValue$=Null )
		name = name.ToLower().Trim()

		Local keyval:Object = m_cvars.ValueForKey(name)
		Local cvar:ICVar = ICVar(keyval)

		If (cvar = Null And keyval <> Null) Or (cvar = Null And defaultValue <> Null And keyval = Null) Then
			Throw "Invalid Operation"
		EndIf

		If cvar = Null And defaultValue <> Null Then
			cvar = New ICVar

			cvar.name = name
			cvar.value = defaultValue

			m_cvars.Insert( name, cvar )
		EndIf

		Return cvar.value
	End Method

	Method AddCommand( command:ICFunction )
		Local idx%

		For idx = 0 Until command.GetNameCount()
			Local name$ = command.GetName(idx).ToLower().Trim()
			Local keyval:Object = m_cvars.ValueForKey(name)
			Local cmd:ICFunction = ICFunction(keyval)

			If keyval = Null Then
				m_cvars.Insert(name, command)
			ElseIf keyval = Null And cmd <> command Then
				Throw "Invalid Operation"
			EndIf
		Next
	End Method

	Method RemoveCommand( name$, command:ICFunction )
		Local idx%

		For idx = 0 Until command.GetNameCount()
			Local name$ = command.GetName(idx).ToLower().Trim()

			If m_cvars.ValueForKey(name) = command Then
				m_cvars.Remove(name)
			Else
				Throw "Invalid Operation"
			EndIf
		Next
	End Method

	Function ConsoleEventHook:Object( id%, data:Object, ctx:Object )
		Local console:IConsole = IConsole(ctx)

		If console = Null Then
			Return data
		EndIf
		
		console.HandleInput( TEvent(data) )
		
		Return data
	End Function
End Type


Private

Type ICVar Final
	Field name$
	Field value$

	Method ToString$()
		Return name
	End Method

	Method Compare%( other:Object )
		If other = Null Then
			Throw "Cannot compare Self to null"
		EndIf

		Return name.Compare( other.ToString() )
	End Method
End Type


Public

Type ICFunction
	Method Invoke( from:IConsole, name$, args$ ) Abstract
	Method GetName$( idx%=0 ) Abstract
	Method GetNameCount%( ) Abstract
End Type


Public

Type ICCallback Extends ICFunction Final
	Field callback( from:IConsole, name$, args$ )
	Field name$

	Function Create:ICCallback( name$, callback(f:IConsole,n$,a$) )
		Local cb:ICCallback = New ICCallback

		cb.name = name
		cb.callback = callback

		Return cb
	End Function

	Method Invoke( from:IConsole, name$, args$ )
		If callback = Null Then
			Return
		EndIf

		callback( from, name, args )
	End Method

	Method GetName$( idx%=0 )
		Return name
	End Method

	Method GetNameCount%( )
		Return 1
	End Method
End Type

Type ICExtCallback Extends ICFunction Final
	Field callback( from:IConsole, name$, args$ )
	Field names$[]
		
	Function Create:ICExtCallback( names$[], callback(f:IConsole,n$,a$) )
		Local cb:ICExtCallback = New ICExtCallback

		cb.names = names
		cb.callback = callback

		Return cb
	End Function

	Method Invoke( from:IConsole, name$, args$ )
		If callback = Null Then
			Return
		EndIf

		callback( from, name, args )
	End Method

	Method GetName$( idx%=0 )
		Return names[idx]
	End Method

	Method GetNameCount%( )
		Return names.Length
	End Method	
End Type
