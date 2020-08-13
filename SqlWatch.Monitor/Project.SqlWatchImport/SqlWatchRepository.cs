using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;

namespace SqlWatchImport
{
	internal class SqlWatchRepository
	{

		// poor mans caching of sql results. DataTables are not super efficient
		// we're not storing lots of data and avoid frequent db calls.

		// distinct list of tables to import < 100
		public static DataTable tablesToImport = new DataTable();
		
		// distinct list of last header record per type per sql instance
		public static DataTable snapshotHeader = new DataTable();

		// list of remote instances to import
		public static DataTable remoteServers = new DataTable();

		// remote instance details
		public static DataTable sqlInstance = new DataTable();

		// list of snapshot type ids per table
		public static DataTable tableSnapshotType = new DataTable();

		public static string LastHeaderSnapshotDate(string SqlInstance, int? SnapshotTypeId = -1)
        {
			// Gets the most recent snapshot for the given SqlInstance and SnapshotTypeId from the header table.

			string output = "";
			string defautlvalue = "2099-12-31";

			try
            {
				//we're returning date as string as we're gonna be passing it back to sql as an ISO string anyway
				if (SnapshotTypeId == (int)0)
				{
					output = defautlvalue;
				}
				else
				{

					foreach (DataRow row in snapshotHeader.Select($"sql_instance = '{SqlInstance}' and snapshot_type_id = { SnapshotTypeId }"))
					{
						output = row["snapshot_time"].ToString();
						break;
					}
				}

				return output;
			}
			catch
            {
				Logger.LogWarning($"No SnaphotHeader cache found for snapshot_type_id { SnapshotTypeId } for [{ SqlInstance }].");
				return defautlvalue;
			}
		}

		public static List<string> RemoteServers()
		{
			// Gets the list of remote servers to import data from
			
			List<String> RemoteSqlInstance = new List<String>();

			foreach (DataRow row in remoteServers.Rows)
			{
				RemoteSqlInstance.Add(row["RemoteSqlInstance"].ToString());
			}

			return RemoteSqlInstance;
		}

		public static string RemoteSqlDatabase(string SqlInstance)
		{
			// Gets the name of the remote SqlWatch database from the config table
			
			// return GetScalarString("select [sqlwatch_database_name] " +
			//	"from [dbo].[sqlwatch_config_sql_instance] where [sql_instance] = '" + SqlInstance + "'");

			DataRow[] dr = remoteServers.Select($"RemoteSqlInstance = '{ SqlInstance }'");
			return dr[0]["SqlWatchDatabase"].ToString();
		}

		public static async Task<bool> GetTableSnapshoTypes()
        {

			// Gets a list of all tables and snapshot types for each table

			Logger.LogVerbose("Getting Snapshot Type for each Logger table");

			// get list of tables first:
			string sql = @"select stuff(( 
	select ' union all select top 1 TABLE_NAME=''' + TABLE_NAME + ''', snapshot_type_id from ' +  + '.' + TABLE_NAME
	from (
		select distinct TABLE_NAME=TABLE_SCHEMA + '.' + TABLE_NAME
		from INFORMATION_SCHEMA.COLUMNS
		where TABLE_NAME like 'sqlwatch_logger%'
		and COLUMN_NAME = 'snapshot_type_id'
		) t
	for xml path('')),1,10,'')";

			using (SqlConnection connection = Connection())
            {
				using (SqlCommand command = new SqlCommand(sql,connection))
                {
					await connection.OpenAsync();

					// execute the first sql query to build union:
					sql = (await command.ExecuteScalarAsync()).ToString();

					using (SqlDataAdapter adapter = new SqlDataAdapter(sql, connection))
					{
						// execute the union and save result:
						int i = adapter.Fill(tableSnapshotType);
					}
				}
            }

			return true;
        }

        public static int TableSnapshotType(string TableName)
        {
			
			// Gets the snapshot type id for the table in question.
			// Does not apply to the snapshot header itself.
			// The header must always download all available data from source:

			if (TableName != "dbo.sqlwatch_logger_snapshot_header")
            {
				
				try
                {
					DataRow[] dr = tableSnapshotType.Select($"TABLE_NAME = '{ TableName }'");
					return int.Parse(dr[0]["snapshot_type_id"].ToString());
				}
				catch (IndexOutOfRangeException)
				{
					Logger.LogWarning($"No snapshot_type_id found in {TableName }. This is likely becuase the table is empty.");
					return (int)0;
				}
			}
			else
            {
				return (int)0;
            }

        }

		public static string RemoteHostname(string SqlInstance)
		{
			// Gets the remote Hostname from the config table.
			
			// return GetScalarString("select hostname=isnull(hostname,sql_instance) + isnull(','+convert(varchar(10),[sql_port]),'') " +
			//	"from [dbo].[sqlwatch_config_sql_instance] where [sql_instance] = '" + SqlInstance + "'");

			DataRow[] dr = remoteServers.Select($"RemoteSqlInstance = '{ SqlInstance }'");
			return dr[0]["Hostname"].ToString();
		}

		public static string RemoteSqSecret(string SqlInstance)
		{
			// Gets the sql secret from the config table

			// return GetScalarString("select [sql_secret]=isnull([sql_secret],'') " +
			//	"from [dbo].[sqlwatch_config_sql_instance] where [sql_instance] = '" + SqlInstance + "'");

			DataRow[] dr = remoteServers.Select($"RemoteSqlInstance = '{ SqlInstance }'");
			return dr[0]["SqlSecret"].ToString();
		}

		public static string RemoteSqlUser(string SqlInstance)
		{
			// Gets the Sql user from the config table

			// return GetScalarString("select [sql_user]=isnull([sql_user],'') " +
			//	"from [dbo].[sqlwatch_config_sql_instance] where [sql_instance] = '" + SqlInstance + "'");

			DataRow[] dr = remoteServers.Select($"RemoteSqlInstance = '{ SqlInstance }'");
			return dr[0]["SqlUser"].ToString();
		}

		public static SqlConnection Connection(int? ConnectTimeout = null)
		{
			// Generic connection builder for the central repository

			SqlConnectionStringBuilder conn = new SqlConnectionStringBuilder();
			conn.DataSource = Config.centralRepoSqlInstance;
			conn.InitialCatalog = Config.centralRepoSqlDatabase;
			conn.ConnectTimeout = ConnectTimeout.HasValue ? (int)ConnectTimeout : Config.CentralRepositoryConnectTimeOut;
			conn.MinPoolSize = Config.MinPoolSize;
			conn.Pooling = true;
			conn.ApplicationName = Config.ApplicationName;

			//this is required when we were running everything in a single connection but since
			//we're using connection pooling, this has no use.
			//conn.MultipleActiveResultSets = true; 

			if (Config.MaxPoolSize != 0)
			{
				conn.MaxPoolSize = Config.MaxPoolSize;
			}

			if (Config.centralRepoSqlUser != "" && Config.centralRepoSqlSecret != "")
			{
				conn.UserID = Config.centralRepoSqlUser;
				conn.Password = Tools.Decrypt(Config.centralRepoSqlSecret);
			}
			else
			{
				conn.IntegratedSecurity = true;
			}

			return new SqlConnection(conn.ConnectionString);
		}

		public static string TableColumns (string TableName)
        {
			// Gets the concatenated list of columns in a given table

			DataRow[] dr = tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
			return dr[0]["allcolumns"].ToString();
		}
		
		public static string TableMergeUpdateColumns(string TableName)
        {
			// Gets the concatenated list of columns for update in the merge statement

			DataRow[] dr = tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
			return dr[0]["updatecolumns"].ToString();
		}

		public static string TableMergeJoins(string TableName)
        {
			// Gets joins for the merge statement 

			DataRow[] dr = tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
			return dr[0]["joins"].ToString();
		}
		
		public static bool TableHasIdentity(string TableName)
		{
			// Checks if the table has identity

			DataRow[] dr = tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
			if (dr[0]["has_identity"].ToString() == "1")
            {
				return true;
            }
			else
            {
				return false;
            }
		}

		public static string TablePrimaryKey(string TableName)
        {
			// Gets concatenated list of primary keys in a table

			DataRow[] dr = tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
			return dr[0]["primary_key"].ToString();
		}

		public static void GetRemoteTables()
		{
			// Gets a list of tables to import and populates DataTable

			Logger.LogVerbose("Getting Remote Tables to process");
			using (SqlConnection connection = Connection())
			{
			
				string sql = "select * from [dbo].[sqlwatch_stage_repository_tables_to_import] order by dependency_level";

				using (SqlDataAdapter adapter = new SqlDataAdapter(sql, connection))
				{
					int i = adapter.Fill(tablesToImport);
					tablesToImport.DefaultView.Sort = "dependency_level";
					tablesToImport = tablesToImport.DefaultView.ToTable();

					if (i == 1)
					{
						Logger.LogMessage("Got 1 table to import from each remote instance");
					}
					else
					{
						Logger.LogMessage($"Got { i } tables to import from each remote instance");
					}
				}
			}
		}

		public static void GetRemoteServers()
        {
			// Gets remote servers to import and populates DataTable

			Logger.LogVerbose("Getting Remote Servers to process.");

			string sql = @"select RemoteSqlInstance = sql_instance
									, Hostname=isnull(hostname,sql_instance) + isnull(','+convert(varchar(10),[sql_port]),'')
									, SqlSecret=isnull([sql_secret],'')
									, SqlUser=isnull([sql_user],'')
									, SqlWatchDatabase = [sqlwatch_database_name]
							from [SQLWATCH].[dbo].[sqlwatch_config_sql_instance]
							where repo_collector_is_active = 1";

			using (SqlConnection connection = Connection())
            {
				using (SqlDataAdapter adapter = new SqlDataAdapter(sql, connection))
				{
					int i = adapter.Fill(remoteServers);

					if (i == 1)
                    {
						Logger.LogMessage("Got 1 server to process");
					}
					else
                    {
						Logger.LogMessage($"Got { i } servers to process");
					}
				}
			}
		}

		public static void GetLastSnapshoHeader(string SqlInstance)
		{
			
			// Gets last snapshot for each type for a SqlInstance

			try
			{
				if (snapshotHeader.Rows.Count == 0)
				{
					using (SqlConnection connection = Connection())
					{

						string sql = $@"select sql_instance, snapshot_type_id, snapshot_time=max(snapshot_time)
								from dbo.sqlwatch_logger_snapshot_header
								where sql_instance = '{ SqlInstance }'
								group by sql_instance, snapshot_type_id";

						connection.Open();

						using (SqlDataAdapter adapter = new SqlDataAdapter(sql, connection))
						{
							int i = adapter.Fill(snapshotHeader);
						}
					}

				}
			}
			catch
			{
				Logger.LogWarning($"SnapshotHeader DataTable is not yet populated. Are we importing logger tables before we imported snapshot header?");
			}

		}

		public static string GetScalarString(string query)
		{

			// Generic function to get scalar string. 

			using (SqlConnection connection = Connection())
			{
				try
				{
					connection.Open();

					using (SqlCommand command = new SqlCommand(query, connection))
                    {
						string output = (string)command.ExecuteScalar();
						return output;
					}
				}
				catch (SqlException e)
				{
					Logger.LogError("GetScalarString failed.", e.Errors[0].Message, query);
					return "";
				}
			}
		}

		public static int? GetScalarNum(string query)
		{

			// Generic function to get scalar numeric

			using (SqlConnection connection = Connection())
			{
				try
				{
					connection.Open();

					using (SqlCommand command = new SqlCommand(query,connection))
                    {
						int output = (int)command.ExecuteScalar();
						return output;
					}
				}
				catch (SqlException e)
				{
					Logger.LogError("GetScalarNum failed.", e.Errors[0].Message, query);
					return null;
				}
			}
		}

		public static async Task<bool> IsOnline()
		{
			// Checks if the server is online

			Logger.LogVerbose($"Checking if Central Repository is online");
			try
			{
				using (SqlConnection conn = Connection(10))
				{
					await conn.OpenAsync();
					return true;
				}
			}
			catch (SqlException e)
			{
				Logger.LogCritical("Unable to open connection to the Central Repository", e.Errors[0].Message);
				return false;
			}
		}

		internal class Table
		{
			public static bool HasColumnLastSeen(string TableName)
			{
				// Checks if table has a given column

				DataRow[] dr = SqlWatchRepository.tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
				if (dr[0]["has_last_seen"].ToString() == "1")
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
}
