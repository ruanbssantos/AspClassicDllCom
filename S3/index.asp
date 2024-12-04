<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Upload Múltiplo de Arquivos</title>
    <!-- Inclua a biblioteca jQuery -->
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
</head>
<body>

    
    <h2>Selecione os arquivos para upload:</h2>
    <form method="POST" enctype="multipart/form-data" id="fileUploadForm">
        <input type="file" id="cadUsuarioUploadCampo" name="cadUsuarioUploadCampo" accept="*" multiple>
    </form>
 
    <button id="uploadBtn">Enviar Arquivos</button>

    <div id="resultado"></div>
    
    <script>
    $(document).ready(function(){
        $('#uploadBtn').click(function(e){
            e.preventDefault();

            // Obtenha os arquivos selecionados
            var form = $('#cadUsuarioUploadCampo').closest('form')[0]; // Corrige a seleção do formulário
            var formData = new FormData(form); // Cria o FormData a partir do formulário
            formData.append("caminho", "USUARIO"); // Adiciona campo extra

            $.ajax({
                url: 'Upload.asp', // Página ASP que processará o upload
                type: 'POST',
                data: formData,
                cache: false,
                contentType: false,
                processData: false,
                beforeSend: function () {
                    $('#resultado').html('<p>Enviando arquivo, aguarde...</p>');
                }
            })
            .done(function (response) {
                console.log('Resposta do servidor:', response);
                $('#resultado').html('<p>Arquivo enviado com sucesso!</p>');
            })
            .fail(function (jqXHR, textStatus, errorThrown) {
                console.error('Erro no envio:', textStatus, errorThrown);
                $('#resultado').html('<p>Erro ao enviar o arquivo. Tente novamente.</p>');
            });
        });
    });
</script>

</body>
</html>
