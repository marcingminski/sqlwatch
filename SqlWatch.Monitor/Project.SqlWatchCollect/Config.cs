using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Reflection;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
	public class Config : IDisposable
	{

		public string RepositoryConnectionString
		{
			get
			{
				SqlConnectionStringBuilder conn = new SqlConnectionStringBuilder
				{
					DataSource = centralRepoSqlInstance,
					InitialCatalog = centralRepoSqlDatabase,
					ConnectTimeout = CentralRepositoryConnectTimeOut,
					MinPoolSize = 0,
					Pooling = true,
					MultipleActiveResultSets = true,
					ApplicationName = ApplicationName,
					IntegratedSecurity = centralRepoSqlUser == "" ? true : false,
					UserID = centralRepoSqlUser == "" ? "" : centralRepoSqlUser,
					Password = centralRepoSqlSecret == "" ? "" : Tools.Decrypt(centralRepoSqlSecret)
				};

				return conn.ConnectionString;
			}
		}

		//public class RemoteInstance
		//{
		//	public string SqlInstance { get; set; }
			
		//	public string SqlDatabase { get; set; }
			
		//	public string Hostname { get; set; }
			
		//	public string SqlUser { get; set; }
			
		//	public string SqlSecret { get; set; }

		//	public bool IntegratedSecurity { get; set; }
		//}

		//central repository config
		public string centralRepoSqlInstance = ConfigurationManager.AppSettings["CentralRepositorySqlInstance"];
		public string centralRepoSqlDatabase = ConfigurationManager.AppSettings["CentralRepositorySqlDatabase"];
		public string centralRepoSqlUser = ConfigurationManager.AppSettings["CentralRepositorySqlUser"];
		public string centralRepoSqlSecret = ConfigurationManager.AppSettings["CentralRepositorySqlSecret"];

		public static int CentralRepositoryConnectTimeOut = 300;

		public static int BulkCopyTimeout = int.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.BulkCopyTimeout"]);
		public static bool SqlBkEnableStreaming = bool.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.EnableStreaming"]);
		public static int SqlBkBatchSize = int.Parse(ConfigurationManager.AppSettings["SqlBulkCopy.BatchSize"]);

		//Aplication performance
		public static int MinThreads = int.Parse(ConfigurationManager.AppSettings["MinThreads"]);
		public static int MaxThreads = int.Parse(ConfigurationManager.AppSettings["MaxThreads"]);
		public static int MinPoolSize = int.Parse(ConfigurationManager.AppSettings["MinPoolSize"]);
		public static int MaxPoolSize = int.Parse(ConfigurationManager.AppSettings["MaxPoolSize"]);

		// Other
		public string ApplicationTitle = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyTitleAttribute>().Title;
		public string ApplicationDescription = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyDescriptionAttribute>().Description;
		public string ApplicationCopyright = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyCopyrightAttribute>().Copyright;
		public string ApplicationName = Assembly.GetExecutingAssembly().GetCustomAttribute<AssemblyProductAttribute>().Product;
		public string ApplicationVersion = Assembly.GetExecutingAssembly().GetName().Version.ToString();
		public DateTime ApplicationBuildDate = new DateTime(2000, 1, 1).AddDays(Assembly.GetExecutingAssembly().GetName().Version.Build).AddSeconds(Assembly.GetExecutingAssembly().GetName().Version.Revision * 2);

		//Target setting
		public int maxQueueSize = int.Parse(ConfigurationManager.AppSettings["MaxQueueSize"]);
		public string TargetType = ConfigurationManager.AppSettings["TargetType"];

		//Log File
		public static int maxLogSizeMB = int.Parse(ConfigurationManager.AppSettings["MaxLogSizeMB"]);
		public static int MaxLogFiles = int.Parse(ConfigurationManager.AppSettings["MaxLogFiles"]);
		public static string LogFile = ConfigurationManager.AppSettings["LogFile"];
		public static bool PrintToConsole = bool.Parse(ConfigurationManager.AppSettings["PrintToConsole"]);
		public static bool PrintToLogFile = bool.Parse(ConfigurationManager.AppSettings["PrintToLogFile"]);

		public async Task<int> GetQueueSizeAsync()
		{
			using (SqlConnection repositoryConnection = new SqlConnection(RepositoryConnectionString))
			{
				string sql = "select count(*) from dbo.sqlwatch_collector with (nolock)";

				using (SqlCommand repositoryCommand = new SqlCommand(sql, repositoryConnection))
				{
					await repositoryConnection.OpenAsync();
					int value = Convert.ToInt32(await repositoryCommand.ExecuteScalarAsync());
					Logger.LogVerbose($"Receiving queue has { value } items.");
					return value;
				}
			}
		}

		public async Task<bool> IsRepositoryOnlineAsync()
		{

			try
			{
				using (SqlConnection conn = new SqlConnection(this.RepositoryConnectionString))
				{

					await conn.OpenAsync();
					Logger.LogVerbose($"Server { this.centralRepoSqlInstance } is online.");
					return true;

				}
			}
			catch
			{
				Logger.LogVerbose($"Server {this.centralRepoSqlInstance} is offline.");
				return false;

			}
		}

		public async Task SetRepositoryConfiguration()
        {
			string sql = "update dbo.sqlwatch_config set config_value = 1 where config_id = 24 and config_value = 0;";

			using (SqlConnection connection = new SqlConnection(this.RepositoryConnectionString))
            {
				using (SqlCommand command = new SqlCommand(sql, connection))
                {
					await connection.OpenAsync();

					try
                    {
						await command.ExecuteNonQueryAsync();
					}
					catch (SqlException e)
                    {
						Logger.LogError(e.Errors[0].Message, e.Server, sql);
                    }
					
                }
            }
		}

		public async Task<string> GetSqlWatchVersion()
        {
			string version = string.Empty;

			using (SqlConnection repoConnection = new SqlConnection(RepositoryConnectionString))
            {
				string sqlCmd = @"SELECT [sqlwatch_version] FROM [dbo].[vw_sqlwatch_app_version]";

				using (SqlCommand repoCommand = new SqlCommand(sqlCmd, repoConnection))
                {
					repoCommand.CommandType = CommandType.Text;

					try
                    {
						await repoConnection.OpenAsync();

						var result = await repoCommand.ExecuteScalarAsync();

						version = result.ToString();
					}
					catch (SqlException e)
                    {
						Logger.LogSqlException(e);
                    }
                }
            }

			return version;

		}

		public async Task<bool> GetCollectorQueueStatusAsync()
        {
			string sql = @"select is_receive_enabled from sys.service_queues where name = 'sqlwatch_collector'";

			using (SqlConnection repositoryConnection = new SqlConnection(this.RepositoryConnectionString))
            {
				using (SqlCommand repositoryCommand = new SqlCommand(sql, repositoryConnection))
                {
					repositoryCommand.CommandType = CommandType.Text;
					
					await repositoryConnection.OpenAsync();
					
					if(Convert.ToInt32(await repositoryCommand.ExecuteScalarAsync()) == 1)
                    {
						return true;
					}
					else
                    {
						return false;
					}
				}
			}
		}
		
		public async Task<List<SqlWatchInstance>> GetRemoteInstancesAsync()
		{
			string sql = @"select RemoteSqlInstance = sql_instance
									, Hostname=isnull(hostname,sql_instance) + isnull(','+convert(varchar(10),[sql_port]),'')
									, SqlSecret=isnull([sql_secret],'')
									, SqlUser=isnull([sql_user],'')
									, SqlWatchDatabase = [sqlwatch_database_name]
									, IntegratedSecurity = integrated_security
							from [dbo].[sqlwatch_config_sql_instance]
							where repo_collector_is_active = 1
							order by case when sql_instance = @@SERVERNAME then '1' else sql_instance end";

			List<SqlWatchInstance> RemoteSqlInstance = new List<SqlWatchInstance>();

			using (SqlConnection connection = new SqlConnection(this.RepositoryConnectionString))
			{
				using (SqlCommand command = new SqlCommand(sql, connection))
				{
					await connection.OpenAsync();
					SqlDataReader reader = await command.ExecuteReaderAsync();

					if (reader.HasRows)
					{
						while (reader.Read())
						{
							SqlWatchInstance RemoteInstance = new SqlWatchInstance
							{
								SqlInstance = reader["RemoteSqlInstance"].ToString(),
								SqlDatabase = reader["SqlWatchDatabase"].ToString(),
								Hostname = reader["Hostname"].ToString(),
								SqlUser = reader["SqlUser"].ToString(),
								SqlSecret = reader["SqlSecret"].ToString(),
								IntegratedSecurity = Convert.ToBoolean(reader["IntegratedSecurity"])
							};

							RemoteSqlInstance.Add(RemoteInstance);
						}
					}

					connection.Close();
				}
			}

			return RemoteSqlInstance;
		}
		
		void IDisposable.Dispose() { }

	}

}