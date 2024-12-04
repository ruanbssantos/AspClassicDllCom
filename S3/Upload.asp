<!--#include file="freeaspupload.asp"-->

<%
    
    accessKey = "accessKey"
    secretKey = "secretKey"
    bucketName = "bucketName"

    Set uploader = Server.CreateObject("FileStorageCOM.S3Uploader")

    uploader.AccessKey = accessKey
    uploader.SecretKey = secretKey  
    uploader.BucketName = bucketName 
  

    Dim objUpload
    Set objUpload = New ShadowUpload

    If objUpload.GetError <> "" Then
        response.write objUpload.GetError  
    else
        For x=0 To objUpload.FileCount-1

            '==============================================================================================================================
            ' UPLOAD BINARY STRING
            '==============================================================================================================================
            
            set uploadFile = objUpload.File(x) 
            binaryString = uploadFile.AsciiContents

            s3Key = "uploads/" & uploadFile.CleanFileName

            response.write  "<br />" &  uploadFile.FileName''Nome Original
            response.write  "<br />" &  uploadFile.CleanFileName'Nome Original

            uploader.UploadFileBinary s3Key, binaryString 


            '==============================================================================================================================
            ' UPLOAD FILE PATH
            '==============================================================================================================================
            ' filePath = Server.MapPath("uploads/Arquivo 1.pdf") 
            ' On Error Resume Next
            ' uploader.UploadFile keyName, filePath

            ' If Err.Number <> DownloadFile Then
            '     Response.Write("Erro ao fazer upload: " & Err.Description)
            ' Else
            '     Response.Write("Upload realizado com sucesso!")
            ' End If
        Next
    End If

    Set objUpload = nothing 
%>
