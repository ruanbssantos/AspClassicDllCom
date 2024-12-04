<%
'constants:
Const MAX_UPLOAD_SIZE=1500000000 'bytes
Const MSG_NO_DATA="nothing to upload!"
Const MSG_EXCEEDED_MAX_SIZE="you exceeded the maximum upload size!"
Const SU_DEBUG_MODE=False

Class ShadowUpload
	Private m_Request
	Private m_Files
	Private m_Error
	
	Public Property Get GetError
		GetError = m_Error
	End Property
	
	Public Property Get FileCount
		FileCount = m_Files.Count
	End Property
	
	Public Function File(index)
		Dim keys
		keys = m_Files.Keys
		Set File = m_Files(keys(index))
	End Function
	
	Public Default Property Get Item(strName)
		If m_Request.Exists(strName) Then
			Item = m_Request(strName)
		Else  
			Item = ""
		End If
	End Property
	
	Private Sub Class_Initialize
		Dim iBytesCount, strBinData

		'first of all, get amount of uploaded bytes:
		iBytesCount = Request.TotalBytes
     		
		WriteDebug("initializing upload, bytes: " & iBytesCount & "<br />")
		
		'abort if nothing there:
		If iBytesCount=0 Then
			m_Error = MSG_NO_DATA
			Exit Sub
		End If
		
		'abort if exceeded maximum upload size:
		If iBytesCount>MAX_UPLOAD_SIZE Then
			m_Error = MSG_EXCEEDED_MAX_SIZE
			Exit Sub
		End If
		
		'read the binary data:
		strBinData = Request.BinaryRead(iBytesCount)
		
		'create private collections:
		Set m_Request = Server.CreateObject("Scripting.Dictionary")
		Set m_Files = Server.CreateObject("Scripting.Dictionary")
     		
		'populate the collection:
		Call BuildUpload(strBinData)
	End Sub
	
	Private Sub Class_Terminate
		Dim fileName
		If IsObject(m_Request) Then
			m_Request.RemoveAll
			Set m_Request = Nothing
		End If
		If IsObject(m_Files) Then
			For Each fileName In m_Files.Keys
				Set m_Files(fileName)=Nothing
			Next
			m_Files.RemoveAll
			Set m_Files = Nothing
		End If
	End Sub
	
	Private Sub BuildUpload(ByVal strBinData)
		Dim strBinQuote, strBinCRLF, iValuePos
		Dim iPosBegin, iPosEnd, strBoundaryData
		Dim strBoundaryEnd, iCurPosition, iBoundaryEndPos
		Dim strElementName, strFileName, objFileData
		Dim strFileType, strFileData, strElementValue
		
		strBinQuote = AsciiToBinary(chr(34))
		strBinCRLF = AsciiToBinary(chr(13))
		
		'find the boundaries
		iPosBegin = 1
		iPosEnd = InstrB(iPosBegin, strBinData, strBinCRLF)
		strBoundaryData = MidB(strBinData, iPosBegin, iPosEnd-iPosBegin)
		iCurPosition = InstrB(1, strBinData, strBoundaryData)
		strBoundaryEnd = strBoundaryData & AsciiToBinary("--")
		iBoundaryEndPos = InstrB(strBinData, strBoundaryEnd)
		
		'read binary data into private collection:
		Do until (iCurPosition>=iBoundaryEndPos) Or (iCurPosition=0)
			'skip non relevant data...
			iPosBegin = InstrB(iCurPosition, strBinData, AsciiToBinary("Content-Disposition"))
			iPosBegin = InstrB(iPosBegin, strBinData, AsciiToBinary("name="))
			iValuePos = iPosBegin
			
			'read the name of the form element, e.g. "file1", "text1"
			iPosBegin = iPosBegin+6
			iPosEnd = InstrB(iPosBegin, strBinData, strBinQuote)
			strElementName = BinaryToAscii(MidB(strBinData, iPosBegin, iPosEnd-iPosBegin))
			
			'maybe file?
			iPosBegin = InstrB(iCurPosition, strBinData, AsciiToBinary("filename="))
			iPosEnd = InstrB(iPosEnd, strBinData, strBoundaryData)
			If (iPosBegin>0) And (iPosBegin<iPosEnd) Then
				'skip non relevant data..
				iPosBegin = iPosBegin+10
				
				'read file name:
				iPosEnd = InstrB(iPosBegin, strBinData, strBinQuote)
				
				strFileName = BinaryToAscii(MidB(strBinData, iPosBegin, iPosEnd-iPosBegin))
				strFileNameOriginal = BinaryToAscii(MidB(strBinData, iPosBegin, iPosEnd-iPosBegin))

				'verify that we got name:
				If Len(strFileName)>0 Then
					'create file data:
					Set objFileData = New FileData
					objFileData.FileName = strFileNameOriginal
					objFileData.CleanFileName = NormalizarNomeArquivo(strFileName)
					
					'read file type:
					iPosBegin = InstrB(iPosEnd, strBinData, AsciiToBinary("Content-Type:"))
					iPosBegin = iPosBegin+14
					iPosEnd = InstrB(iPosBegin, strBinData, strBinCRLF)
					strFileType = BinaryToAscii(MidB(strBinData, iPosBegin, iPosEnd-iPosBegin))
					objFileData.ContentType = strFileType
					
					'read file contents:
					iPosBegin = iPosEnd+4
					iPosEnd = InstrB(iPosBegin, strBinData, strBoundaryData)-2
					strFileData = MidB(strBinData, iPosBegin, iPosEnd-iPosBegin)
					
					'check that not empty:
					If LenB(strFileData)>0 Then
						objFileData.Contents = strFileData
						
						'append to files collection if not empty:
						Set m_Files(strFileName) = objFileData
					Else  
						Set objFileData = Nothing
					End If
				End If
				strElementValue = strFileName
			Else  
				'ordinary form value, just read:
				iPosBegin = InstrB(iValuePos, strBinData, strBinCRLF)
				iPosBegin = iPosBegin+4
				iPosEnd = InstrB(iPosBegin, strBinData, strBoundaryData)-2
				strElementValue = BinaryToAscii(MidB(strBinData, iPosBegin, iPosEnd-iPosBegin))
			End If
			
			'append to request collection
			m_Request(strElementName) = strElementValue
			
			'skip to next element:
			iCurPosition = InstrB(iCurPosition+LenB(strBoundaryData), strBinData, strBoundaryData)
		Loop
	End Sub
	
	Private Function WriteDebug(msg)
		If SU_DEBUG_MODE Then
			Response.Write(msg)
			Response.Flush
		End If
	End Function
	
	Private Function AsciiToBinary(strAscii)
		Dim i, char, result
		result = ""
		For i=1 to Len(strAscii)
			char = Mid(strAscii, i, 1)
			result = result & chrB(AscB(char))
		Next
		AsciiToBinary = result
	End Function
	
	Private Function BinaryToAscii(strBinary)
		Dim i, result
		result = ""
		For i=1 to LenB(strBinary)
			result = result & chr(AscB(MidB(strBinary, i, 1))) 
		Next
		BinaryToAscii = result
	End Function
End Class

Class FileData
	Private m_fileName
	Private m_cleanFileName
	Private m_contentType
	Private m_BinaryContents
	Private m_AsciiContents
	Private m_imageWidth
	Private m_imageHeight
	Private m_checkImage
	
	Public Property Get FileName
		FileName = m_fileName
	End Property

	Public Property Get CleanFileName
		CleanFileName = m_cleanFileName
	End Property
	
	Public Property Get ContentType
		ContentType = m_contentType
	End Property
	
	Public Property Get ImageWidth
		If m_checkImage=False Then Call CheckImageDimensions
		ImageWidth = m_imageWidth
	End Property
	
	Public Property Get ImageHeight
		If m_checkImage=False Then Call CheckImageDimensions
		ImageHeight = m_imageHeight
	End Property
	
	Public Property Let FileName(strName)
		Dim arrTemp
		arrTemp = Split(strName, "\")
		m_fileName = arrTemp(UBound(arrTemp))
	End Property

	Public Property Let CleanFileName(strName)
		m_cleanFileName = strName
	End Property
		
	Public Property Let CheckImage(blnCheck)
		m_checkImage = blnCheck
	End Property
	
	Public Property Let ContentType(strType)
		m_contentType = strType
	End Property
	
	Public Property Let Contents(strData)
		m_BinaryContents = strData
		m_AsciiContents = RSBinaryToString(m_BinaryContents)
	End Property
	
	Public Property Get AsciiContents
		AsciiContents = m_AsciiContents
	End Property
	
	Public Property Get Size
		Size = LenB(m_BinaryContents)
	End Property
	
	Private Sub CheckImageDimensions
		Dim width, height, colors
		Dim strType
		
		'''If gfxSpex(BinaryToAscii(m_BinaryContents), width, height, colors, strType) = true then
		If gfxSpex(m_AsciiContents, width, height, colors, strType) = true then
			m_imageWidth = width
			m_imageHeight = height
		End If
		m_checkImage = True
	End Sub
	
	Private Sub Class_Initialize
		m_imageWidth = -1
		m_imageHeight = -1
		m_checkImage = False
	End Sub
	
	Public Sub SaveToDisk(strFolderPath, ByRef strNewFileName)
		Dim strPath, objFSO, objFile
		Dim i, time1, time2
		Dim objStream, strExtension
		
		strPath = replace(strFolderPath,"/","\") &"\"

		If Len(strNewFileName)=0 Then
			vstr_nomeArquivo = replace(m_cleanFileName,"."&GetExtension(m_cleanFileName),"")			
			vstr_nomeArquivo = vstr_nomeArquivo & "-" & fcn_geraIdentificador() & "." & GetExtension(m_cleanFileName)
		Else  
			strExtension = GetExtension(strNewFileName)
			If Len(strExtension)=0 Then
				vstr_nomeArquivo =  strNewFileName & "-" & fcn_geraIdentificador() & "." & GetExtension(m_cleanFileName)
			End if
		End If

		arquivo("FinalName") = ""

		if len(vstr_nomeArquivo) > 0 then 
			arquivo("FinalName") = vstr_nomeArquivo		
			strPath = strPath & vstr_nomeArquivo
		end if
		
		WriteDebug("save file started...<br />")
		
		time1 = CDbl(Timer)
		
		Set objFSO = Server.CreateObject("Scripting.FileSystemObject")
		Set objFile = objFSO.CreateTextFile(strPath)
		
		objFile.Write(m_AsciiContents)
		
		'''For i=1 to LenB(m_BinaryContents)
		'''	objFile.Write chr(AscB(MidB(m_BinaryContents, i, 1)))
		'''Next          
		
		time2 = CDbl(Timer)
		WriteDebug("saving file took " & (time2-time1) & " seconds.<br />")
		
		objFile.Close
		Set objFile=Nothing
		Set objFSO=Nothing
	End Sub
	
	Private Function GetExtension(strPath)
		Dim arrTemp
		arrTemp = Split(strPath, ".")
		GetExtension = ""
		If UBound(arrTemp)>0 Then
			GetExtension = arrTemp(UBound(arrTemp))
		End If
	End Function
	
	Private Function RSBinaryToString(xBinary)
		'Antonin Foller, http://www.motobit.com
		'RSBinaryToString converts binary data (VT_UI1 | VT_ARRAY Or MultiByte string)
		'to a string (BSTR) using ADO recordset
		
		Dim Binary
		'MultiByte data must be converted To VT_UI1 | VT_ARRAY first.
		If vartype(xBinary)=8 Then Binary = MultiByteToBinary(xBinary) Else Binary = xBinary
		
		Dim RS, LBinary
		Const adLongVarChar = 201
		Set RS = CreateObject("ADODB.Recordset")
		LBinary = LenB(Binary)
		
		If LBinary>0 Then
			RS.Fields.Append "mBinary", adLongVarChar, LBinary
			RS.Open
			RS.AddNew
			RS("mBinary").AppendChunk Binary 
			RS.Update
			RSBinaryToString = RS("mBinary")
		Else  
			RSBinaryToString = ""
		End If
	End Function
	
	Function MultiByteToBinary(MultiByte)
		'© 2000 Antonin Foller, http://www.motobit.com
		' MultiByteToBinary converts multibyte string To real binary data (VT_UI1 | VT_ARRAY)
		' Using recordset
		Dim RS, LMultiByte, Binary
		Const adLongVarBinary = 205
		Set RS = CreateObject("ADODB.Recordset")
		LMultiByte = LenB(MultiByte)
		If LMultiByte>0 Then
			RS.Fields.Append "mBinary", adLongVarBinary, LMultiByte
			RS.Open
			RS.AddNew
			RS("mBinary").AppendChunk MultiByte & ChrB(0)
			RS.Update
			Binary = RS("mBinary").GetChunk(LMultiByte)
		End If
		MultiByteToBinary = Binary
	End Function
	
	Private Function WriteDebug(msg)
		If SU_DEBUG_MODE Then
			Response.Write(msg)
			Response.Flush
		End If
	End Function
	
	Private Function BinaryToAscii(strBinary)
		Dim i, result
		result = ""
		For i=1 to LenB(strBinary)
			result = result & chr(AscB(MidB(strBinary, i, 1))) 
		Next
		BinaryToAscii = result
	End Function
	
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::                                                             :::
	':::  This routine will attempt to identify any filespec passed  :::
	':::  as a graphic file (regardless of the extension). This will :::
	':::  work with BMP, GIF, JPG and PNG files.                     :::
	':::                                                             :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::          Based on ideas presented by David Crowell          :::
	':::                   (credit where due)                        :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	'::: blah blah blah blah blah blah blah blah blah blah blah blah :::
	'::: blah blah blah blah blah blah blah blah blah blah blah blah :::
	'::: blah blah     Copyright *c* MM,  Mike Shaffer     blah blah :::
	'::: bh blah      ALL RIGHTS RESERVED WORLDWIDE      blah blah :::
	'::: blah blah  Permission is granted to use this code blah blah :::
	'::: blah blah   in your projects, as long as this     blah blah :::
	'::: blah blah      copyright notice is included       blah blah :::
	'::: blah blah blah blah blah blah blah blah blah blah blah blah :::
	'::: blah blah blah blah blah blah blah blah blah blah blah blah :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::                                                             :::
	':::  This function gets a specified number of bytes from any    :::
	':::  file, starting at the offset (base 1)                      :::
	':::                                                             :::
	':::  Passed:                                                    :::
	':::       flnm        => Filespec of file to read               :::
	':::       offset      => Offset at which to start reading       :::
	':::       bytes       => How many bytes to read                 :::
	':::                                                             :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	Private Function GetBytes(flnm, offset, bytes)
		Dim startPos
		If offset=0 Then
			startPos = 1
		Else  
			startPos = offset
		End If
		if bytes = -1 then		' Get All!
			GetBytes = flnm
		else
			GetBytes = Mid(flnm, startPos, bytes)
		end if
		'		Dim objFSO
		'		Dim objFTemp
		'		Dim objTextStream
		'		Dim lngSize
		'		
		'		Set objFSO = CreateObject("Scripting.FileSystemObject")
		'		
		'		' First, we get the filesize
		'		Set objFTemp = objFSO.GetFile(flnm)
		'		lngSize = objFTemp.Size
		'		set objFTemp = nothing
		'		
		'		fsoForReading = 1
		'		Set objTextStream = objFSO.OpenTextFile(flnm, fsoForReading)
		'		
		'		if offset > 0 then
		'			strBuff = objTextStream.Read(offset - 1)
		'		end if
		'		
		'		if bytes = -1 then		' Get All!
		'			GetBytes = objTextStream.Read(lngSize)  'ReadAll
		'		else
		'			GetBytes = objTextStream.Read(bytes)
		'		end if
		'		
		'		objTextStream.Close
		'		set objTextStream = nothing
		'		set objFSO = nothing
	End Function
	
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::                                                             :::
	':::  Functions to convert two bytes to a numeric value (long)   :::
	':::  (both little-endian and big-endian)                        :::
	':::                                                             :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	Private Function lngConvert(strTemp)
		lngConvert = clng(asc(left(strTemp, 1)) + ((asc(right(strTemp, 1)) * 256)))
	end function
	
	Private Function lngConvert2(strTemp)
		lngConvert2 = clng(asc(right(strTemp, 1)) + ((asc(left(strTemp, 1)) * 256)))
	end function
	
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	':::                                                             :::
	':::  This function does most of the real work. It will attempt  :::
	':::  to read any file, regardless of the extension, and will    :::
	':::  identify if it is a graphical image.                       :::
	':::                                                             :::
	':::  Passed:                                                    :::
	':::       flnm        => Filespec of file to read               :::
	':::       width       => width of image                         :::
	':::       height      => height of image                        :::
	':::       depth       => color depth (in number of colors)      :::
	':::       strImageType=> type of image (e.g. GIF, BMP, etc.)    :::
	':::                                                             :::
	':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	function gfxSpex(flnm, width, height, depth, strImageType)
		dim strPNG 
		dim strGIF
		dim strBMP
		dim strType
		dim strBuff
		dim lngSize
		dim flgFound
		dim strTarget
		dim lngPos
		dim ExitLoop
		dim lngMarkerSize
		
		strType = ""
		strImageType = "(unknown)"
		
		gfxSpex = False
		
		strPNG = chr(137) & chr(80) & chr(78)
		strGIF = "GIF"
		strBMP = chr(66) & chr(77)
		
		strType = GetBytes(flnm, 0, 3)
		
		if strType = strGIF then				' is GIF
			strImageType = "GIF"
			Width = lngConvert(GetBytes(flnm, 7, 2))
			Height = lngConvert(GetBytes(flnm, 9, 2))
			Depth = 2 ^ ((asc(GetBytes(flnm, 11, 1)) and 7) + 1)
			gfxSpex = True
		elseif left(strType, 2) = strBMP then		' is BMP
			strImageType = "BMP"
			Width = lngConvert(GetBytes(flnm, 19, 2))
			Height = lngConvert(GetBytes(flnm, 23, 2))
			Depth = 2 ^ (asc(GetBytes(flnm, 29, 1)))
			gfxSpex = True
		elseif strType = strPNG then			' Is PNG
			strImageType = "PNG"
			Width = lngConvert2(GetBytes(flnm, 19, 2))
			Height = lngConvert2(GetBytes(flnm, 23, 2))
			Depth = getBytes(flnm, 25, 2)
			select case asc(right(Depth,1))
				case 0
					Depth = 2 ^ (asc(left(Depth, 1)))
					gfxSpex = True
				case 2
					Depth = 2 ^ (asc(left(Depth, 1)) * 3)
					gfxSpex = True
				case 3
					Depth = 2 ^ (asc(left(Depth, 1)))  '8
					gfxSpex = True
				case 4
					Depth = 2 ^ (asc(left(Depth, 1)) * 2)
					gfxSpex = True
				case 6
					Depth = 2 ^ (asc(left(Depth, 1)) * 4)
					gfxSpex = True
				case else
					Depth = -1
			end select
		else
			strBuff = GetBytes(flnm, 0, -1)		' Get all bytes from file
			lngSize = len(strBuff)
			flgFound = 0
			
			strTarget = chr(255) & chr(216) & chr(255)
			flgFound = instr(strBuff, strTarget)
			
			if flgFound = 0 then
				exit function
			end if
			
			strImageType = "JPG"
			lngPos = flgFound + 2
			ExitLoop = false
			
			do while ExitLoop = False and lngPos < lngSize
				do while asc(mid(strBuff, lngPos, 1)) = 255 and lngPos < lngSize
					lngPos = lngPos + 1
				loop
				
				if asc(mid(strBuff, lngPos, 1)) < 192 or asc(mid(strBuff, lngPos, 1)) > 195 then
					lngMarkerSize = lngConvert2(mid(strBuff, lngPos + 1, 2))
					lngPos = lngPos + lngMarkerSize  + 1
				else
					ExitLoop = True
				end if
			loop
			
			if ExitLoop = False then
				Width = -1
				Height = -1
				Depth = -1
			else
				Height = lngConvert2(mid(strBuff, lngPos + 4, 2))
				Width = lngConvert2(mid(strBuff, lngPos + 6, 2))
				Depth = 2 ^ (asc(mid(strBuff, lngPos + 8, 1)) * 8)
				gfxSpex = True
			end if
		end if
	End Function
End Class

Function NormalizarNomeArquivo(input)
    Dim regex, cleanedName, i, char, result

	' Localizar a extensão do arquivo
    extensionIndex = InStrRev(input, ".")
    If extensionIndex > 0 Then
        extension = Mid(input, extensionIndex) ' Extensão do arquivo
        nomeArquivo = Left(input, extensionIndex - 1) ' Nome do arquivo sem extensão
    Else
        extension = ""
        nomeArquivo = input
    End If

    ' Etapa 1: Remover acentos e caracteres de marcação
    nomeArquivo = Replace(nomeArquivo, "á", "a")
    nomeArquivo = Replace(nomeArquivo, "à", "a")
    nomeArquivo = Replace(nomeArquivo, "ã", "a")
    nomeArquivo = Replace(nomeArquivo, "â", "a")
    nomeArquivo = Replace(nomeArquivo, "ä", "a")
    nomeArquivo = Replace(nomeArquivo, "é", "e")
    nomeArquivo = Replace(nomeArquivo, "è", "e")
    nomeArquivo = Replace(nomeArquivo, "ê", "e")
    nomeArquivo = Replace(nomeArquivo, "ë", "e")
    nomeArquivo = Replace(nomeArquivo, "í", "i")
    nomeArquivo = Replace(nomeArquivo, "ì", "i")
    nomeArquivo = Replace(nomeArquivo, "î", "i")
    nomeArquivo = Replace(nomeArquivo, "ï", "i")
    nomeArquivo = Replace(nomeArquivo, "ó", "o")
    nomeArquivo = Replace(nomeArquivo, "ò", "o")
    nomeArquivo = Replace(nomeArquivo, "õ", "o")
    nomeArquivo = Replace(nomeArquivo, "ô", "o")
    nomeArquivo = Replace(nomeArquivo, "ö", "o")
    nomeArquivo = Replace(nomeArquivo, "ú", "u")
    nomeArquivo = Replace(nomeArquivo, "ù", "u")
    nomeArquivo = Replace(nomeArquivo, "û", "u")
    nomeArquivo = Replace(nomeArquivo, "ü", "u")
    nomeArquivo = Replace(nomeArquivo, "ç", "c")
    nomeArquivo = Replace(nomeArquivo, "Á", "A")
    nomeArquivo = Replace(nomeArquivo, "À", "A")
    nomeArquivo = Replace(nomeArquivo, "Ã", "A")
    nomeArquivo = Replace(nomeArquivo, "Â", "A")
    nomeArquivo = Replace(nomeArquivo, "Ä", "A")
    nomeArquivo = Replace(nomeArquivo, "É", "E")
    nomeArquivo = Replace(nomeArquivo, "È", "E")
    nomeArquivo = Replace(nomeArquivo, "Ê", "E")
    nomeArquivo = Replace(nomeArquivo, "Ë", "E")
    nomeArquivo = Replace(nomeArquivo, "Í", "I")
    nomeArquivo = Replace(nomeArquivo, "Ì", "I")
    nomeArquivo = Replace(nomeArquivo, "Î", "I")
    nomeArquivo = Replace(nomeArquivo, "Ï", "I")
    nomeArquivo = Replace(nomeArquivo, "Ó", "O")
    nomeArquivo = Replace(nomeArquivo, "Ò", "O")
    nomeArquivo = Replace(nomeArquivo, "Õ", "O")
    nomeArquivo = Replace(nomeArquivo, "Ô", "O")
    nomeArquivo = Replace(nomeArquivo, "Ö", "O")
    nomeArquivo = Replace(nomeArquivo, "Ú", "U")
    nomeArquivo = Replace(nomeArquivo, "Ù", "U")
    nomeArquivo = Replace(nomeArquivo, "Û", "U")
    nomeArquivo = Replace(nomeArquivo, "Ü", "U")
    nomeArquivo = Replace(nomeArquivo, "Ç", "C")

    ' Etapa 2: Remover caracteres que não são letras ou números
    Set regex = New RegExp
    regex.Pattern = "[^A-Za-z0-9 ]" ' Tudo que não for letra, número ou espaço
    regex.Global = True
    cleanedName = regex.Replace(nomeArquivo, "")

    ' Etapa 3: Substituir "_" por "-"
    cleanedName = Replace(cleanedName, "_", "-")

    ' Etapa 4: Remover espaços extras
    cleanedName = Trim(cleanedName)

    ' Etapa 5: Substituir espaços restantes por "-"
    cleanedName = Replace(cleanedName, " ", "-")

    ' Retornar o nome normalizado
    NormalizarNomeArquivo = cleanedName & extension
End Function
%>