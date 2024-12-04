<%
    Set uploader = Server.CreateObject("FileStorageCOM.S3Uploader")
 
    accessKey = "accessKey"
    secretKey = "secretKey"
    bucketName = "bucketName"
    keyName = "Uploads/Arquivo 1.pdf"

    filePath = Server.MapPath("uploads/Arquivo 1.pdf")
    destinationFilePath = Server.MapPath("downloads/arquivoBaixado.txt")


    ' On Error Resume Next
    ' uploader.UploadFile accessKey, secretKey, bucketName, keyName, filePath
    ' 'uploader.DownloadFile accessKey, secretKey, bucketName, keyName, destinationFilePath

    ' If Err.Number <> DownloadFile0 Then
    '     Response.Write("Erro ao fazer upload: " & Err.Description)
    ' Else
    '     Response.Write("Upload realizado com sucesso!")
    ' End If
  
    fileBytes = Request.BinaryRead(Request.TotalBytes)
 

    If LenB(fileBytes) > 0 Then
        'On Error Resume Next   
        uploader.UploadFileBinary accessKey, secretKey, bucketName, "Uploads/Sigas/", fileBytes
        
        If Err.Number <> 0 Then
            response.write "Erro ao fazer upload do arquivo " & nomeArqModificado & ": " & Err.Description & "|"
        else
            Response.Write "Upload concluído com sucesso!"
        end if
        Set uploader = Nothing
    Else
        Response.Write "Nenhum arquivo foi recebido."
    End If
%>
