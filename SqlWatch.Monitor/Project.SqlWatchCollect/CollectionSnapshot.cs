using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Management.Automation;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;
using System.Xml.Serialization;

namespace SqlWatchCollect
{
    class CollectionSnapshot : SqlWatchInstance, IDisposable
    {
        private readonly Collector dataCollector;
        public CollectionSnapshot(Collector dataCollector)
        {
            this.dataCollector = dataCollector;
            SqlDatabase = dataCollector.SqlDatabase;
            SqlInstance = dataCollector.SqlInstance;
            SqlUser = dataCollector.SqlUser;
            SqlSecret = dataCollector.SqlSecret;
        }

        public DateTime SnapshotTime { get; set; }

        public DateTime SnapshotTimeNew { get; set; }

        public Guid ConversationHandle { get; set; }

        void IDisposable.Dispose() { }

        public class SqlInstanceMeta
        {
            public string PhysicalName { get; set; }
            public string SqlVersion { get; set; }

        }

        public string ConnectionStringRepository { get; set; }

        public async Task<double> OffloadSchedulerMonitorData()
        {
            string procedureName = "dbo.usp_sqlwatch_logger_ring_buffer_scheduler_monitor";

            using (SqlConnection remoteConnection = new SqlConnection(dataCollector.ConnectionString))
            {
                using (SqlCommand remoteCommand = new SqlCommand(procedureName, remoteConnection))
                {
                    try 
                    {
                        await remoteConnection.OpenAsync();
                        await remoteCommand.ExecuteNonQueryAsync();
                    }
                    catch (SqlException e)
                    {
                        Logger.LogError(e.Errors[0].Message, e.Server, procedureName);
                        throw;
                    }
                }
            }

            return 0;
        }

        public SqlInstanceMeta GetSqlInstanceMeta()
        {

            SqlInstanceMeta sqlInstanceMeta = new SqlInstanceMeta();

            using (Config config = new Config())
            {
                this.ConnectionStringRepository = config.RepositoryConnectionString;

                using (SqlConnection repositoryConnection = new SqlConnection(this.ConnectionStringRepository))
                {
                    string sql = "select physical_name, sql_version from [dbo].[sqlwatch_meta_server] where servername = @sql_instance";

                    using (SqlCommand repositoryCommand = new SqlCommand(sql, repositoryConnection))
                    {
                        repositoryCommand.CommandType = CommandType.Text;
                        repositoryCommand.Parameters.Add("@sql_instance", SqlDbType.VarChar, 32).Value = SqlInstance;

                        repositoryConnection.OpenAsync();
                        SqlDataReader reader = repositoryCommand.ExecuteReader();

                        if (reader.HasRows)
                        {
                            while (reader.Read())
                            {
                                sqlInstanceMeta = new SqlInstanceMeta
                                {
                                    PhysicalName = reader["physical_name"].ToString(),
                                    SqlVersion = reader["sql_version"].ToString(),
                                };

                            }
                        }

                    }


                }
            }

            return sqlInstanceMeta;
        }

        public async Task<string> GetWmiWin32Volume()
        {
            string xml = string.Empty;

            SqlInstanceMeta sqlInstanceMeta = new SqlInstanceMeta();
            sqlInstanceMeta = GetSqlInstanceMeta();

            string physicalName = sqlInstanceMeta.PhysicalName;
            string sqlVersion = sqlInstanceMeta.SqlVersion;

            if (sqlVersion.Contains("on Windows"))
            {
                xml = await Task.Run(() =>
                {
                    ConnectionOptions options = new ConnectionOptions();
                    options.Impersonation = System.Management.ImpersonationLevel.Impersonate;

                    ManagementPath path = new ManagementPath()
                    {
                        NamespacePath = @"root\cimv2",
                        Server = physicalName
                    };

                    ManagementScope scope = new ManagementScope(path, options);
                    scope.Connect();

                    SelectQuery query = new SelectQuery("Win32_Volume");


                    using (ManagementObjectSearcher searcher = new ManagementObjectSearcher(scope, query))
                    {

                        using (ManagementObjectCollection results = searcher.Get())
                        {

                            xml += "<CollectionSnapshot>\n";
                            xml += "<snapshot_header>\n";
                            xml += $"<row snapshot_time=\"{DateTime.UtcNow.ToString("s", System.Globalization.CultureInfo.InvariantCulture)}\" snapshot_type_id=\"17\" sql_instance=\"{SqlInstance}\" />\n";
                            xml += "</snapshot_header>\n";
                            xml += "<disk_space_usage>\n";

                            foreach (ManagementObject m in results)
                            {
                                if (m["Name"].ToString().StartsWith("\\?") != true | m["Filesystem"].ToString() != "CDFS")
                                {
                                    xml += $"<row volume_name=\"{m["Name"]}\" freespace=\"{m["Freespace"]}\" capacity=\"{m["Capacity"]}\" label=\"{m["Label"]}\" filesystem=\"{m["Filesystem"]}\" blocksize=\"{m["Blocksize"]}\" />\n";
                                }

                            }

                            xml += "</disk_space_usage>\n";
                            xml += "</CollectionSnapshot>\n";

                            return xml;

                        }
                    }
                });
            }
            return xml;
        }

        public async Task<string> GetRemoteMetaDataXml(string metaDataName)
        {
            string xml_message = string.Empty;

            using (SqlConnection remoteConnection = new SqlConnection(dataCollector.ConnectionString))
            {
                using (SqlCommand remoteCommand = new SqlCommand("dbo.usp_sqlwatch_internal_get_data_metadata_snapshot_xml", remoteConnection))
                {
                    remoteCommand.CommandTimeout = 180;
                    remoteCommand.CommandType = CommandType.StoredProcedure;
                    remoteCommand.Parameters.Add("@metadata", SqlDbType.NVarChar, 50).Value = metaDataName;
                    remoteCommand.Parameters.Add("@metadata_xml", SqlDbType.Xml).Direction = ParameterDirection.Output;

                    try
                    {
                        await remoteConnection.OpenAsync();
                        await remoteCommand.ExecuteNonQueryAsync();

                        xml_message = remoteCommand.Parameters["@metadata_xml"].Value.ToString();
                    }
                    catch (SqlException e)
                    {
                        string text = $"{remoteCommand.CommandText} (MetaDataName: {metaDataName})";
                        throw new Exception($"{e.Errors[0].Message} Command: {text}", e);
                    }
                }
            }

            return xml_message;
        }
        
        public async Task<string> GetRemoteSnapshotDataXml(int snapshotTypeId, double timerInterval)
        {
            string xml_message = string.Empty;

            using (SqlConnection remoteConnection = new SqlConnection(dataCollector.ConnectionString))
            {
                using (SqlCommand remoteCommand = new SqlCommand("dbo.usp_sqlwatch_internal_get_data_collection_snapshot_xml", remoteConnection))
                {
                    
                    if (timerInterval <= 1000 * 180)
                    {
                        remoteCommand.CommandTimeout = 60;
                    }
                    else
                    {
                        remoteCommand.CommandTimeout = 180;
                    }

                    remoteCommand.CommandType = CommandType.StoredProcedure;
                    remoteCommand.Parameters.Add("@snapshot_type_id", SqlDbType.SmallInt).Value = snapshotTypeId;
                    remoteCommand.Parameters.Add("@snapshot_data_xml", SqlDbType.Xml).Direction = ParameterDirection.Output;

                    try
                    {
                        await remoteConnection.OpenAsync();
                        await remoteCommand.ExecuteNonQueryAsync();

                        xml_message = remoteCommand.Parameters["@snapshot_data_xml"].Value.ToString();
                    }
                    catch (SqlException e)
                    {
                        string text = $"{remoteCommand.CommandText} (SnapshotTypeId: {snapshotTypeId })";
                        throw new Exception ($"{e.Errors[0].Message} Command: {text}", e);
                    }
                }
            }

            return xml_message;
        }

    }
};