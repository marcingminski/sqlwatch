using System.Configuration;
using System.Diagnostics;
using System.Reflection;

namespace SqlWatchImport
{
	internal class Config
	{
		//central repository config
		public static string centralRepoSqlInstance = ConfigurationManager.AppSettings["CentralRepositorySqlInstance"];
		public static string centralRepoSqlDatabase = ConfigurationManager.AppSettings["CentralRepositorySqlDatabase"];
		public static string centralRepoSqlUser = ConfigurationManager.AppSettings["CentralRepositorySqlUser"];
		public static string centralRepoSqlSecret = ConfigurationManager.AppSettings["CentralRepositorySqlSecret"];
		public static string EnvironmentToProcess = ConfigurationManager.AppSettings["EnvironmentToProcess"];

		public static int CentralRepositoryConnectTimeOut = 60;
		public static int RemoteInstanceConnectTimeOut = 60;

		public static string UserKey = ConfigurationManager.AppSettings["UserKey"];

		//application config
		public static bool fullLoad = bool.Parse(ConfigurationManager.AppSettings["FullLoad"]);

		public static int BulkCopyTimeout = int.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.BulkCopyTimeout"]);
		public static bool SqlBkEnableStreaming = bool.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.EnableStreaming"]);
		public static int SqlBkBatchSize = int.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.BatchSize"]);

		public static bool dumpOnError = bool.Parse(ConfigurationManager.AppSettings["DumpDataOnError"]);

		//public static string loggingLevel = ConfigurationManager.AppSettings["LoggingLevel"];
		public static int maxLogSizeMB = int.Parse(ConfigurationManager.AppSettings["MaxLogSizeMB"]);
		public static int MaxLogFiles = int.Parse(ConfigurationManager.AppSettings["MaxLogFiles"]);
		public static string LogFile = ConfigurationManager.AppSettings["LogFile"];
		public static bool PrintToConsole = bool.Parse(ConfigurationManager.AppSettings["PrintToConsole"]);
		public static bool PrintToLogFile = bool.Parse(ConfigurationManager.AppSettings["PrintToLogFile"]);


		public static string ApplicationTitle = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyTitleAttribute>().Title;
		public static string ApplicationDescription = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyDescriptionAttribute>().Description;
		public static string ApplicationCopyright = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyCopyrightAttribute>().Copyright;
		public static string ApplicationName = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyProductAttribute>().Product;

		//Aplication performance
		public static int MinThreads = int.Parse(ConfigurationManager.AppSettings["MinThreads"]);
		public static int MaxThreads = int.Parse(ConfigurationManager.AppSettings["MaxThreads"]);
		public static int MinPoolSize = int.Parse(ConfigurationManager.AppSettings["MinPoolSize"]);
		public static int MaxPoolSize = int.Parse(ConfigurationManager.AppSettings["MaxPoolSize"]);

		// Other
		public static string textDivider = "------------------------------------------------------------------------";
		public static string tsplaceholder = "                        ";
		public static bool hasErrors = false;

	}
}
