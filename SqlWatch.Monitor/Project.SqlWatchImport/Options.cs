using CommandLine;

namespace SqlWatchImport
{
	internal class Options
	{

		//https://github.com/commandlineparser/commandline
		[Option("add", Required = false, HelpText = "Add New Remote Instance to the Central Repository.")]
		public bool Add { get; set; }

		[Option("update", Required = false, HelpText = "Updates Existing Remote Instance User Password.")]
		public bool Update { get; set; }

		[Option('s', "sqlinstance", Required = false, HelpText = "Remote SqlInstance to add. It must match the remote @@SERVERNAME.")]
		public string RemoteSqlWatchInstance { get; set; }

		[Option('d', "database", Required = false, HelpText = "Name of the remote SQLWATCH database.")]
		public string RemoteSqlWatchDatabase { get; set; }

		[Option('h', "hostname", Required = false, HelpText = "Hostname used for connection if different to the remote @@SERVERNAME.")]
		public string RemoteHostname { get; set; }

		[Option('o', "port", Required = false, HelpText = "Remote SQL Port if different to the standard 1433.")]
		public int RemoteSqlPort { get; set; }

		[Option('u', "sqluser", Required = false, HelpText = "SQL user used to connect to the remote instance. Leave empty for Windows authentication.")]
		public string RemoteSqlUser { get; set; }

		[Option('p', "sqlpassword", Required = false, HelpText = "SQL password used to connect to the remote instance. Leave empty for Windows authentication. This will be encrypted and saved in SQLWATCH database.")]
		public string RemoteSqlPassword { get; set; }
	}
}
