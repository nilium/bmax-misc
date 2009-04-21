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

Import "../collections/collections.bmx"

Private
Global buf@[8192] ' Buffer of data to be parsed
Global shrts:Short[128] ' Buffer for what used to be nam$ in IPNode.ReadNodes

Public

Rem
bbdoc: Sets the size of the buffer that's parsed.  When Parse is parsing a document, it reads a maximum amount of @size bytes to parse and parses them.  This repeats until the document reaches its maximum position (typically either EOF or until a specified size limit is reached).
notes: The default @size is 8192 (8kb -- shouldn't be too much for most cases)
EndRem
Function SetParseCacheSize( size%=8192 )
    buf = New Byte[size]
End Function

Rem
bbdoc: Managed interface for a collection of IPNodes.
EndRem
Type IPDoc
    Rem
    bbdoc: The root of the IPDoc
    EndRem
    Field Root:IPNode

    Method New()
        root = New IPNode
    End Method
    
    Method Delete()
        root.Dispose()
    End Method

    Rem
    bbdoc: Load an IPDoc from a @source.
    EndRem
    Function Load:IPDoc( source:Object )
        Assert source, "Null URL passed to LoadParseDoc"

        Local stream:TStream = TStream(source)
        If stream = Null Then stream = ReadStream( source )

        Assert stream, "Failed to read stream ["+source.ToString( )+"]"

        Local doc:IPDoc = New IPDoc

        doc.root.Read( stream )

        Return doc
    End Function
    
    Rem
    bbdoc: Create an empty IPDoc.
    EndRem
    Function Create:IPDoc( name$="" )
        Local doc:IPDoc = New IPDoc
        doc.root.Name = name
        Return doc
    End Function

    Rem
    bbdoc: Write the IPDoc to a stream.
    EndRem
    Method Write( stream:TStream )
        root.Write( stream )
    End Method
End Type

Rem
bbdoc: A node in an Parse document tree.  A node has functions for reading
EndRem
Type IPNode
    Field link:ILink
    Rem
    bbdoc: The name of the node.
    EndRem
    Field Name$
    Rem
    bbdoc: The node's attributes/properties.
    EndRem
    Field Attrs:IList = New IList
    Rem
    bbdoc: The node's children.
    EndRem
    Field Children:IList = New IList
    Rem
    bbdoc: The node's parent node.
    EndRem
    Field Parent:IPNode = Null
    
    ' Useful for spitting out errors when parsing a valid Parse document with bad input
    Field _line%=0
    Field _colm%=0
    
    Rem
    bbdoc: Gets the line number the node was found on.
    EndRem
    Method GetLine%( )
        Return _line
    End Method
    
    Rem
    bbdoc: Gets the column number the node was found on.
    EndRem
    Method GetColumn%( )
        Return _colm
    End Method
    
    Method LineCol$( )
        Return "["+_line+":"+_colm+"]"
    End Method

    Rem
    bbdoc: Reads a set of nodes from a stream, optionally passing the amount of bytes to read up to (instead of reading until EOF) to @size.<br/>
    The method will not seek to the beginning of the stream, so if you pass -1 to @size then it will calculate the size of data as @res.Size( ) - @res.Pos( ).<br/>
    Endrem
    Method Read( res:TStream, size%=-1, sline%=1, scolumn%=1 )
        Const E_NAME% = 0
        Const R_NAME% = 2
        Const E_OPEN% = 4
        Const RF_VALUE% = 6
        Const R_COMMENT% = 8
        
        Assert res,"Failed to read file"

        If size <= -1 Then size = res.Size( )-res.Pos( )
        Local s% = E_NAME, s_last%
        Local node:IPNode = Self
        Local nf:IPAttr
        Local c%=0
        Local escape%
        Local line%=sline
        Local col%=scolumn
        _line = line
        _colm = col
        Local sz%=0
        Local cfield%=0
        Local lc%
        Local si%=0
        
        While size > 0
            sz = Min(buf.Length, size)
            res.ReadBytes( buf, sz )
            size :- buf.Length
            For Local i:Int = 0 To sz-1
                lc = c
                c = buf[i]
                If c = 13 Or c = 0 Then Continue
                col :+ 1
                
                If c = 35 And escape = 0 And s <> R_COMMENT Then
                    If s = R_NAME Then
                        s = E_OPEN
                    ElseIf s = RF_VALUE
                        nf.Content = String.FromShorts( shrts, si )
                        si = 0
                        s = E_NAME
                    EndIf
    
                    s_last = s
                    s = R_COMMENT
                EndIf
    
                If c = 10 Then
                    line :+ 1
                    col = 0
                    If s = R_COMMENT Then
                        s = s_last
                    EndIf
                EndIf
                
              '  DebugLog "["+line+":"+col+":"+s+"] "+c
                
                If s = R_COMMENT Then Continue
                
                If c = 10 And escape Then
                    escape = 0
                    Continue
                EndIf
                
                If (c = 32 Or c = 9) And (lc = 32 Or lc = 9) Then
                    Continue
                EndIf

                If c = 92 And escape = 0 Then
                    escape = 1
                    lc = 0
                    Continue
                EndIf
                
                Select s
                
                    Case E_NAME
                        If (c = 0 Or c = 10 Or c = 32 Or c = 9) And escape = 0 Then
                            Continue
                        ElseIf c = 123 And escape = 0 Then
                            node = node.AddChild( node.Children.Count( ) )
                            cfield=1
                        ElseIf c = 125 And escape = 0 Then
                            If node = Null Or node = Self Then
                                memset_( buf, 0, buf.Length )
                                memset_( shrts, 0, shrts.Length*2 )
                                Throw "["+line+";"+col+";"+s+"]  Unexpected character '"+Chr(c)+"', cannot close a node when there is none open"
                            EndIf
                            node = node.Parent
                            cfield=1
                        Else
                            shrts[0] = c
                            si = 1
                            s = R_NAME
                            cfield = 1
                        EndIf
                    
                    Case R_NAME
                        If (c = 32 Or c = 9) And escape = 0 Then
                            s = E_OPEN
                        ElseIf c = 123 And escape = 0 Then
                            s = E_NAME
                            node = node.AddChild( String.FromShorts( shrts, si ) )
                            si = 0
                        ElseIf c = 10 And escape = 0 Then
                            cfield = 0
                            s = E_OPEN
                        ElseIf c = 33 And escape = 0 Then
                            node.AddAttr( String.FromShorts( shrts, si ) )
                            si = 0
                            s = E_NAME
                            cfield = 1
                        ElseIf c = 125 And escape = 0 Then
                            memset_( buf, 0, buf.Length )
                            memset_( shrts, 0, shrts.Length*2 )
                            Throw "["+line+";"+col+";"+s+"]  Unexpected character '"+Chr(c)+"', expected name, :Float, or { -- perhaps you forgot to escape a character?"
                        Else
                            If shrts.Length = si Then shrts = shrts[..shrts.Length*2]
                            shrts[si] = c
                            si :+ 1
                        EndIf
                    
                    Case E_OPEN
                        If c = 123 And escape = 0 Then
                            node = node.AddChild( String.FromShorts( shrts, si ) )
                            si = 0
                            s = E_NAME
                        ElseIf c = 32 Or c = 9 Then
                            Continue
                        ElseIf cfield
                            nf = node.AddAttr( String.FromShorts( shrts, si ) )
                            si = 1
                            shrts[0] = c
                            s = RF_VALUE
                        Else
                            memset_( buf, 0, buf.Length )
                            memset_( shrts, 0, shrts.Length*2 )
                            Throw "["+line+";"+col+";"+s+"]  Unexpected character '"+Chr(c)+"', expected { or attribute value -- perhaps you forgot to escape a character?"
                        EndIf
                    
                    Case RF_VALUE
                        If c = 123 And escape = 0 Then
                            nf.Content = String.FromShorts( shrts, si )
                            si = 0
                            node = node.AddChild( node.Children.Count( ) )
                            s = E_NAME
                            cfield=1
                        ElseIf c = 125 And escape = 0 Then
                            nf.Content = String.FromShorts( shrts, si )
                            si = 0
                            s = E_NAME
                            If node = Null Or node = Self Then
                                memset_( buf, 0, buf.Length )
                                memset_( shrts, 0, shrts.Length*2 )
                                Throw "["+line+";"+col+";"+s+"]  Unexpected character '"+Chr(c)+"', cannot close a node when there is none open"
                            EndIf
                            node = node.Parent
                            cfield=1
                        ElseIf c = 59 And escape = 0 Then
                            nf.Content = String.FromShorts( shrts, si )
                            si = 0
                            s = E_NAME
                            cfield = 1
                        ElseIf c = 10 And escape = 0 Then
                            nf.Content = String.FromShorts( shrts, si )
                            si = 0
                            cfield = 1
                            s = E_NAME
                        Else
                            If escape = 1 Then
                                Select c
                                    Case 78
                                        c = 10
                                    Case 110
                                        c = 10
                                    Case 48
                                        c = 0
                                    Default
                                End Select
                            EndIf
                            If shrts.Length = si Then shrts = shrts[..shrts.Length*2]
                            shrts[si] = c
                            si :+ 1
                        EndIf
                    
                End Select
                
                escape = 0
            Next
        Wend
        
        If node <> Self Then
            memset_( buf, 0, buf.Length )
            memset_( shrts, 0, shrts.Length*2 )
            Throw "["+line+";"+col+";"+s+"]  Unexpected EOF"
        EndIf
        If s <> E_NAME Then
            Select s
                Case E_OPEN
                    memset_( buf, 0, buf.Length )
                    memset_( shrts, 0, shrts.Length*2 )
                    Throw "["+line+";"+col+";"+s+"]  Unexpected EOF"
                Case RF_VALUE
                    nf.Content = String.FromShorts( shrts, si )
                Case E_NAME
                Case R_COMMENT
            End Select
        EndIf
        
        memset_( buf, 0, buf.Length )
        memset_( shrts, 0, shrts.Length*2 )
    End Method
   
   Rem
   bbdoc: Writes the node, its children, and its Attrs to a stream in the order of <i>[name] { [Attrs] [children] }</i>
   EndRem
    Method Write( out:TStream, indent$="" )
        Local attrIndent$ = indent
        If Parent Then ' Nodes without parents are assumed to be documents
            out.WriteLine( indent+Name.Replace("\","\\").Replace(" ","\ ").Replace("#","\#").Replace("{","\{").Replace("}","\}").Replace(":Float","\:Float").Replace("~t","\~t").Replace("~n","\n")+" {" )
            attrIndent :+ "    "
        EndIf

        For Local i:IPAttr = EachIn Attrs
            If i.Content.Length = 0 Then
                out.WriteLine( attrIndent+i.Name.Replace("\","\\").Replace(" ","\ ").Replace("#","\#").Replace("{","\{").Replace("}","\}").Replace(":Float","\:Float").Replace("~t","\~t").Replace("~n","\n")+":Float" )
            Else
                Local outp$ = attrIndent+i.Name.Replace("\","\\").Replace(" ","\ ").Replace("#","\#").Replace("{","\{").Replace("}","\}").Replace(":Float","\:Float").Replace("~t","\~t").Replace("~n","\n")
                outp :+ " "+i.Content.Replace("\","\\").Replace(" ","\ ").Replace("#","\#").Replace("{","\{").Replace("}","\}").Replace("~n","\~n")
                out.WriteLine( outp )
            EndIf
        Next
        For Local i:IPNode = EachIn Children
            i.Write( out, indent+"    " )
        Next
        
        If Parent Then
            out.WriteLine( indent+"}" )
        EndIf
    End Method
    
    Rem
    bbdoc: Prepares the node, its children, and its Attrs for collection by removing itself from its parent and disposing of its children and Attrs.
    EndRem
    Method Dispose( )
        Name = Null
        Parent = Null
        If link Then link.Remove( )
        link = Null
        If Attrs Then
            For Local i:IPAttr = EachIn Attrs
                i.Dispose( )
            Next
            Attrs.Clear( )
        EndIf
        Attrs = Null
        If Children Then
            For Local i:IPNode = EachIn Children
                i.Dispose( )
            Next
            Children.Clear( )
        EndIf
        Children = Null
    End Method

    Rem
    bbdoc: Adds a child to the node with the name @fname and returns it.
    returns: The new @IPNode.
    EndRem
    Method AddChild:IPNode( fname$ )
        Local i:IPNode = New IPNode
        i.Name = fname
        i.link = Children.AddLast( i )
        i.Parent = Self
        Return i
    End Method

    Rem
    bbdoc: Adds an attribute to the node with the name @fname and an optional @value and returns it.
    returns: The new @IPAttr.
    EndRem
    Method AddAttr:IPAttr( fname$, value$="" )
        Local i:IPAttr = New IPAttr
        i.Name = fname
        i.Content = value
        i.link = Attrs.AddLast( i )
        i.Parent = Self
        Return i
    End Method
    
    Rem
    bbdoc: Gets an attribute and, if you pass a value to @fDefaultValue, will create the new attribute if one does not already exist.<br/>
    This method makes the assumption that all attribute names in the node are unique.
    returns: A string containing the contents of the attribute.
    EndRem
    Method GetAttr$( fname$, fDefaultValue$=Null )
        Local f:IPAttr = FindAttr( fname )
        If Not f And fDefaultValue <> Null Then
            AddAttr( fname, fDefaultValue )
            Return fDefaultValue
        ElseIf f
            Return f.content
        EndIf
        Return Null
    End Method
    
    Rem
    bbdoc: Sets an attribute with the name @fname to @value.  If the attribute doesn't exist, it is created.
    EndRem
    Method SetAttr( fname$, fvalue$ )
        Local f:IPAttr = FindAttr( fname )
        If Not f Then
            AddAttr( fname, fvalue )
        Else
            f.Content = fvalue
        EndIf
    End Method
    
    Rem
    bbdoc: Finds a child node with the name @fname.  If children with the same name exist, you can iterate over them by passing the last-found child to @last.
    returns: The requested IPNode if successful, otherwise Null.
    EndRem
    Method FindNode:IPNode( fname$, last:IPNode = Null )
        If last = Null Then
            last = IPNode( Children.GetFirst( ) )
        Else
            If Not last.link.NextLink( ) Then
                Return Null
            EndIf
            last = IPNode( last.link.NextLink( ).Value( ) )
        EndIf

        While ( last <> Null )
            If last.name = fname Return last
            If Not last.link.NextLink( ) Then
                Return Null
            EndIf
            last = IPNode( last.link.NextLink( ).Value( ) )
        Wend

        Return Null
    End Method

    Rem
    bbdoc: Finds an attribute with the name @fname.  If attributes with the same name exist, you can iterate over them by passing the last-found attribute to @last.<br/>
    This function will return the IPAttr, not a string like GetAttr.
    returns: The requested IPNode if successful, otherwise Null.
    EndRem
    Method FindAttr:IPAttr( fname$, last:IPAttr = Null )
        If last = Null Then
            last = IPAttr( Attrs.GetFirst( ) )
        Else
            If Not last.link.NextLink( ) Then
                Return Null
            EndIf
            last = IPAttr( last.link.NextLink( ).Value( ) )
        EndIf

        While ( last <> Null )
            If last.name = fname Return last
            If Not last.link.NextLink( ) Then
                Return Null
            EndIf
            last = IPAttr( last.link.NextLink( ).Value( ) )
        Wend

        Return Null
    End Method
End Type

Rem
bbdoc: Attribute class for an IPNode.
EndRem
Type IPAttr
    Rem
    bbdoc: Name of the attribute.
    EndRem
    Field Name$
    Rem
    bbdoc: Content/value of the attribute.
    EndRem
    Field Content$
    Rem
    bbdoc: The parent/owner (node) of the attribute.
    EndRem
    Field Parent:IPNode
    Field _numArr:Float[]=Null
    Field _idArr$[]=Null
    Field link:ILink
    
    Field _line%=0
    Field _colm%=0
    
    Rem
    bbdoc: Gets the line number the attribute was found on.
    EndRem
    Method GetLine%( )
        Return _line
    End Method
    
    Rem
    bbdoc: Gets the column number the attribute was found on.
    EndRem
    Method GetColumn%( )
        Return _colm
    End Method
    
    Method LineCol$( )
        Return "["+_line+":"+_colm+"]"
    End Method
    
    Rem
    bbdoc: Prepares the attribute for collection by removing itself from its parent.
    EndRem    
    Method Dispose( )
        If link Then link.Remove( )
        link = Null
        _numArr = Null
        _idArr = Null
        Parent = Null
        Content = Null
        Name = Null
    End Method

    Rem
    bbdoc: Returns an array of numbers based on the contents of the attribute.<br/>
    E.g., &quot;position 24 25 26&quot; would return an array with the contents 24, 25, and 26.
    returns: An array of doubles containing the number values of the attribute.
    EndRem
    Method ToNumberArray:Float[]( force%=0 )
        If Not Content Then Return Null
        If _numArr And Not force Then Return _numArr
        _numArr = New Float[ToIDArr( force ).Length]
        For Local i:Int = 0 To _idArr.Length-1
            _numArr[i] = _idArr[i].ToDouble( )
        Next
        Return _numArr
    End Method
    
    Rem
    bbdoc: Returns an array of IDs based on the contents of the attribute.<br/>
    E.g., &quot;flags fullbright nofog foo bar&quot; would return an array with the contents 'fullbright', 'nofog', 'foo', and 'bar'.
    returns: An array of strings containing the IDs of the attribute.
    EndRem
    Method ToIDArr$[]( force%=0 )
        If Not Content Then Return Null
        If _idArr And Not force Then Return _idArr
        _idArr = content.Split(",")
        For Local i:Int = 0 To _idArr.Length-1
            _idArr[i] = _idArr[i].Trim( )
        Next
        Return _idArr
    End Method

    Rem
    bbdoc: Returns a number based on the contents of the attribute.<br/>
    This is just another way of saying @myAttr.Content.ToDouble( ).
    returns: A double calculated from the contents of the attribute.
    EndRem
    Method ToNumber:Float( )
        If Not Content Then Return Null
        Return Content.ToDouble( )
    End Method
End Type