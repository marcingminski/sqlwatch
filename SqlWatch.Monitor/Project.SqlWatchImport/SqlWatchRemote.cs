using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Configuration;

namespace SqlWatchImport
{
	internal class SqlWatchRemote
	{

		public static double t1 = 0; // Total time ms spent on bulk copy full load;
		public static double t2 = 0; // Total time ms spent on merge;
		public static double t3 = 0; // Total time ms spent on getting last snapshot from the central repository;
		public static double t4 = 0; // Total time ms spent on bulk copy delta load;

		#region CommandLine
		public static bool Add (string SqlInstance, string SqlDatabase, string Hostname = null, int? SqlPort = null, string SqlUser = null, string SqlPassword = null)
        {
			string SqlSecret = null;

			if (SqlPassword != null)
            {
				SqlSecret = Tools.Encrypt(SqlPassword);
			}

			if (SqlPort == 0)
            {
				SqlPort = null;
            }

			using (SqlConnection conn = SqlWatchRepository.Connection())
            {
				string query = @"insert into [dbo].[sqlwatch_config_sql_instance]([sql_instance]
										,[hostname],[sql_port],[sqlwatch_database_name]
										,[repo_collector_is_active],[sql_user],[sql_secret])
						values(@sql_instance, @hostname, @port, @database, 1, @sql_user, @sql_secret);";

				using (SqlCommand command = new SqlCommand(query,conn))
                {
					command.Parameters.AddWithValue("@sql_instance", SqlInstance);
					command.Parameters.AddWithValue("@hostname", Hostname ?? (object)DBNull.Value);
					command.Parameters.AddWithValue("@port", SqlPort ?? (object)DBNull.Value);
					command.Parameters.AddWithValue("@database", SqlDatabase);
					command.Parameters.AddWithValue("@sql_user", SqlUser ?? (object)DBNull.Value);
					command.Parameters.AddWithValue("@sql_secret", SqlSecret ?? (object)DBNull.Value);

					conn.Open();

					try
                    {
						command.ExecuteNonQuery();
						Console.WriteLine("OK");
						return true;
					}
					catch (SqlException e)
                    {
						Console.WriteLine(e.Errors[0].Message);
						return false;
                    }
				}
			}
		}

		public static bool Update(string SqlInstance, string SqlUser, string SqlPassword)
        {
			string SqlSecret = Tools.Encrypt(SqlPassword);
			using (SqlConnection conn = SqlWatchRepository.Connection())
			{
				string query = @"update [dbo].[sqlwatch_config_sql_instance]
							set sql_secret = @sql_secret, 
							    sql_user = @sql_user
						where sql_instance = @sql_instance";

				using (SqlCommand command = new SqlCommand(query, conn))
				{
					command.Parameters.AddWithValue("@sql_instance", SqlInstance);
					command.Parameters.AddWithValue("@sql_user", SqlUser);
					command.Parameters.AddWithValue("@sql_secret", SqlSecret);

					conn.Open();

					try
					{
						command.ExecuteNonQuery();
						Console.WriteLine("OK");
						return true;
					}
					catch (SqlException e)
					{
						Console.WriteLine(e.Errors[0].Message);
						return false;
					}
				}
			}

		}

		#endregion

		public static async Task<bool> Import(string SqlInstance)
		{
			Stopwatch sw = Stopwatch.StartNew();

			Logger.LogMessage($"Importing: [{ SqlInstance }]");

			bool isOnlineResult = false;
			Task tIsOnline = Task.Run(async () =>
			{
				isOnlineResult = await IsOnline(SqlInstance);
			});

			Task.WaitAll(tIsOnline);

			if (isOnlineResult == false)
			{
				return false;
			}

			await Task.Run(() => 
			{
				List<Task> tasks = new List<Task>();

				for (int i = 1; i <= 20; i++)
				{
					foreach (DataRow row in SqlWatchRepository.tablesToImport.Select($"dependency_level = {i}"))
					{
						string tableName = row["table_name"].ToString();

						if (tableName == "")
						{
							break; //no more tables to process
						}

						if (
								(tableName.Contains("sqlwatch_meta"))
								|| ((tableName.Contains("sqlwatch_logger")) && Config.LoggerTablesFullLoad == true)
								|| (tableName == "dbo.sqlwatch_logger_snapshot_header" && Config.snapshotHeaderFullLoad == true)
								)
						{
							Task task = Task.Run(async () =>
							{
								Logger.LogVerbose($"Importing FULL remote data from [{ SqlInstance }].[{ tableName }]");
								await ImportTableFull(SqlInstance, tableName);

								//populate lat snapshot tiem for each type
								if (tableName == "dbo.sqlwatch_logger_snapshot_header")
								{
									await Task.Run(() => { SqlWatchRepository.GetLastSnapshoHeader(SqlInstance); });
								}
							});
							tasks.Add(task);
						}
						else if (tableName.Contains("sqlwatch_logger"))
						{
							Task task = Task.Run(async () =>
							{
								Logger.LogVerbose($"Importing DELTA remote data from [{ SqlInstance }].[{ tableName }]");
								await ImportTableDelta(SqlInstance, tableName);

								//populate lat snapshot tiem for each type
								if (tableName == "dbo.sqlwatch_logger_snapshot_header")
								{
									await Task.Run(() => { SqlWatchRepository.GetLastSnapshoHeader(SqlInstance); });
								}
							});
							tasks.Add(task);

						};
						//wait until all tasks for the given dependency level are finished
						Task.WaitAll(tasks.ToArray());
					}
				}
			});

			Logger.LogMessage($"Finished: { SqlInstance }. Time taken: { sw.Elapsed.TotalMilliseconds }ms");
			return true;
		}

		private static async Task<bool> ImportTableFull(string SqlInstance, string TableName)
		{
			Stopwatch tt = Stopwatch.StartNew();

			using (SqlConnection repoConnection = SqlWatchRepository.Connection())
			{
				repoConnection.Open();

				string PkColumns = SqlWatchRepository.TablePrimaryKey(TableName);

				string sql = $"select top 0 * into [#{ TableName }] from { TableName };";

				if (PkColumns != "")
                {
					sql += $"alter table [#{ TableName }] add primary key ({ PkColumns }); ";
				}

				using (SqlCommand repoCommand = new SqlCommand(sql, repoConnection))
                {
					Logger.LogVerbose($"Preparing landing table for [{ SqlInstance }].{ TableName }");

					try
					{
						await repoCommand.ExecuteNonQueryAsync();
					}
					catch (SqlException e)
					{
						Logger.LogError($"Failed to prepare table for [{ SqlInstance }].{ TableName}", e.Errors[0].Message);
						return false;
					}
				}

				using (SqlConnection remoteConnection = SqlWatchRemote.Connection(SqlInstance))
				{
					remoteConnection.Open();

					//Logger tables must have a valid header record. Despite the dependency order, it may happen that we will try to import new logger records after we have alrady imported header.
					//This could happen if the import is running for a long time and enough time has passed between header and the logger records that new data was inserted at source.
					//We have to make sure we're only importing logger records up to the max snapshot time in the repository. For this to happen, we need to know the snapshot_type_id for each table.

					string lastSeenInRepo = "";
					if (Config.respectDateLastSeen == true)
                    {
						if (SqlWatchRepository.Table.HasColumnLastSeen(TableName) == true)
						{

							sql = $"select convert(varchar(30),isnull(max(date_last_seen),'1970-01-01'),121) from { TableName }";
							using (SqlCommand cmdGetRepoLastSeen = new SqlCommand(sql, repoConnection))
							{
								lastSeenInRepo = (await cmdGetRepoLastSeen.ExecuteScalarAsync()).ToString();
							}
						}
					}

					if (TableName.Contains("sqlwatch_logger"))
                    {
						sql = $"select * from { TableName } where snapshot_time <= '{ SqlWatchRepository.LastHeaderSnapshotDate(SqlInstance, SqlWatchRepository.TableSnapshotType(TableName)) }'";
						if (lastSeenInRepo != "")
                        {
							sql += $" and date_last_seen > '{ lastSeenInRepo }'";
                        }
					} 
					else
                    {
						sql = $"select * from { TableName }";
						if (lastSeenInRepo != "")
						{
							sql += $" where date_last_seen > '{ lastSeenInRepo }'";
						}
					}

					using (SqlCommand cmdGetData = new SqlCommand(sql, remoteConnection))
                    {
						cmdGetData.CommandTimeout = Config.DataCopyExecTimeout;
						//import data into #t table
						try
						{
							Stopwatch bk1 = Stopwatch.StartNew();
							using (SqlDataReader reader = await cmdGetData.ExecuteReaderAsync())
							{
								Logger.LogVerbose($"Preparing to Bulk Copy remote data from [{ SqlInstance }].{ TableName } to landing table #{ TableName }");

								using (SqlBulkCopy sqlBulkCopy = new SqlBulkCopy(repoConnection, SqlBulkCopyOptions.KeepIdentity, null))
								{
									sqlBulkCopy.DestinationTableName = $"[#{ TableName }]";
									sqlBulkCopy.BulkCopyTimeout = Config.DataCopyExecTimeout;
									if (Config.StreamData)
									{
										sqlBulkCopy.EnableStreaming = true;
									}

									try
									{
										Logger.LogVerbose($"Copying remote data from [{ SqlInstance }].{ TableName } to landing table #{ TableName } using BulkCopy.");
										await sqlBulkCopy.WriteToServerAsync(reader);
										t1 += bk1.Elapsed.TotalMilliseconds;
										Logger.LogVerbose($"Bulk Copied remote data from [{ SqlInstance }].{ TableName } to landing table #{ TableName } in { bk1.Elapsed.TotalMilliseconds }ms. Awaiting Merge.");
									}
									catch (SqlException e)
									{
										Logger.LogError($"Failed to Bulk Copy data from [{ SqlInstance }].{ TableName }", e.Errors[0].Message);
										return false;
									}
								}
							}
						}
						catch (SqlException e)
						{
							Logger.LogError($"Failed to populate DataReader with remote Data from [{ SqlInstance }].{ TableName }", e.Errors[0].Message, sql);
							return false;
						}
					}

					sql = "";
					if (SqlWatchRepository.TableHasIdentity(TableName) == true)
                    {
						sql += $"\nset identity_insert { TableName } on;";
                    }

					string allColumns = SqlWatchRepository.TableColumns(TableName);

					sql += $@"
							;merge { TableName } as target
								using [#{ TableName }] as source
							on ({ SqlWatchRepository.TableMergeJoins(TableName) })
							when not matched
							then insert ({ allColumns })
							values (source.{ allColumns.Replace(",", ",source.") })";

					string updateColumns = SqlWatchRepository.TableMergeUpdateColumns(TableName);
					if (updateColumns != "")
                    {
						sql += $@"
							when matched
							then update set
							{ updateColumns }";	
                    }

					sql += ";";

					if (SqlWatchRepository.TableHasIdentity(TableName) == true)
					{
						sql += $"\nset identity_insert { TableName } off;";
					}

					using (SqlCommand cmdMergeTable = new SqlCommand(sql,repoConnection))
                    {
						cmdMergeTable.CommandTimeout = Config.DataCopyExecTimeout;

						Logger.LogVerbose($"Merging [{ SqlInstance }]." + TableName);
						try
						{
							Stopwatch mg = Stopwatch.StartNew();
							int nRows = await cmdMergeTable.ExecuteNonQueryAsync();
							t2 += mg.Elapsed.TotalMilliseconds;
							if (nRows == 1)
							{
								Logger.LogVerbose($"Merged { nRows } row from [{ SqlInstance }].{ TableName } in { mg.Elapsed.TotalMilliseconds }ms");
							}
							else
							{
								Logger.LogVerbose($"Merged { nRows } rows from [{ SqlInstance }].{ TableName } in { mg.Elapsed.TotalMilliseconds }ms");
							}
							Logger.LogSuccess($"Imported { TableName } from { SqlInstance } in { tt.Elapsed.TotalMilliseconds }ms");

							return true;
						}
						catch (SqlException e)
						{
							Logger.LogError($"Failed to merge table [{ SqlInstance }].{ TableName }", e.Errors[0].Message, sql);
							//dump # table to physical table to help debugging
							sql = $"select * into [_DUMP_{ string.Format("{0:yyyyMMddHHmmssfff}", DateTime.Now) }_{ SqlInstance }.{ TableName }] from [#{ TableName }]";
							using (SqlCommand cmdDumpData = new SqlCommand(sql, repoConnection))
							{
								try
								{
									cmdDumpData.ExecuteNonQuery();
								}
								catch (SqlException x)
								{
									Logger.LogError("Failed to dump data into a table for debugging", x.Errors[0].Message, sql);
									return false;
								}
							}
							return false;
						}
					}
				}
			}
		}

		private static async Task<bool> ImportTableDelta(string SqlInstance, string TableName)
		{
			Stopwatch sw = Stopwatch.StartNew();

			using (SqlConnection repoConnection = SqlWatchRepository.Connection())
			{
				await repoConnection.OpenAsync();

				string snapshotTime = "1970-01-01";

				using (SqlCommand cmdGetLastSnapshotTime = new SqlCommand($"select [snapshot_time]=isnull(convert(varchar(23),max([snapshot_time]),121),'{ snapshotTime }') from { TableName } (nolock)", repoConnection))
				{
					Stopwatch ls = Stopwatch.StartNew();
					snapshotTime = (await cmdGetLastSnapshotTime.ExecuteScalarAsync()).ToString();
					t3+=ls.Elapsed.TotalMilliseconds;
				}

				//Logger tables must have a valid header record. Despite the dependency order, it may happen that we will try to import new logger records after we have alrady imported header.
				//This could happen if the import is running for a long time and enough time has passed between header and the logger records that new data was inserted at source.
				//We have to make sure we're only importing logger records up to the max snapshot time in the repository. For this to happen, we need to know the snapshot_type_id for each table.

				using (SqlConnection remoteConnection = SqlWatchRemote.Connection(SqlInstance))
				{
					await remoteConnection.OpenAsync();

					using (SqlCommand remoteCommand = new SqlCommand($"select * " +
						$"from { TableName } " +
						$"where [snapshot_time] > '{ snapshotTime }' " +
						$"and [snapshot_time] <= '{ SqlWatchRepository.LastHeaderSnapshotDate(SqlInstance, SqlWatchRepository.TableSnapshotType(TableName)) }'", remoteConnection))
                    {
						remoteCommand.CommandTimeout = Config.DataCopyExecTimeout;

						Stopwatch bk2 = Stopwatch.StartNew();
						using (SqlDataReader reader = await remoteCommand.ExecuteReaderAsync())
						{
							using (SqlBulkCopy sqlBulkCopy = new SqlBulkCopy(repoConnection, SqlBulkCopyOptions.KeepIdentity, null))
							{
								sqlBulkCopy.DestinationTableName = TableName;
								sqlBulkCopy.BulkCopyTimeout = Config.DataCopyExecTimeout;
								
								if (Config.StreamData) 
								{
									sqlBulkCopy.EnableStreaming = true;
								}

								int rowCount = reader.Cast<object>().Count();

								Logger.LogVerbose("Writing remote data from [" + SqlInstance + "]." + TableName);

								try
								{
									await sqlBulkCopy.WriteToServerAsync(reader);
									t4 += bk2.Elapsed.TotalMilliseconds;
									if (rowCount == 1)
									{
										Logger.LogVerbose($"Bulk copied { rowCount.ToString() } row from [{ SqlInstance }].{ TableName } in { sw.Elapsed.TotalMilliseconds }ms");
									}
									else
									{
										Logger.LogVerbose($"Bulk copied { rowCount.ToString() } rows from [{ SqlInstance }].{ TableName } in { sw.Elapsed.TotalMilliseconds }ms");
									}

									Logger.LogSuccess($"Imported { TableName } from { SqlInstance } in { sw.Elapsed.TotalMilliseconds }ms");
								}
								catch (Exception e)
								{
									Logger.LogError("Failed to Bulk Copy data from [" + SqlInstance + "]." + TableName);
									Logger.LogError(e.ToString());
								}
							}
						}
					}	
				}
			}
			return true;
		}

		public static SqlConnection Connection(string SqlInstance, int? ConnectTimeout = null)
		{

			//SqlInstance = @@SERVERNAME but it may not always be the same as the physical hostname.
			SqlConnectionStringBuilder conn = new SqlConnectionStringBuilder();
			conn.DataSource = SqlWatchRepository.RemoteHostname(SqlInstance);
			conn.InitialCatalog = SqlWatchRepository.RemoteSqlDatabase(SqlInstance);
			conn.ConnectTimeout = ConnectTimeout.HasValue ? (int)ConnectTimeout : Config.RemoteInstanceConnectTimeOut;
			//conn.MultipleActiveResultSets = true;
			conn.MinPoolSize = 0;
			conn.Pooling = true;
			conn.ApplicationName = Config.ApplicationName;

			string RemoteSqlUser = SqlWatchRepository.RemoteSqlUser(SqlInstance);

			if (RemoteSqlUser != "")
			{
				string SqlSecret = SqlWatchRepository.RemoteSqSecret(SqlInstance);
				string SqlPassword = Tools.Decrypt(SqlSecret);
				conn.UserID = RemoteSqlUser;
				conn.Password = SqlPassword;
			}
			else
			{
				conn.IntegratedSecurity = true;
			}
			return new SqlConnection(conn.ConnectionString);
		}

		public static async Task<bool> IsOnline(string SqlInstance)
        {
			Logger.LogVerbose($"Checking if { SqlInstance } is online");
			try
            {
				using (SqlConnection conn = Connection(SqlInstance,5))
                {
					await conn.OpenAsync();
					return true;
                }
            }
			catch (SqlException e)
            {
				Logger.LogError("Unable to open connection to the remote instance: " + SqlInstance, e.Errors[0].Message);
				return false;
            }
        }
	}
}
