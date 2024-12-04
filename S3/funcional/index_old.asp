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
    <form id="uploadForm">
        <input type="file" id="fileInput" name="file" multiple> 
    </form>
    <div id="uploadStatus"></div>
 
    <button id="uploadButton">Enviar Arquivos</button>

    <div id="resultado"></div>
    
    <script>
        $(document).ready(function () {
            $('#uploadButton').on('click', function () {
                // Obter os arquivos selecionados
                var files = $('#fileInput')[0].files;

                if (files.length === 0) {
                    $('#uploadStatus').text('Por favor, selecione um arquivo.');
                    return;
                }

                // Criar um objeto FormData para enviar os arquivos
                var formData = new FormData();

                // Adicionar os arquivos ao FormData
                for (var i = 0; i < files.length; i++) {
                    formData.append('file' + i, files[i]);
                }

                // Enviar os arquivos via AJAX
                $.ajax({
                    url: 'upload.asp', // Endereço do script ASP Classic
                    type: 'POST',
                    data: formData,
                    contentType: false, // Não definir contentType, o FormData cuida disso
                    processData: false, // Não processar os dados
                    success: function (response) {
                        $('#uploadStatus').html('<p>Upload concluído!</p><pre>' + response + '</pre>');
                    },
                    error: function (xhr, status, error) {
                        $('#uploadStatus').html('<p>Erro no upload: ' + error + '</p>');
                    }
                });
            });
        });
    </script>

</body>
</html>
