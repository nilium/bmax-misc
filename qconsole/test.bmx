Strict

'buildopt:gui

Import "qconsole.bmx"

Type ICBasicCommand Extends ICFunction Final
	Method Invoke( from:IConsole, name$, args$ )
		Select name
			Case "quit"
				Running = False

			Case "echo"
				from.Write( args )
		End Select
	End Method

	Method GetName$( idx%=0 )
		Select idx
			Case 0
				Return "quit"

			Case 1
				Return "echo"

			Default
				Return ""
		End Select
	End Method
	
	Method GetNameCount%()
		Return 2
	End Method
End Type

Global Running% = True

Local console:IConsole

SetGraphicsDriver(GLMax2DDriver())
Graphics(800, 600, 0, 0)

EnablePolledInput()

console = New IConsole
'console.Hook()
console.AddCommand( New ICBasicCommand )

While Running
	While PollEvent() <> 0
		If console.HandleInput( CurrentEvent ) = True Then
			Select CurrentEvent.Id
				Case EVENT_APPTERMINATE
					Running = False
	
				Case EVENT_KEYDOWN
					If CurrentEvent.Data = KEY_ESCAPE Then
						Running = False
					EndIf
					
				Case EVENT_KEYCHAR
					If Chr(CurrentEvent.Data) = "`" And (Not (CurrentEvent.mods&MODIFIER_SHIFT)) Then
						console.Toggle()
					EndIf
					
				Default
			End Select
		EndIf
	Wend

	Cls()
	console.Draw(.5)
	Flip()
Wend

'console.Unhook()

End
