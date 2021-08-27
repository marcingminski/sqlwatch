using System;
using System.Data;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlWatchCollect
{

    class CollectionHeader : SqlWatchInstance, IDisposable
    {
        //Not used as we are creating header from the message payload, however keeping this as it may be useful in the future

        public CollectionHeader(CollectionSnapshot collectionSnapshot)
        {
            SqlDatabase = collectionSnapshot.SqlDatabase;
            SqlInstance = collectionSnapshot.SqlInstance;
            SqlSecret = collectionSnapshot.SqlSecret;
            SqlUser = collectionSnapshot.SqlUser;
            SnapshotTime = collectionSnapshot.SnapshotTime;
        }

        public int SnapshotTypeId { get; set; }

        public DateTime SnapshotTime { get; set; }

        public DateTime SnapshotTimeNew { get; set; }

        public async Task<DateTime> NewCollectionHeader()
        {
            Logger.LogVerbose($"Creating New Collection Header (TypeId:{ SnapshotTypeId }) {SqlInstance}");

            using (Config config = new Config())
            {
                using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
                {
                    using (SqlCommand command = new SqlCommand("dbo.usp_sqlwatch_internal_logger_new_header", repositoryConnection))
                    {

                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.Add("@snapshot_type_id", SqlDbType.TinyInt).Value = SnapshotTypeId;
                        command.Parameters.Add("@sql_instance", SqlDbType.VarChar, 32).Value = SqlInstance;
                        command.Parameters.Add("@snapshot_time", SqlDbType.DateTime2, 0).Value = SnapshotTime;
                        command.Parameters.Add("@snapshot_time_new", SqlDbType.DateTime2, 0).Direction = ParameterDirection.Output;

                        await repositoryConnection.OpenAsync();

                        try
                        {
                            await command.ExecuteNonQueryAsync();
                        }
                        catch (SqlException e)
                        {
                            Logger.LogError(e.Errors[0].Message);
                        }

                        SnapshotTimeNew = Convert.ToDateTime(command.Parameters["@snapshot_time_new"].Value);
                        return SnapshotTimeNew;
                    }
                }
            }
        }

        void IDisposable.Dispose() { }
    }
}