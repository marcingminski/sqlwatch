using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class Dialog : IDisposable
	{
		void IDisposable.Dispose() { }

		public int DialogLifeTime { get; set; } = 3600;

		public async Task EndConversation(Guid ConversationHandle)
        {
			using (Config config = new Config())
			{
				using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
				{
					using (SqlCommand repositoryCommand = new SqlCommand("dbo.usp_sqlwatch_internal_broker_dialog_end", repositoryConnection))
					{
						repositoryCommand.CommandType = CommandType.StoredProcedure;
						repositoryCommand.Parameters.Add("@cid", SqlDbType.UniqueIdentifier).Value = ConversationHandle;

						try
						{
							await repositoryConnection.OpenAsync();
							await repositoryCommand.ExecuteNonQueryAsync();
						}
						catch (SqlException e)
						{
							Logger.LogError(e.Errors[0].Message, e.Server, repositoryCommand.CommandText);
						}
					}
				}
			}
		}

		public async Task<Guid> CreateNewConversationAsync()
		{
			//begin and end convesation are quite expensive but the benefit of having multiple conversations is the ability to use multiple queue readers
			//a single "receive" will only receive from the same conversation group and if we only have single conversation we will only have one group

			Guid ConversationHandle = Guid.Empty;

			using (Config config = new Config())
            {
				using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
				{
					using (SqlCommand repositoryCommand = new SqlCommand("dbo.usp_sqlwatch_internal_broker_dialog_new", repositoryConnection))
					{
						repositoryCommand.CommandType = CommandType.StoredProcedure;
						repositoryCommand.Parameters.Add("@cid", SqlDbType.UniqueIdentifier).Direction = ParameterDirection.Output;
						repositoryCommand.Parameters.Add("@lifetime", SqlDbType.Int).Value = DialogLifeTime;

						try
                        {
							await repositoryConnection.OpenAsync();
							await repositoryCommand.ExecuteNonQueryAsync();

							ConversationHandle = (Guid)repositoryCommand.Parameters["@cid"].Value;
						}
						catch (SqlException e)
                        {
							Logger.LogError(e.Errors[0].Message, e.Server, repositoryCommand.CommandText);
						}

					}
				}
			}

			return ConversationHandle;
		}

	}
}