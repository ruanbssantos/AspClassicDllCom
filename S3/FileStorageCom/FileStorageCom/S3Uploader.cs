using Amazon.S3.Transfer;
using Amazon.S3;
using FileStorageCOM;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Amazon.S3.Model;
using System.IO;

namespace FileStorageCom
{
    [ComVisible(true)]
    [Guid("F0FEF99B-AAE6-45A4-809A-05B92F6AD679")]
    [ClassInterface(ClassInterfaceType.None)]
    public class S3Uploader : IS3Uploader
    {
        private string _accessKey;
        private string _secretKey;
        private string _bucketName;
        private Amazon.RegionEndpoint regionEndpoint;
        public bool Status { get; private set; } // Indica se a operação foi bem-sucedida
        public string ErrorMessage { get; private set; } // Mensagem de erro, se houver
                                                         // Propriedades para Access Key, Secret Key e Bucket Name
        public string AccessKey
        {
            get { return _accessKey; }
            set { _accessKey = value; }
        }

        public string SecretKey
        {
            get { return _secretKey; }
            set { _secretKey = value; }
        }

        public string BucketName
        {
            get { return _bucketName; }
            set { _bucketName = value; }
        }

        public S3Uploader()
        {
            this.regionEndpoint = Amazon.RegionEndpoint.USEast2; // Ohio nos EUA
        }
        private static byte[] ConvertBSTRToByteArray(string bstr)
        {
            if (string.IsNullOrEmpty(bstr))
                return new byte[0];

            return System.Text.Encoding.Default.GetBytes(bstr);
        }

        // Configurar a região dinamicamente
        public void SetRegionEndpoint(string regionSystemName)
        {
            this.regionEndpoint = Amazon.RegionEndpoint.GetBySystemName(regionSystemName);
        }

        public bool IsBucketAccessible()
        {
            try
            {
                // Validar credenciais
                if (string.IsNullOrEmpty(_accessKey) || string.IsNullOrEmpty(_secretKey) || string.IsNullOrEmpty(_bucketName))
                {
                    Status = false;
                    ErrorMessage = "Chave de acesso, chave secreta ou nome do bucket não foram fornecidos.";
                    return Status;
                }

                // Criar cliente S3
                using (var s3Client = new AmazonS3Client(_accessKey, _secretKey, this.regionEndpoint))
                {
                    // Tenta obter a localização do bucket para verificar se ele está acessível
                    var response = s3Client.GetBucketLocation(new GetBucketLocationRequest
                    {
                        BucketName = _bucketName
                    });

                    // Se a operação for bem-sucedida, o bucket é acessível
                    Status = true;
                    ErrorMessage = string.Empty;
                    return Status;
                }
            }
            catch (AmazonS3Exception ex)
            {
                // Tratamento de erros específicos do S3
                if (ex.StatusCode == System.Net.HttpStatusCode.Forbidden)
                {
                    ErrorMessage = "Permissões insuficientes para acessar o bucket.";
                }
                else if (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    ErrorMessage = $"O bucket '{_bucketName}' não foi encontrado.";
                }
                else
                {
                    ErrorMessage = $"Erro do S3: {ex.Message}";
                }

                Status = false;
                return Status;
            }
            catch (Exception ex)
            {
                // Tratamento de erros inesperados
                ErrorMessage = $"Erro inesperado: {ex.Message}";
                Status = false;
                return Status;
            }
        }

        public void UploadFileBinary(string keyName, string binaryString)
        {

            try
            {
                // Converter a string (BSTR) de volta para byte[]
                byte[] fileData = ConvertBSTRToByteArray(binaryString);

                // Certifique-se de que o nome da chave está em UTF-8
                var encodedKeyName = Encoding.UTF8.GetString(Encoding.Default.GetBytes(keyName));


                // Certifique-se de que o array não está vazio
                if (fileData == null || fileData.Length == 0)
                {
                    throw new ArgumentException("O arquivo está vazio ou inválido.");
                }

                // Criar o cliente do S3 e enviar o arquivo
                using (var s3Client = new AmazonS3Client(_accessKey, _secretKey, this.regionEndpoint))
                {
                    using (var stream = new MemoryStream(fileData))
                    {
                        var request = new PutObjectRequest
                        {
                            BucketName = _bucketName,
                            Key = encodedKeyName,
                            InputStream = stream,
                        };

                        s3Client.PutObject(request);
                    }
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Erro ao fazer upload  binary para o S3: {ex.Message}";
                throw new ArgumentException(ErrorMessage);
            }
            
        }

        public void UploadFile(string keyName, string filePath)
        {
            if (string.IsNullOrEmpty(keyName)) 
            {
                ErrorMessage = "O nome da chave não pode ser nulo ou vazio.";
                throw new ArgumentException(ErrorMessage);

            }


            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) 
            {
                ErrorMessage = "O caminho do arquivo é inválido ou o arquivo não existe.";
                throw new ArgumentException(ErrorMessage);
            } 

            try
            {
                // Criar o cliente S3 e TransferUtility com descarte adequado
                using (var s3Client = new AmazonS3Client(_accessKey, _secretKey, this.regionEndpoint))
                {
                    using (var fileTransferUtility = new TransferUtility(s3Client))
                    {
                        // Fazer upload do arquivo
                        fileTransferUtility.Upload(filePath, _bucketName, keyName);
                    }
                }
            }
            catch (AmazonS3Exception ex)
            {
                // Capturar exceções específicas do S3 
                ErrorMessage = $"Erro ao fazer upload para o S3. Mensagem AWS: {ex.Message}";
                throw new ArgumentException(ErrorMessage);
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Erro inesperado ao fazer upload para o S3: {ex.Message}";
                throw new ArgumentException(ErrorMessage); 
            }
        }

        public void DownloadFile(string keyName, string destinationFilePath)
        {
            if (string.IsNullOrEmpty(keyName))
            {
                ErrorMessage = "O nome da chave não pode ser nulo ou vazio.";
                throw new ArgumentException(ErrorMessage);

            }


            if (string.IsNullOrEmpty(destinationFilePath))
            {
                ErrorMessage = "O caminho de destino não pode ser nulo ou vazio.";
                throw new ArgumentException(ErrorMessage);
            } 

            try
            {
                // Criar o cliente S3 com descarte adequado
                using (var s3Client = new AmazonS3Client(_accessKey, _secretKey, this.regionEndpoint))
                {
                    // Criar o utilitário de transferência com descarte adequado
                    using (var fileTransferUtility = new TransferUtility(s3Client))
                    {
                        // Fazer o download do arquivo e salvar no caminho especificado
                        fileTransferUtility.Download(destinationFilePath, _bucketName, keyName);
                    }
                }
            }
            catch (AmazonS3Exception ex)
            {
                // Captura exceções específicas do S3 
                ErrorMessage = $"Erro ao baixar o arquivo do S3. Mensagem AWS: {ex.Message}";
                throw new ArgumentException(ErrorMessage);
            }
            catch (UnauthorizedAccessException ex)
            {
                // Captura problemas de acesso ao arquivo local 
                ErrorMessage = $"Erro ao salvar o arquivo em '{destinationFilePath}'. Verifique as permissões. Detalhes: {ex.Message}";
                throw new ArgumentException(ErrorMessage);
            }
            catch (Exception ex)
            {
                // Captura exceções gerais 
                ErrorMessage = $"Erro inesperado ao baixar o arquivo do S3: {ex.Message}";
                throw new ArgumentException(ErrorMessage);
            }
        }

        public string GetPreSignedUrl(string filePath, int minutesValid)
        {
            try
            {
                // Validar parâmetros
                if (string.IsNullOrEmpty(filePath))
                {
                    ErrorMessage = "O caminho do arquivo não pode ser nulo ou vazio.";
                    throw new ArgumentException(ErrorMessage);
                }

                if (minutesValid <= 0)
                {
                    ErrorMessage = "A validade deve ser maior que 0 minutos.";
                    throw new ArgumentException(ErrorMessage);
                }

                // Criar o cliente S3
                using (var s3Client = new AmazonS3Client(_accessKey, _secretKey, this.regionEndpoint))
                {
                    // Verificar se o arquivo existe no bucket
                    var metadataRequest = new GetObjectMetadataRequest
                    {
                        BucketName = _bucketName,
                        Key = filePath
                    };

                    try
                    {
                        // Tentar obter os metadados do objeto
                        s3Client.GetObjectMetadata(metadataRequest);

                        // Configurar a solicitação para a URL pré-assinada
                        var request = new GetPreSignedUrlRequest
                        {
                            BucketName = _bucketName,
                            Key = filePath,
                            Expires = DateTime.UtcNow.AddMinutes(minutesValid), // Validade da URL
                            Verb = HttpVerb.GET // Permissão de leitura
                        };

                        // Gerar a URL pré-assinada
                        string preSignedUrl = s3Client.GetPreSignedURL(request);

                        // Resetar a mensagem de erro em caso de sucesso
                        ErrorMessage = string.Empty;
                        return preSignedUrl;
                    }
                    catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
                    {
                        // Arquivo não encontrado
                        ErrorMessage = "O arquivo solicitado não existe no bucket.";
                        return null;
                    }
                }
            }
            catch (AmazonS3Exception ex)
            {
                // Tratar erros específicos do S3
                ErrorMessage = $"Erro AWS S3: {ex.Message}";
                throw new Exception(ErrorMessage);
            }
            catch (Exception ex)
            {
                // Tratar erros gerais
                ErrorMessage = $"Erro ao gerar URL pré-assinada: {ex.Message}";
                throw new Exception(ErrorMessage);
            }
        }


    }
}
