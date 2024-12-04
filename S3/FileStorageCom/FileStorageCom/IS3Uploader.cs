using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace FileStorageCOM
{
    [ComVisible(true)]
    [Guid("0B438912-657B-4678-9077-8F784A701358")]
    public interface IS3Uploader
    {
        string AccessKey { get; set; }
        string SecretKey { get; set; }
        string BucketName { get; set; }
        bool Status { get; }
        string ErrorMessage { get; }

        void SetRegionEndpoint(string regionSystemName);
        bool IsBucketAccessible();
        void UploadFile(string keyName, string filePath);
        void UploadFileBinary(string keyName, string binaryString);
        void DownloadFile(string keyName, string destinationFilePath);
        string GetPreSignedUrl(string filePath, int minutesValid);
    }
}
