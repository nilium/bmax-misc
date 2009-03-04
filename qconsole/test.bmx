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
