using System;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class SqlBulkCopyGeneric : IDisposable
    {

		public string sql { get; set; }
		public string targetTableName { get; set; }
		public string connectionStringSource { get; set; }
		public string connectionStringTarget { get; set; }
		public int snapshotTypeId { get; set; }
		public DateTime snapshotTimeNew { get; set; }
		public DataTable dataTable { get; set; }

		public async Task<int> BulkCopyDataTableAsync()
        {
			return await Task.Run(async () =>
			{

				var options = SqlBulkCopyOptions.CheckConstraints;

				using (SqlConnection repositoryConnection = new SqlConnection(this.connectionStringTarget))
				{
					await repositoryConnection.OpenAsync();

					using (SqlBulkCopy sqlBulkCopy = new SqlBulkCopy(repositoryConnection, options, null))
					{

						sqlBulkCopy.DestinationTableName = this.targetTableName;
						sqlBulkCopy.BulkCopyTimeout = 60;
						sqlBulkCopy.BatchSize = 4000;

                        try
                        {
							Stopwatch sw = Stopwatch.StartNew();
							await sqlBulkCopy.WriteToServerAsync(dataTable);
							Logger.LogVerbose($"Bulk loaded {this.targetTableName} in { sw.Elapsed.TotalMilliseconds }ms");
							return SqlBulkCopyExtension.RowsCopiedCount(sqlBulkCopy);
						}
                        catch (SqlException e)
                        {
							Logger.LogError(e.Errors[0].Message, e.Server, sql);
							throw;
						}
                    }
				}

			});
		}
		public async Task<int> BulkCopySqlReaderAsync()
		{
			return await Task.Run(async () =>
			{
				using (SqlConnection remoteConnection = new SqlConnection(this.connectionStringSource))
				{
					using (SqlCommand command = new SqlCommand(this.sql, remoteConnection))
					{

						Logger.LogVerbose($"Bulk copying {this.targetTableName}");
						Stopwatch sw = Stopwatch.StartNew();

						await remoteConnection.OpenAsync();

						//var options = SqlBulkCopyOptions.KeepIdentity; | SqlBulkCopyOptions.TableLock;
						var options = SqlBulkCopyOptions.CheckConstraints;

						using (SqlConnection repositoryConnection = new SqlConnection(this.connectionStringTarget))
						{
							await repositoryConnection.OpenAsync();

							using (SqlBulkCopy sqlBulkCopy = new SqlBulkCopy(repositoryConnection, options, null))
							{

								sqlBulkCopy.DestinationTableName = this.targetTableName;
								sqlBulkCopy.BulkCopyTimeout = 60;
								sqlBulkCopy.EnableStreaming = true;
								sqlBulkCopy.BatchSize = 5000;

                                try
                                {
									SqlDataReader reader = await command.ExecuteReaderAsync();
									await sqlBulkCopy.WriteToServerAsync(reader);
									int rows = SqlBulkCopyExtension.RowsCopiedCount(sqlBulkCopy);
									Logger.LogVerbose($"Bulk copied { rows } rows to {this.targetTableName} in { sw.Elapsed.TotalMilliseconds }ms");
									return rows;
								}
                                catch (SqlException e)
                                {
                                    Logger.LogError(e.Errors[0].Message, e.Server, this.sql);
									throw;
								}
                            }
						}
					}
				};

			});
		}

		void IDisposable.Dispose() { }

	}
}