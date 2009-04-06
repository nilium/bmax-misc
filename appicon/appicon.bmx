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

?MacOS
Import "appicon.macos.m"
?

Private

?MacOS
Extern "C"
	Function bbSetAppIcon(bytes:Byte Ptr, length:Int)
End Extern
?

Public
Rem:doc
	Set an application's icon.
	
	E.g., under Windows, set the taskbar/window icon.  Under Mac OS, set the
	dock icon.
	@todo Write Windows code.
EndRem
Function AppIcon( url:Object=Null )
	?MacOS
	
	Local stream:TStream = TStream(url)
	Local data@ Ptr = Null
	Local size% = 0
	
	If stream = Null Then
		stream = OpenStream(url)
		If stream = Null Then
			Throw "AppIcon: Could not open stream for URL"
		EndIf
	EndIf
	
	Try
		size = stream.Size()
		If size <= 0 Then
			Throw "AppIcon: Size of stream zero or indeterminable: "+size
		EndIf
	Catch ex:Object
		stream.Close()
		stream = Null
		Throw ex
	End Try
	
	data = malloc_(size)	' using malloc so NSData can free the memory when it's done
	
	stream.ReadBytes(data, size)
	stream.Close()
	stream = Null
	
	If data <> Null And size > 0 Then
		bbSetAppIcon(data, size)
	Else
		Throw "AppIcon: Unable to set dock icon"
	EndIf
	
	?Win32
	
	?Linux
	
	?
End Function
