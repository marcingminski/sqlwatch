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

namespace SqlWatchImport
{
	
	class Program
    {
		static void Main(string[] args)
        {

			#region prerun config

			Stopwatch sw = Stopwatch.StartNew();


			if (Config.MinThreads != 0)
            {
				ThreadPool.SetMinThreads(Config.MinThreads, Config.MinThreads) ;
            }

			if (Config.MaxThreads != 0)
            {
				ThreadPool.SetMaxThreads(Config.MaxThreads, Config.MaxThreads);
            }

			Trace.Listeners.Clear();

			Tools.RotateLogFile(Config.LogFile);

			TextWriterTraceListener twtl = new TextWriterTraceListener(Config.LogFile);
			twtl.Name = "TextLogger";
			twtl.TraceOutputOptions = TraceOptions.ThreadId | TraceOptions.DateTime;

			if (Config.PrintToConsole == true )
            {
				ConsoleTraceListener ctl = new ConsoleTraceListener(false);
				ctl.TraceOutputOptions = TraceOptions.DateTime;
				Trace.Listeners.Add(ctl);
			}

			if (Config.PrintToLogFile == true)
            {
				Trace.Listeners.Add(twtl);

			}
			Trace.AutoFlush = true;

			var version = Assembly.GetExecutingAssembly().GetName().Version;
			var buildDate = new DateTime(2000, 1, 1).AddDays(version.Build).AddSeconds(version.Revision * 2);
			var displayableVersion = $"{version} ({buildDate})";

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

				bool isOnlineResult = false;
				Task tIsOnline = Task.Run(async () =>
				{
					isOnlineResult = await SqlWatchRepository.IsOnline();
				});

				Task.WaitAll(tIsOnline);

				Stopwatch sdt = Stopwatch.StartNew();

				Task tRemoteTables = Task.Run(() =>
				{
					SqlWatchRepository.GetRemoteTables();
				});

				Task tSnapshotTypes = Task.Run(async () =>
				{
					await SqlWatchRepository.GetTableSnapshoTypes();
				});

				// populate Servers DataTable, SqlAdapters 
				Task tRemoteServers = Task.Run(() =>
				{
					SqlWatchRepository.GetRemoteServers();
				});

				// wait until we have got all the reference data:
				Task.WaitAll(tRemoteServers, tRemoteTables, tSnapshotTypes);

				double t0= sdt.Elapsed.TotalMilliseconds;

				List<Task> tasks = new List<Task>();

				// import remote serveres:
				SqlWatchRepository.RemoteServers().ForEach(delegate (String SqlInstance)
				{
					Task task = Task.Run(async () =>
					{
						await SqlWatchRemote.Import(SqlInstance);
					});
					tasks.Add(task);
				});
				Task.WaitAll(tasks.ToArray());

                Logger.LogMessage("Import completed in " + sw.Elapsed.TotalMilliseconds + "ms");

				Logger.LogVerbose($"Total time spent on populating reference DataTables: { t0 }ms");
				Logger.LogVerbose($"Total time spent on Bulk Copy Full load: { SqlWatchRemote.t1 }ms");
				Logger.LogVerbose($"Total time spent on Merge: { SqlWatchRemote.t2 }ms");
				Logger.LogVerbose($"Total time spent on Bulk Copy Delta load: { SqlWatchRemote.t4 }ms");
				Logger.LogVerbose($"Total time spent on querying Central Repo for the last snapshot: { SqlWatchRemote.t3 }ms");
				Logger.LogVerbose($"Total time spent on eveyrthing else: { (t0+SqlWatchRemote.t1+SqlWatchRemote.t2+SqlWatchRemote.t4+SqlWatchRemote.t3)-sw.Elapsed.TotalMilliseconds }ms ");

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
						   if (options.Add)
						   {

							   SqlWatchRemote.Add(
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
							   SqlWatchRemote.Update(
								   options.RemoteSqlWatchInstance,
								   options.RemoteSqlUser,
								   options.RemoteSqlPassword
								   );
						   }
					   });

                #endregion
            }
        }
    }

}