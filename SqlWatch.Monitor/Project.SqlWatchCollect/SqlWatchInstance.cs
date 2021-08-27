using System;
using System.Data.SqlClient;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    public class SqlWatchInstance : IDisposable
    {

		public string SqlInstance { get; set; }
        
		public string SqlDatabase { get; set; }
		
		public string SqlUser { get; set; }
		
		public string SqlSecret { get; set; }
		
		public int ConnectTimeout { get; set; } = 60;
		
		public string Hostname { get; set; } = "";
		
		public string ApplicationName { get; set; }

		public bool IntegratedSecurity { get; set; }

		public string CollectionStatus { get; set; }

		public bool IsInitialised { get; set; }

		public bool IsOnline { get; set; }

		public int OfflineCounts { get; set; }

		public bool IsOffline { get; set; }

		public bool IsActive { get; set; }

		public DateTime LastTimeOnline { get; set; }

		public DateTime LastPollTime { get; set; }

		public string ConnectionString
		{
			get
			{
				SqlConnectionStringBuilder conn = new SqlConnectionStringBuilder
				{
					DataSource = this.Hostname != "" ? this.Hostname : this.SqlInstance,
					InitialCatalog = this.SqlDatabase,
					Pooling = true,
					MinPoolSize = 0,
					MultipleActiveResultSets = true,
					ConnectTimeout = this.ConnectTimeout,
                    ApplicationName = this.ApplicationName,
					IntegratedSecurity = this.IntegratedSecurity,
					UserID = this.SqlUser == "" ? "" : this.SqlUser,
					Password = this.SqlSecret == "" ? "" : Tools.Decrypt(this.SqlSecret)
				};

				return conn.ConnectionString;
			}
		}
        
  //      public class RemoteInstance
		//{
		//	public string SqlInstance { get; set; }
			
		//	public string SqlDatabase { get; set; }
			
		//	public string Hostname { get; set; }
			
		//	public string SqlUser { get; set; }
			
		//	public string SqlSecret { get; set; }

		//}

		void IDisposable.Dispose() { }

	}
}
