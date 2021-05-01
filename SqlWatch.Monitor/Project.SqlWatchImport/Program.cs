#define TRACE

using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Threading;
using System.Diagnostics;
using System.Reflection;
using CommandLine;
using System.Configuration;
using System.Data;
using System.Linq;

namespace SqlWatchImport
{
	
	class Program
    {
		static void Main(string[] args)
        {

			#region prerun config

			Stopwatch sw = Stopwatch.StartNew();

			Trace.Listeners.Clear();

			Tools.RotateLogFile(Config.LogFile);

            TextWriterTraceListener twtl = new TextWriterTraceListener(Config.LogFile)
            {
                TraceOutputOptions = TraceOptions.ThreadId | TraceOptions.DateTime
            };

            ConsoleTraceListener ctl = new ConsoleTraceListener(false)
            {
                TraceOutputOptions = TraceOptions.DateTime
            };

            if (Config.PrintToConsole == true )
            {
				Trace.Listeners.Add(ctl);
			}

			if (Config.PrintToLogFile == true)
            {
				Trace.Listeners.Add(twtl);

			}

			Trace.AutoFlush = true;

			var version = Assembly.GetExecutingAssembly().GetName().Version;
			var buildDate = new DateTime(2000, 1, 1).AddDays(version.Build).AddSeconds(version.Revision * 2);
			var displayableVersion = $"{version} ({buildDate:yyyy-MM-dd HH:mm:ss})";

			#endregion

			if (args.Length == 0)
			{
				#region importdata

				string	message = $"{ Config.ApplicationTitle } ";
						message += $"\r\n{ Config.tsplaceholder } { Config.ApplicationDescription }";
						message += $"\r\n{ Config.tsplaceholder } { Config.ApplicationCopyright }";
						message += $"\r\n{ Config.tsplaceholder } Version: { displayableVersion }";
				Logger.LogMessage(message);

				//print all config:
				message = "Application Configuration";
				foreach (string s in ConfigurationManager.AppSettings.AllKeys)
				{
					if (s.Contains("Secret") && ConfigurationManager.AppSettings[s] != "") {
						message += $"\r\n{ Config.tsplaceholder } { s } : ***** ";
					} else
                    {
						message += $"\r\n{ Config.tsplaceholder } { s } : { ConfigurationManager.AppSettings[s] } ";
					}
				}

				Logger.LogVerbose(message);

				Stopwatch sdt = Stopwatch.StartNew();
				double t0 = 0;

				using (SqlWatchInstance SqlWatchRepository = new SqlWatchInstance())
                {
					SqlWatchRepository.SqlInstance = Config.centralRepoSqlInstance;
					SqlWatchRepository.SqlDatabase = Config.centralRepoSqlDatabase;
					SqlWatchRepository.SqlUser = Config.centralRepoSqlUser;
					SqlWatchRepository.SqlSecret = Config.centralRepoSqlSecret;

					if (SqlWatchRepository.IsOnline().Result)
                    {
						t0 = sdt.Elapsed.TotalMilliseconds;

						string VersionRepository = SqlWatchRepository.GetVersion().Result;
						Logger.LogVerbose($"Central Repository SQLWATCH Version: \"{VersionRepository}\"");

						List<Task> RemoteImportTasks = new List<Task>();
						List<Task> InitializeTasks = new List<Task>();

						List<SqlWatchInstance.RemoteInstance> RemoteInstances = SqlWatchRepository.GetRemoteInstancesAsync().Result;
						List<SqlWatchInstance.SqlWatchTable> SqlWatchTables = SqlWatchRepository.GetTablesToImportAsync().Result;

						Logger.LogMessage($"Got { RemoteInstances.Count } { (RemoteInstances.Count == 1 ? "instance" : "instances") } to import");
						Logger.LogMessage($"Got { SqlWatchTables.Count } { (SqlWatchTables.Count == 1 ? "table" : "tables") } to import from each instance");

						if (Config.MinThreads > 0)
						{
							ThreadPool.SetMinThreads(Config.MinThreads, Config.MinThreads);
						}
						else if (Config.MinThreads == -1)
                        {
							int minThreads = SqlWatchTables.Count * RemoteInstances.Count;
							ThreadPool.SetMinThreads(minThreads, minThreads);
							Logger.LogVerbose($"Automatically setting MinThreads to { minThreads }");
						}

						if (Config.MaxThreads != 0)
						{
							ThreadPool.SetMaxThreads(Config.MaxThreads, Config.MaxThreads);
						}

						Parallel.ForEach(RemoteInstances, RemoteInstance =>
						{

							Task RemoteImportTask = Task.Run(async () =>
							{
								using (SqlWatchInstance SqlWatchRemote = new SqlWatchInstance())
								{
									SqlWatchRemote.SqlInstance = RemoteInstance.SqlInstance;
									SqlWatchRemote.SqlDatabase = RemoteInstance.SqlDatabase;
									SqlWatchRemote.SqlUser = RemoteInstance.SqlUser;
									SqlWatchRemote.SqlSecret = RemoteInstance.SqlSecret;
									SqlWatchRemote.Hostname = RemoteInstance.Hostname;
									SqlWatchRemote.ConnectionStringRepository = SqlWatchRepository.ConnectionString;

									string VersionRemote = (SqlWatchRemote.GetVersion()).Result;
									Logger.LogVerbose($"\"{RemoteInstance.SqlInstance}\" SQLWATCH Version: \"{VersionRemote}\"");

									if (VersionRepository == VersionRemote)
                                    {
										await SqlWatchRemote.ImportAsync(SqlWatchTables);
									}
									else
                                    {
										Logger.LogError($"Version mismatch. The central repository and the remote instance must have the same version of SQLWATCH installed. " +
											$"The Central Repository is {VersionRepository} and the remote instance \"{RemoteInstance.SqlInstance}\" is {VersionRemote} ");
                                    }
									
								}
							});
							RemoteImportTasks.Add(RemoteImportTask);
						});

						try
						{
							Task results = Task.WhenAll(RemoteImportTasks.Where(t => t != null).ToArray());
							results.Wait();
						}
						catch (Exception e)
						{
							Logger.LogError(e.ToString());
						}
					}
				}

                Logger.LogMessage("Import completed in " + sw.Elapsed.TotalMilliseconds + "ms");

				Console.ResetColor();

				if (Config.hasErrors == true)
				{
					Environment.ExitCode = 1;
				}
				else
				{
					Environment.ExitCode = 0;
				}

                #endregion
            }
            else
            {
                #region interactive
                Parser.Default.ParseArguments<Options>(args)
					   .WithParsed<Options>(options => 
					   {
						   using (SqlWatchInstance SqlWatchRepository = new SqlWatchInstance())
						   {
							   SqlWatchRepository.SqlInstance = Config.centralRepoSqlInstance;
							   SqlWatchRepository.SqlDatabase = Config.centralRepoSqlDatabase;
							   SqlWatchRepository.SqlUser = Config.centralRepoSqlUser;
							   SqlWatchRepository.SqlSecret = Config.centralRepoSqlSecret;

							   if (SqlWatchRepository.IsOnline().Result)
							   {

								   if (options.Add)
								   {
									   SqlWatchRepository.AddRemoteInstance(
										   options.RemoteSqlWatchInstance,
										   options.RemoteSqlWatchDatabase,
										   options.RemoteHostname,
										   options.RemoteSqlPort,
										   options.RemoteSqlUser,
										   options.RemoteSqlPassword
										);

								   }

								   if (options.Update)
								   {
									   SqlWatchRepository.UpdateRemoteInstance(
										   options.RemoteSqlWatchInstance,
										   options.RemoteSqlUser,
										   options.RemoteSqlPassword
										);
								   }


							   }
						   }
			
					   });

				Console.ResetColor();
				#endregion
			}
        }
    }

}