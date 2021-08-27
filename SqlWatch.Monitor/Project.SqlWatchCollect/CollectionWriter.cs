using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class CollectionWriter : IDisposable
    {

        //The idea of the writes was to create an abstraction layer where we can just write to any target, not just SqlServer (i.e. Log Analytics, InfluxDb etc)
        //For now it is only designed to deal with SqlServer targets

        void IDisposable.Dispose() { }

        public CollectionWriter(Guid ConversationHandle)
        {
            this.ConversationHandle = ConversationHandle;
        }

        public string ConnectionString { get; set; }

        public string SqlInstance { get; set; }

        public string ConnectionStringRepository { get; set; }

        public Guid ConversationHandle { get; set; }

        public async Task<bool> WriteMessage(string messageBody, string messageType)
        {
            bool retStatus = false;

            using (Config config = new Config())
            {
                if (config.TargetType == "SqlServer")
                {
                    this.ConnectionStringRepository = config.RepositoryConnectionString;

                    using (SqlConnection repositoryConnection = new SqlConnection(this.ConnectionStringRepository))
                    {
                        string sendCmd = $@"
    DECLARE @xml XML = cast (@message as xml);

    SEND ON CONVERSATION @cid
        MESSAGE TYPE [{messageType}] (@xml);
";

                        using (SqlCommand repositoryCommand = new SqlCommand(sendCmd, repositoryConnection))
                        {
                            repositoryCommand.CommandTimeout = repositoryConnection.ConnectionTimeout;
                            repositoryCommand.Parameters.Add("@cid", SqlDbType.UniqueIdentifier).Value = ConversationHandle;
                            repositoryCommand.Parameters.AddWithValue("@message", messageBody);
                            await repositoryConnection.OpenAsync();

                            try
                            {
                                await repositoryCommand.ExecuteNonQueryAsync();

                                retStatus = true;
                            }
                            catch (SqlException e)
                            {
                                Logger.LogError(e.Errors[0].Message, e.Server, sendCmd);
                                throw new Exception($"{e.Errors[0].Message} Command: {sendCmd}", e);
                            }

                        };
                    }
                }
            }

            return retStatus;
        }
    }
}