using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Web;
using System.Web.Security;

namespace SqlWatchImport
{
	internal class Tools
	{

		public static void RotateLogFile(string logFile)
		{
			//rotate log file: 

			try
            {
				if (File.Exists(logFile))
				{
					long length = new System.IO.FileInfo(logFile).Length;

					if (length / 1024.0 / 1024.0 > Config.maxLogSizeMB)
					{
						System.IO.File.Move(logFile, logFile + "_" + string.Format("{0:yyyy-MM-dd_HH-mm-ss-fff}", DateTime.Now) + ".log");

						var dir = new DirectoryInfo(Assembly.GetExecutingAssembly().Location);
						var query = dir.GetFiles("*.log", SearchOption.AllDirectories);

						foreach (var file in query.OrderByDescending(file => file.CreationTime).Skip(Config.MaxLogFiles))
						{
							file.Delete();
						}
					}
				}
			}
			catch (Exception e)
            {
				Logger.LogWarning("I was not able to rotate log files");
            }
		}

		private static readonly UTF8Encoding Encoder = new UTF8Encoding();

		public static string Encrypt(string unencrypted)
		{
			if (string.IsNullOrEmpty(unencrypted))
				return string.Empty;
			try
			{
				var encryptedBytes = MachineKey.Protect(Encoder.GetBytes(unencrypted));
				if (encryptedBytes != null && encryptedBytes.Length > 0)
					return HttpServerUtility.UrlTokenEncode(encryptedBytes);
			}
			catch (Exception)
			{
				return string.Empty;
			}
			return string.Empty;
		}

		public static string Decrypt(string encrypted)
		{
			if (string.IsNullOrEmpty(encrypted))
				return string.Empty;

			try
			{
				var bytes = HttpServerUtility.UrlTokenDecode(encrypted);
				if (bytes != null && bytes.Length > 0)
				{
					var decryptedBytes = MachineKey.Unprotect(bytes);
					if (decryptedBytes != null && decryptedBytes.Length > 0)
						return Encoder.GetString(decryptedBytes);
				}
			}
			catch (Exception e)
			{
				Logger.LogError("Failed to decrypt password. Perhaps the secret needs updating?");
				Logger.LogError(e.ToString());
				return string.Empty;
			}

			return string.Empty;
		}
	}
}
