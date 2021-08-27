#define TRACE

using System;
using System.Configuration;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class Program
    {
        static void Main(string[] args)
        {

            //Initialise basic stuff:
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

            if ((bool.Parse(ConfigurationManager.AppSettings["PrintToConsole"])) == true)
            {
                Trace.Listeners.Add(ctl);
            }

            if ((bool.Parse(ConfigurationManager.AppSettings["PrintToLogFile"])) == true)
            {
                Trace.Listeners.Add(twtl);
            }

            Trace.AutoFlush = true;


            using (Config config = new Config())
            {

                Logger.LogMessage($"{ config.ApplicationName } {config.ApplicationVersion} ({config.ApplicationBuildDate:yyyy-MM-dd HH:mm:ss})");
                Logger.LogMessage($"Copyright { config.ApplicationCopyright }");

                //Start Collection Scheduler.
                //The scheduler is responsible for managing collectors, starting and stoping new collectors for new servers or stopping when things go wrong.
                //The scheduler will invoke new "DataCollector.cs" for each SqlInstance. The DataCollector will then in turn invoke CollectionTimer for each timer
                //defined in the timers table. Each collection snapshot (including metadata) must have a timer otherwise it will not be collected. 
                //Timer then runs on (well...) a timer and invokes "CollectionSnapshot.cs" for each particular snapshot_type or metadata every so often.

                //When scheduler stops collection becuase something goes wrong (say the queue gets full) it will then resume when things go back to normal.
                //when server goes offline, it will also automatically resume collection when the server goes back online with the exception that it will need to be re-initialised (things pushed to tempdb).

                using (CollectionPoller collectionPoller = new CollectionPoller())
                {

                }

                using (CollectionScheduler collectionScheduler = new CollectionScheduler())
                {

                    var mre = new ManualResetEvent(false);

                    Task.Run(async () =>
                    {
                        await collectionScheduler.Start();
                    });

                    mre.WaitOne();

                }
            }

            Logger.LogVerbose("Ending Main");
        }
    }
}