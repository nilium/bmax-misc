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

Private
Global glob_deltat:Float=1.0
Global glob_ctime:Float
Global glob_ltime:Float
Global glob_fps:Float = 1.0 / (1000.0/60.0)
Global glob_fps_frames% = 60
Global glob_fps_time% = 0
Global glob_fpsTimer:TTimer = CreateTimer( 1 )

Public

Function SetGameSpeed( n:Float ) ' expose
    glob_fps = 0.001
    glob_fps_frames = n
End Function

Function GetTicks:Float( ) ' expose
    Return glob_deltat
End Function

Function GetFPS%( ) ' expose
    Return glob_fps_frames
End Function

Private

Function __flipHook:Object( i%, d:Object, c:Object )
    If i = EmitEventHook Then
        Local e:TEvent = TEvent( d )
        If Not e Then Return d
        If e.id = EVENT_TIMERTICK And e.source = glob_fpsTimer Then
            glob_fps_frames = glob_fps_time
            glob_fps_time = 0
        EndIf
    Else
        glob_ltime = glob_ctime
        glob_ctime = Millisecs()
        glob_fps_time :+ 1
        If Int(glob_ltime) = 0 Then Return Null
        glob_deltat = glob_deltat*.025+((glob_ctime-glob_ltime)*glob_fps)*.975
    EndIf
    Return d
End Function
AddHook( FlipHook, __flipHook, Null, 10000 )
AddHook( EmitEventHook, __flipHook, Null, 0 )