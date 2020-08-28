using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Caching;

namespace SqlWatchImport
{
	class SqlWatchInstance : IDisposable
	{

		public static double t1 = 0; // Total time ms spent on bulk copy full load;
		public static double t2 = 0; // Total time ms spent on merge;
		public static double t3 = 0; // Total time ms spent on getting last snapshot from the central repository;
		public static double t4 = 0; // Total time ms spent on bulk copy delta load;

		public string SqlInstance { get; set; }
		public string SqlDatabase { get; set; }
		public string SqlUser { get; set; }
		public string SqlSecret { get; set; }
		public int ConnectTimeout { get; set; } = 60;
		public string Hostname { get; set; } = "";
		public string ConnectionString
		{
			get
			{
				SqlConnectionStringBuilder conn = new SqlConnectionStringBuilder
				{
					DataSource = this.Hostname != "" ? this.Hostname : this.SqlInstance,
					InitialCatalog = this.SqlDatabase,
					ConnectTimeout = Config.RemoteInstanceConnectTimeOut,
					MinPoolSize = 0,
					Pooling = true,
					ApplicationName = Config.ApplicationName,
					IntegratedSecurity = this.SqlUser == "" ? true : false,
					UserID = this.SqlUser == "" ? "" : this.SqlUser,
					Password = this.SqlSecret == "" ? "" : Tools.Decrypt(this.SqlSecret)
				};

				return conn.ConnectionString;
			}
		}
		public string ConnectionStringRepository { get; set; }
		public string Vesion { get; set; }

		void IDisposable.Dispose() { }

		public class RemoteInstance
		{
			public string SqlInstance { get; set; }
			public string SqlDatabase { get; set; }
			public string Hostname { get; set; }
			public string SqlUser { get; set; }
			public string SqlSecret { get; set; }
		}

		public class SqlWatchTable
		{
			public string Name { get; set; }
			public int DependencyLevel { get; set; }
			public bool HasLastSeen { get; set; }
			public string PrimaryKey { get; set; }
			public bool HasIdentity { get; set; }
			public bool HasLastUpdated { get; set; }
			public string Joins { get; set; }
			public string UpdateColumns { get; set; }
			public string AllColumns { get; set; }
		}

		public class SqlWatchHeader
		{
			public string SqlInstance { get; set; }
			public int SnapshotTypeId { get; set; }
			public string SnapshotTime { get; set; } // storing time in ISO string as we're passing it straight back to SQL without doing anything with it in C#

		}

		public class SqlWatchTableSnapshotTypeId
		{
			public string TableName { get; set; }
			public int SnapshotTypeId { get; set; }
		}

		public async Task<List<SqlWatchTableSnapshotTypeId>> GetSqlWatchTableSnapshotTypeIdAsync()
		{
			// Get list of tables first:
			string sql = @"select stuff(( 
						select ' union all select top 1 TABLE_NAME=''' + TABLE_NAME + ''', snapshot_type_id from ' +  + '.' + TABLE_NAME
						from (
							select distinct TABLE_NAME=TABLE_SCHEMA + '.' + TABLE_NAME
							from INFORMATION_SCHEMA.COLUMNS
							where TABLE_NAME like 'sqlwatch_logger%'
							and COLUMN_NAME = 'snapshot_type_id'
							) t
						for xml path('')),1,10,'')";

			List<SqlWatchTableSnapshotTypeId> SqlWatchTableSnapshotType = new List<SqlWatchTableSnapshotTypeId>();

			using (SqlConnection connection = new SqlConnection(this.ConnectionString))
			{
				using (SqlCommand command = new SqlCommand(sql, connection))
				{
					await connection.OpenAsync();

					// Execute the first query to build sql string 
					sql = (await command.ExecuteScalarAsync()).ToString();
					command.CommandText = sql;

					SqlDataReader reader = await command.ExecuteReaderAsync();

					if (reader.HasRows)
					{
						while (reader.Read())
						{
							SqlWatchTableSnapshotTypeId Type = new SqlWatchTableSnapshotTypeId
							{
								TableName = reader["TABLE_NAME"].ToString(),
								SnapshotTypeId = int.Parse(reader["snapshot_type_id"].ToString())
							};

							SqlWatchTableSnapshotType.Add(Type);
						}
					}

					connection.Close();
				}
			}

			return SqlWatchTableSnapshotType;
		}

		public async Task<List<RemoteInstance>> GetRemoteInstancesAsync()
		{
			// Gets the list of remote servers to import data from

			string sql = @"select RemoteSqlInstance = sql_instance
									, Hostname=isnull(hostname,sql_instance) + isnull(','+convert(varchar(10),[sql_port]),'')
									, SqlSecret=isnull([sql_secret],'')
									, SqlUser=isnull([sql_user],'')
									, SqlWatchDatabase = [sqlwatch_database_name]
							from [SQLWATCH].[dbo].[sqlwatch_config_sql_instance]
							where repo_collector_is_active = 1";

			List<RemoteInstance> RemoteSqlInstance = new List<RemoteInstance>();

			using (SqlConnection connection = new SqlConnection(this.ConnectionString))
			{
				using (SqlCommand command = new SqlCommand(sql, connection))
				{
					await connection.OpenAsync();
					SqlDataReader reader = await command.ExecuteReaderAsync();

					if (reader.HasRows)
					{
						while (reader.Read())
						{
							RemoteInstance RemoteInstance = new RemoteInstance
							{
								SqlInstance = reader["RemoteSqlInstance"].ToString(),
								SqlDatabase = reader["SqlWatchDatabase"].ToString(),
								Hostname = reader["Hostname"].ToString(),
								SqlUser = reader["SqlUser"].ToString(),
								SqlSecret = reader["SqlSecret"].ToString()
							};

							RemoteSqlInstance.Add(RemoteInstance);
						}
					}

					connection.Close();
				}
			}

			return RemoteSqlInstance;
		}

		public async Task<List<SqlWatchTable>> GetTablesToImportAsync()
		{
			// Gets the list of remote servers to import data from

			string sql = @"SELECT TableName=[table_name]
								  ,DependencyLevel=[dependency_level]
								  ,HasLastSeen=[has_last_seen]
								  ,PrimaryKey=[primary_key]
								  ,HasIdentity=[has_identity]
								  ,HasLastUpdated=[has_last_updated]
								  ,Joins=[joins]
								  ,UpdateColumns=[updatecolumns]
								  ,AllColumns=[allcolumns]
							  FROM [dbo].[sqlwatch_stage_repository_tables_to_import]
							  ORDER BY dependency_level";

			List<SqlWatchTable> SqlWatchTable = new List<SqlWatchTable>();

			using (SqlConnection connection = new SqlConnection(this.ConnectionString))
			{
				using (SqlCommand command = new SqlCommand(sql, connection))
				{
					await connection.OpenAsync();

					SqlDataReader reader = await command.ExecuteReaderAsync();

					if (reader.HasRows)
					{
						while (reader.Read())
						{
							SqlWatchTable Table = new SqlWatchTable
							{
								Name = reader["TableName"].ToString(),
								DependencyLevel = int.Parse(reader["DependencyLevel"].ToString()),
								HasLastSeen = bool.Parse(reader["HasLastSeen"].ToString()),
								PrimaryKey = reader["PrimaryKey"].ToString(),
								HasIdentity = bool.Parse(reader["HasIdentity"].ToString()),
								HasLastUpdated = bool.Parse(reader["HasLastUpdated"].ToString()),
								Joins = reader["Joins"].ToString(),
								UpdateColumns = reader["UpdateColumns"].ToString(),
								AllColumns = reader["AllColumns"].ToString()
							};

							SqlWatchTable.Add(Table);
						}
					}

					connection.Close();
				}
			}

			return SqlWatchTable;
		}

		public async Task<List<SqlWatchHeader>> GetSqlWatchHeaderAsync()
		{
			// Gets the list of remote servers to import data from

			string sql = $@"select sql_instance, snapshot_type_id, 
								snapshot_time=convert(varchar(23),max(snapshot_time),121)
								from dbo.sqlwatch_logger_snapshot_header
								where sql_instance = '{ this.SqlInstance }'
								group by sql_instance, snapshot_type_id";

			List<SqlWatchHeader> SqlWatchHeader = new List<SqlWatchHeader>();

			using (SqlConnection connection = new SqlConnection(this.ConnectionStringRepository))
			{
				using (SqlCommand command = new SqlCommand(sql, connection))
				{
					await connection.OpenAsync();
					SqlDataReader reader = await command.ExecuteReaderAsync();

					if (reader.HasRows)
					{
						while (reader.Read())
						{
							SqlWatchHeader Header = new SqlWatchHeader
							{
								SqlInstance = reader["sql_instance"].ToString(),
								SnapshotTypeId = int.Parse(reader["snapshot_type_id"].ToString()),
								SnapshotTime = reader["snapshot_time"].ToString()
							};

							SqlWatchHeader.Add(Header);
						}
					}

					connection.Close();
				}
			}

			return SqlWatchHeader;
		}

		public async Task<bool> ImportAsync(List<SqlWatchTable> SqlWatchTables)
		{

			Stopwatch sw = Stopwatch.StartNew();

			string SqlInstance = this.SqlInstance;

			Logger.LogMessage($"Importing: \"{ SqlInstance }\"");

			if (await IsOnline() == false)
			{
				return false;
			}

			await Task.Run(() =>
			{
				List<Task<bool>> TableImportTasks = new List<Task<bool>>();

				int depLevels = (SqlWatchTables.Max(s => s.DependencyLevel));
				for (int i = 1; i <= depLevels; i++)
				{
					Parallel.ForEach(SqlWatchTables.FindAll(s => s.DependencyLevel == i), Table =>
					{
						Task<bool> TableImportTask = ImportTableAsync(
									Table.Name,
									Table.PrimaryKey,
									Table.HasIdentity,
									Table.HasLastSeen,
									Table.HasLastUpdated,
									Table.Joins,
									Table.UpdateColumns,
									Table.AllColumns
									);

						TableImportTasks.Add(TableImportTask);
					});

					Task.WhenAll(TableImportTasks);

					foreach (var result in (TableImportTasks.Select(t => t.Result).ToArray()))
					{
						if (result == false)
						{
							// If any of the tasks returns false we should break as may not have satisfied all dependencies.
							// Analogically, if the snapshot header returns zero rows, we will break as no new data to import.
							i = depLevels + 2;
						}
					}

				}
			});

			Logger.LogMessage($"Finished: \"{ SqlInstance }\". Time taken: { sw.Elapsed.TotalMilliseconds }ms");
			return true;
		}

		public async Task<bool> ImportTableAsync(
					string tableName,
					string primaryKeys,
					bool HasIdentity,
					bool HasLastSeen,
					bool HasLastUpdated,
					string Joins,
					string UpdateColumns,
					string AllColumns
			)
		{
			string SqlInstance = this.SqlInstance;

			Stopwatch tt = Stopwatch.StartNew();

			using (SqlConnection connectionRepository = new SqlConnection(this.ConnectionStringRepository))
			{
				Stopwatch tc = Stopwatch.StartNew();
				await connectionRepository.OpenAsync();
				//Logger.LogVerbose($"Opened connection to the Central Repository in { tc.Elapsed.TotalMilliseconds }ms.");

				string sql = "";

				using (SqlConnection connectionRemote = new SqlConnection(this.ConnectionString))
				{
					try
					{
						Stopwatch t = Stopwatch.StartNew();
						await connectionRemote.OpenAsync();
						//Logger.LogVerbose($"Opened connection to \"{ SqlInstance }\" to import \"{tableName}\" in { t.Elapsed.TotalMilliseconds }ms.");
					}
					catch (SqlException e)
					{
						Logger.LogError($"Failed to open connection to { this.SqlInstance }", e.Errors[0].Message);
						return false;
					}

					string lastSeenInRepo = Config.fullLoad == true ? "1970-01-01" : "";
					string lastUpdatedInRepo = Config.fullLoad == true ? "1970-01-01" : "";

					if (HasLastSeen == true && lastSeenInRepo == "")
					{
						// The nolock here is safe as nothing is modifying or writing data for specific instance but it does not block other threads modifying their own instances
						sql = $"select convert(varchar(30),isnull(max(date_last_seen),'1970-01-01'),121) " +
							$"from { tableName } with (nolock) " +
							$"where sql_instance = '{ this.SqlInstance }' ";

						using (SqlCommand cmdGetRepoLastSeen = new SqlCommand(sql, connectionRepository))
						{
							Stopwatch t = Stopwatch.StartNew();
							lastSeenInRepo = (await cmdGetRepoLastSeen.ExecuteScalarAsync()).ToString();
							Logger.LogVerbose($"Fetched \"Last Seen\" (\"{lastSeenInRepo}\") from \"{ tableName }\" for \"[{ SqlInstance }]\" in { t.Elapsed.TotalMilliseconds }ms.");
						}
					}
					else if (HasLastUpdated == true && lastUpdatedInRepo == "")
					{
						// The nolock here is safe as nothing is modifying or writing data for specific instance but it does not block other threads modifying their own instances
						sql = $"select convert(varchar(30),isnull(max(date_updated),'1970-01-01'),121) " +
							$"from { tableName } with (nolock) " +
							$"where sql_instance = '{ this.SqlInstance }' ";

						using (SqlCommand cmdGetRepoLastUpdated = new SqlCommand(sql, connectionRepository))
						{
							Stopwatch t = Stopwatch.StartNew();
							lastUpdatedInRepo = (await cmdGetRepoLastUpdated.ExecuteScalarAsync()).ToString();
							Logger.LogVerbose($"Fetched \"Last Updated\" (\"{lastUpdatedInRepo}\") from \"{ tableName }\" for \"[{ SqlInstance }]\" in { t.Elapsed.TotalMilliseconds }ms.");
						}
					}

					// For the header table, we have to pull new headers for each snapshot
					// We are going to build a where clause dynamically
					if (tableName == "dbo.sqlwatch_logger_snapshot_header")
					{
						// If we are doing a full load, we are going to skip the below and default to 1970-01-01 further below:
						var snapshotTimes = new DateTime(1970, 1, 1);
						if (!Config.fullLoad)
						{
							snapshotTimes = await SnapshotTimeForInstance(connectionRepository);
						}

						sql = $@"select * 
								from [dbo].[sqlwatch_logger_snapshot_header] with (readpast) 
								where [snapshot_time] > { snapshotTimes } ";
					}
					// For logger tables excluding the snapshot header, check the last snapshot_time we have in the central respository
					// and only import new records from remote
					else if (tableName.Contains("sqlwatch_logger"))
					{

						// Check if we are running fullload and set the SnapshotTime way in the past if yes to force load all data from the remote:
						string snapshotTime = Config.fullLoad == true ? "1970-01-01" : "";

						if (snapshotTime == "")
						{
							// The nolock here is safe as nothing is modifying or writing data for specific instance but it does not block other threads modifying their own instances
							sql = $"select [snapshot_time]=isnull(convert(varchar(23),max([snapshot_time]),121),'1970-01-01') " +
								$"from { tableName } with (nolock)" +
								$"where sql_instance = '{ this.SqlInstance }'";

							using (SqlCommand cmdGetLastSnapshotTime = new SqlCommand(sql, connectionRepository))
							{
								Stopwatch t = Stopwatch.StartNew();
								snapshotTime = (await cmdGetLastSnapshotTime.ExecuteScalarAsync()).ToString();
								Logger.LogVerbose($"Fetched \"Last Snapshot Time\" (\"{ (snapshotTime == "" ? "1970-01-01" : snapshotTime) }\") from \"{ tableName }\" for \"[{ SqlInstance }]\" in { t.Elapsed.TotalMilliseconds }ms.");
							}
						}

						// If we are not running full load, we can genuinely not have snapshottime if the tables are empty. In which case, again, we have to pull all data:
						sql = $"select * from { tableName } with (readpast) where snapshot_time > '{ (snapshotTime == "" ? "1970-01-01" : snapshotTime) }'";
					}
					// For any other table, we are assuming they are meta tables:
					else
					{
						sql = $"select * from { tableName } with (readpast)";

						// Some tables may have both, the last seen and last updated fields.
						// The last seen field takes precedence over the last udpated.

						if (lastSeenInRepo != "" && HasLastSeen == true)
						{
							sql += $" where date_last_seen > '{ lastSeenInRepo }'";
						}
						else if (lastUpdatedInRepo != "" && HasLastUpdated == true)
						{
							sql += $" where date_updated > '{ lastUpdatedInRepo }'";
						}
					}

					// ------------------------------------------------------------------------------------------------------------------------------
					// BULK COPY
					// ------------------------------------------------------------------------------------------------------------------------------
					int rowsCopied = 0;

					using (SqlCommand cmdGetData = new SqlCommand(sql, connectionRemote))
					{
						cmdGetData.CommandTimeout = Config.BulkCopyTimeout;

						//import data into #t table
						try
						{
							Stopwatch bk1 = Stopwatch.StartNew();
							using (SqlDataReader reader = await cmdGetData.ExecuteReaderAsync())
							{

								if (reader.HasRows == false)
								{
									Logger.LogVerbose($"Nothing to import from \"[{ SqlInstance }].{ tableName }\"");

									if (tableName == "dbo.sqlwatch_logger_snapshot_header")
									{
										Logger.LogWarning($"No new records in the snapshot header from \"{SqlInstance}\".");
										// At this point we want to break importing of any child tables:
										return false;
									}
									else
									{
										return true;
									}
								}

								string PkColumns = primaryKeys;

								sql = $"select top 0 * into [#{ tableName }] from { tableName } with (nolock);";

								if (PkColumns != "")
								{
									sql += $"alter table [#{ tableName }] add primary key ({ PkColumns }); ";
								}

								using (SqlCommand commandRepository = new SqlCommand(sql, connectionRepository))
								{

									try
									{
										Stopwatch t = Stopwatch.StartNew();
										await commandRepository.ExecuteNonQueryAsync();
										Logger.LogVerbose($"Created landing table \"#{ tableName }\" for \"{ SqlInstance }\" in { t.Elapsed.TotalMilliseconds }ms.");
									}
									catch (SqlException e)
									{
										Logger.LogError($"Failed to prepare table for \"[{ SqlInstance }].{ tableName}\"", e.Errors[0].Message);
										return false;
									}
								}

								var options = SqlBulkCopyOptions.KeepIdentity | SqlBulkCopyOptions.TableLock;

								using (SqlBulkCopy sqlBulkCopy = new SqlBulkCopy(connectionRepository, options, null))
								{

									sqlBulkCopy.DestinationTableName = $"[#{ tableName }]";
									sqlBulkCopy.BulkCopyTimeout = Config.BulkCopyTimeout;
									sqlBulkCopy.EnableStreaming = Config.SqlBkEnableStreaming;
									sqlBulkCopy.BatchSize = Config.SqlBkBatchSize;

									try
									{
										await sqlBulkCopy.WriteToServerAsync(reader);

										rowsCopied = SqlBulkCopyExtension.RowsCopiedCount(sqlBulkCopy);

										t1 += bk1.Elapsed.TotalMilliseconds;
										Logger.LogVerbose($"Copied { rowsCopied } { (rowsCopied == 1 ? "row" : "rows") } from \"[{ SqlInstance }].{ tableName }\" to \"{ (tableName == "dbo.sqlwatch_logger_snapshot_header" ? "dbo.sqlwatch_logger_snapshot_header" : $"#{ tableName }") }\" in { bk1.Elapsed.TotalMilliseconds }ms.");
									}
									catch (SqlException e)
									{
										Logger.LogError($"Failed to Bulk Copy data from \"[{ SqlInstance }].{ tableName }\"", e.Errors[0].Message);
										return false;
									}
								}
							}
						}
						catch (SqlException e)
						{
							Logger.LogError($"Failed to populate DataReader with remote Data from \"[{ SqlInstance }].{ tableName }\"", e.Errors[0].Message, sql);
							return false;
						}
					}

					// ------------------------------------------------------------------------------------------------------------------------------
					// MERGE
					// ------------------------------------------------------------------------------------------------------------------------------
					if (rowsCopied > 0) //&& tableName != "dbo.sqlwatch_logger_snapshot_header")
					{
						sql = "";

						if (HasIdentity == true)
						{
							sql += $"\nset identity_insert { tableName } on;";
						}

						string allColumns = AllColumns;

						sql += $";merge { tableName } as target ";

						if (tableName.Contains("sqlwatch_logger") == true && tableName != "dbo.sqlwatch_logger_snapshot_header")
						{
							sql += $@"
								using (
								select s.* from [#{ tableName }] s
								inner join dbo.sqlwatch_logger_snapshot_header h
									on s.[snapshot_time] = h.[snapshot_time]
									and s.[snapshot_type_id] = h.[snapshot_type_id]
									and s.[sql_instance] = h.[sql_instance]) as source";
						}
						else
						{
							sql += $"using [#{ tableName }] as source";
						}

						sql += $@"
							on ({ Joins })
							when not matched
							then insert ({ allColumns })
							values (source.{ allColumns.Replace(",", ",source.") })";

						string updateColumns = UpdateColumns;

						// we would never update existing logger tables
						if (updateColumns != "" && tableName.Contains("sqlwatch_logger") == false)
						{
							sql += $@"
							when matched
							then update set
							{ updateColumns }";
						}

						sql += ";";

						if (HasIdentity == true)
						{
							sql += $"\nset identity_insert { tableName } off;";
						}

						using (SqlCommand cmdMergeTable = new SqlCommand(sql, connectionRepository))
						{
							cmdMergeTable.CommandTimeout = Config.BulkCopyTimeout;

							try
							{
								Stopwatch mg = Stopwatch.StartNew();
								int nRows = await cmdMergeTable.ExecuteNonQueryAsync();
								t2 += mg.Elapsed.TotalMilliseconds;

								Logger.LogVerbose($"Merged { nRows } { (nRows == 1 ? "row" : "rows") } from \"#{ tableName }\" for \"{ SqlInstance }\" in { mg.Elapsed.TotalMilliseconds }ms");
								Logger.LogSuccess($"Imported \"{ tableName }\" from \"{ SqlInstance }\" in { tt.Elapsed.TotalMilliseconds }ms");

								return true;
							}
							catch (SqlException e)
							{
								string message = $"Failed to merge table \"[{ SqlInstance }].{ tableName }\"";
								if (e.Errors[0].Message.Contains("Violation of PRIMARY KEY constraint") == true)
								{
									message += ". Perhaps you should try running a full load to try to resolve the issue.";
								}

								Logger.LogError(message, e.Errors[0].Message, sql);

								//dump # table to physical table to help debugging

								if (Config.dumpOnError == true)
								{
									sql = $"select * into [_DUMP_{ string.Format("{0:yyyyMMddHHmmssfff}", DateTime.Now) }_{ SqlInstance }.{ tableName }] from [#{ tableName }]";
									using (SqlCommand cmdDumpData = new SqlCommand(sql, connectionRepository))
									{
										try
										{
											cmdDumpData.ExecuteNonQuery();
										}
										catch (SqlException x)
										{
											Logger.LogError("Failed to dump data into a table for debugging. This was not expected.", x.Errors[0].Message, sql);
											return false;
										}
									}
								}
								return false;
							}
						}
					}
					else
					{
						return true;
					}
				}
			}
		}

		private async Task<DateTime> SnapshotTimeForInstance(SqlConnection connectionRepository)
		{
			// The nolock here is safe as nothing is modifying or writing data for specific instance but it does not block other threads modifying their own instances
			var sql = @"select 'case ' + char(10) + (
												select 'when [snapshot_type_id] = ' + convert(varchar(10),[snapshot_type_id]) + ' then ''' + convert(varchar(23),max([snapshot_time])) + '''' + char(10)
												from [dbo].[sqlwatch_logger_snapshot_header] with (nolock)
												where sql_instance = @SqlInstance
												group by [snapshot_type_id],[sql_instance]
												for xml path('')
											) + char(10) + ' else '''' end '";

			using (var cmd = new SqlCommand(sql, connectionRepository))
			{
				cmd.Parameters.AddWithValue("@SqlInstance", this.SqlInstance);
				var result = await cmd.ExecuteScalarAsync();
				return DateTime.Parse(result.ToString());
			}
		}

		public async Task<string> GetVersion()
		{
			string sql = "SELECT [sqlwatch_version] FROM [dbo].[vw_sqlwatch_app_version]";
			string version = "";

			using (SqlConnection connetion = new SqlConnection(this.ConnectionString))
			{
				await connetion.OpenAsync();
				using (SqlCommand cmdGetVersion = new SqlCommand(sql, connetion))
				{
					version = (await cmdGetVersion.ExecuteScalarAsync()).ToString();
				}
			}

			this.Vesion = version;
			return version;
		}
		public async Task<bool> IsOnline()
		{
			// Checks if the server is online

			Logger.LogVerbose($"Checking if Central Repository is online");
			try
			{
				using (SqlConnection conn = new SqlConnection(this.ConnectionString))
				{
					await conn.OpenAsync();
					return true;
				}
			}
			catch (SqlException e)
			{
				Logger.LogError($"Unable to open connection to {this.SqlInstance}", e.Errors[0].Message);
				return false;
			}
		}

		public class Table : SqlWatchInstance, IDisposable
		{
			public string TableName { get; set; }

		}

		#region CommandLine

		public bool AddRemoteInstance(string SqlInstance, string SqlDatabase, string Hostname = null, int? SqlPort = null, string SqlUser = null, string SqlPassword = null)
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

			using (SqlConnection conn = new SqlConnection(this.ConnectionString))
			{
				string query = @"insert into [dbo].[sqlwatch_config_sql_instance]([sql_instance]
										,[hostname],[sql_port],[sqlwatch_database_name]
										,[repo_collector_is_active],[sql_user],[sql_secret])
						values(@sql_instance, @hostname, @port, @database, 1, @sql_user, @sql_secret);";

				using (SqlCommand command = new SqlCommand(query, conn))
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

		public bool UpdateRemoteInstance(string SqlInstance, string SqlUser, string SqlPassword)
		{
			string SqlSecret = Tools.Encrypt(SqlPassword);
			using (SqlConnection conn = new SqlConnection(this.ConnectionString))
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

	}
}
