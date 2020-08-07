using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;

namespace SqlWatchImport
{
	internal class SqlWatchRepo
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
				
				// this sql has to be moved to a stored procedure and populate table
				// during deployment to save a bit of time with every execution
				string sql = @";WITH cte_tables (lvl, object_id, name, schema_Name) AS
  (SELECT 1, object_id, sys.tables.name, sys.schemas.name as schema_Name
   FROM sys.tables Inner Join sys.schemas on sys.tables.schema_id = sys.schemas.schema_id
   WHERE type_desc = 'USER_TABLE'
     AND is_ms_shipped = 0
	--and sys.tables.name like 'sqlwatch_meta%'
	and (sys.tables.name like 'sqlwatch_meta%' or sys.tables.name like 'sqlwatch_logger%')
	--exclude tables that have mo meaning outside of the original SQL Instance:
	and sys.tables.name not in (
		     'sqlwatch_meta_action_queue'
			,'sqlwatch_meta_repository_import_queue'
			,'sqlwatch_meta_repository_import_status'
			,'sqlwatch_meta_repository_import_thread'
			,'sqlwatch_logger_whoisactive'
			,'sqlwatch_logger_system_configuration_scd'
			)
   UNION ALL SELECT cte_tables.lvl + 1, t.object_id, t.name, S.name as schema_Name
   FROM cte_tables
   JOIN sys.tables AS t ON EXISTS
     (SELECT NULL FROM sys.foreign_keys AS fk
      WHERE fk.parent_object_id = t.object_id
        AND fk.referenced_object_id = cte_tables.object_id )
   JOIN sys.schemas as S on t.schema_id = S.schema_id
   AND t.object_id <> cte_tables.object_id
   AND cte_tables.lvl < 30
   WHERE t.type_desc = 'USER_TABLE'
	 --and t.name like 'sqlwatch_meta%'
	 and ( t.name like 'sqlwatch_meta%' or t.name like 'sqlwatch_logger%' )
	 and t.name not in ('sqlwatch_logger_whoisactive','sqlwatch_logger_system_configuration_scd')
     AND t.is_ms_shipped = 0 )
, cte_dependency as (
	SELECT table_name=d.schema_Name + '.' + d.name, MAX (d.lvl) AS dependency_level
	FROM cte_tables d
	GROUP BY schema_Name, name
)
select *
into dbo.sqlwatch_stage_repository_tables_to_import
from
cte_dependency d

outer apply (
	select has_last_seen = max(case when COLUMN_NAME = 'date_last_seen' then 1 else 0 end)
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_SCHEMA + '.' + TABLE_NAME = d.table_name
) c

outer apply (
select primary_key = isnull(stuff ((
		select ',' + quotename(ccu.COLUMN_NAME)
			from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
			inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
			on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
		where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
		and tc.CONSTRAINT_TYPE = 'Primary Key'
		order by ccu.ORDINAL_POSITION
		for xml path('')),1,1,''),'')
	) pks

outer apply (
select has_identity = isnull(isnull(( 
		select 1
		from SYS.IDENTITY_COLUMNS 
		where OBJECT_NAME(OBJECT_ID) = parsename(d.TABLE_NAME,1)
		),0),'')
) hasidentity

outer apply (
 select joins = isnull(stuff ((
		select ' and source.' + quotename(ccu.COLUMN_NAME) + ' = target.' + quotename(ccu.COLUMN_NAME)
			from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
			inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
			on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
		where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
		and tc.CONSTRAINT_TYPE = 'Primary Key'
		order by ccu.ORDINAL_POSITION
		for xml path('')),1,5,''),'')
) mergejoins

outer apply (

select updatecolumns = isnull(stuff((
		select ',' + quotename(COLUMN_NAME) + '=source.' + quotename(COLUMN_NAME)
		from INFORMATION_SCHEMA.COLUMNS
		where TABLE_NAME = parsename(d.TABLE_NAME,1)

		--excluding primary keys
		and COLUMN_NAME not in (
				select ccu.COLUMN_NAME
				from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
				inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
				on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
				where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
				and tc.CONSTRAINT_TYPE = 'Primary Key'
		)
		--excluding computed columns 
		and COLUMN_NAME not in (
				select cc.name 
				from sys.computed_columns cc
				inner join sys.tables t
					on t.object_id = cc.object_id
				where t.name = parsename(d.TABLE_NAME,1)
		)

		--excluding identity columns (some may be outside of PK)
		and COLUMN_NAME not in (
				select ic.name
				from sys.identity_columns ic
				inner join sys.tables t
					on t.object_id = ic.object_id
				where t.name = parsename(d.TABLE_NAME,1)
		)
		order by ORDINAL_POSITION
		for xml path('')),1,1,''),'')
) updatecolumns

outer apply (

select allcolumns = isnull(stuff ((
		select ',' + quotename(COLUMN_NAME)
		from INFORMATION_SCHEMA.COLUMNS
		where TABLE_NAME = parsename(d.TABLE_NAME,1)
		--excluding computed columns 
		and COLUMN_NAME not in (
				select name 
				from sys.computed_columns
		)
		order by ORDINAL_POSITION
		for xml path('')),1,1,''),'')
) allcolumns
ORDER BY dependency_level";

				sql = "select * from [dbo].[sqlwatch_stage_repository_tables_to_import] order by dependency_level";

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

				DataRow[] dr = SqlWatchRepo.tablesToImport.Select($"TABLE_NAME= '{ TableName }'");
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
