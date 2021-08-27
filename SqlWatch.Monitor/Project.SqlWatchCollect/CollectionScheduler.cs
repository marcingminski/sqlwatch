using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class CollectionScheduler : IDisposable
    {

        private readonly IDictionary<string, Collector> dataCollectors = new Dictionary<string, Collector>();

        void IDisposable.Dispose() { }

        private bool isRunning = false;

        private bool IsCheckingOnlineInstances = false;

        private bool IsQueueEnabled;

        System.Timers.Timer schedulerTimer = new System.Timers.Timer();
        System.Timers.Timer onlinePollerTimer = new System.Timers.Timer();
        System.Timers.Timer instanceListTimer = new System.Timers.Timer();
        System.Timers.Timer queuStatusTImer = new System.Timers.Timer();

        class RemoteInstance
        {
            public string SqlInstance { get; set; }
            public string SqlWatchVersion { get; set; }
            public string Status { get; set; }

        }

        public async Task Start()
        {

            Logger.LogVerbose("Starting Collection Scheduler");

            var mre = new ManualResetEvent(false);

            using (Config config = new Config())
            {
              
                var repoConfig = config.SetRepositoryConfiguration();

                await Task.Run(async () => await Task.WhenAll(repoConfig)); ;

                Logger.LogVerbose("Configured Repository");

            };

            Logger.LogVerbose($"Setting up Queue timer");

            queuStatusTImer.Interval = 1000 * 60;
            queuStatusTImer.AutoReset = true;
            queuStatusTImer.Elapsed += QueuStatusTImer_Elapsed;

            QueuStatusTImer_Elapsed(null, null);

            Logger.LogVerbose($"Setting up instance list timer");

            instanceListTimer.Interval = 1000 * 60;
            instanceListTimer.AutoReset = true;
            instanceListTimer.Elapsed += InstanceListTimer_Elapsed;

            InstanceListTimer_Elapsed(null, null);

            Logger.LogVerbose($"Setting up Online Poller timer");

            onlinePollerTimer.Interval = 1000 * 60;
            onlinePollerTimer.AutoReset = true;
            onlinePollerTimer.Elapsed += OnlinePoolerTimer_Elapsed;

            await Task.Run(() =>
            {
                OnlinePoolerTimer_Elapsed(null, null);
            });

            Task.Delay(2000).Wait();

            Logger.LogVerbose($"Setting up Scheduler timer");

            schedulerTimer.Interval = 1000 * 10;
            schedulerTimer.Elapsed += Timer_Elapsed; ;
            schedulerTimer.AutoReset = true;

            await Task.Run(() =>
            {
                Timer_Elapsed(null, null);
            });

            Logger.LogVerbose($"Starting timers");

            queuStatusTImer.Start();
            schedulerTimer.Start();
            instanceListTimer.Start();
            onlinePollerTimer.Start();

            mre.WaitOne();

            Logger.LogVerbose("Ending Collection Scheduler");
        }

        private void QueuStatusTImer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            Task.Run(async () =>
            {
                using (Config config = new Config())
                {

                    if (await config.GetCollectorQueueStatusAsync() == false)
                    {
                        IsQueueEnabled = false;
                        StopAllDataCollectors();
                        Logger.LogVerbose($"Terminating InvokeCollectionScheduler because the receiving queue is disabled and RemoveAllDataColelctors was called.");
                        isRunning = false;
                        return;
                    }
                    else
                    {
                        IsQueueEnabled = true;
                        Logger.LogVerbose($"Receiving queue is enabled");

                        int qSize = await config.GetQueueSizeAsync();

                        if (qSize > config.maxQueueSize)
                        {
                            Logger.LogWarning($"The receiveing queue has over {config.maxQueueSize} items ({qSize})...");
                            Task.Delay(60000).Wait();

                            if (await config.GetQueueSizeAsync() >= qSize)
                            {
                                DoWhenQueueIsFull();
                                Logger.LogVerbose($"Terminating InvokeCollectionScheduler because the receiving queue is full.");
                                isRunning = false;
                                return;
                            }
                        }
                    }

                }
            });
        }

        private void InstanceListTimer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            Task.Run(async () =>
            {
                await GetInstancesToMonitor();
            });
        }

        private void OnlinePoolerTimer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {
            Task.Run(async() =>
            {
                //wait until we have some instances before we start checking
                while (dataCollectors.Count == 0)
                {
                    await Task.Delay(1000);
                }
                await CheckInstanceOnline();
            });
        }

        private void Timer_Elapsed(object sender, System.Timers.ElapsedEventArgs e)
        {

            Logger.LogVerbose("Starting Scheduler Timer_Elapsed");

            Task.WhenAll(InvokeCollectionScheduler());

            Logger.LogVerbose("Finished Scheduler Timer_Elapsed");

        }

        // we should only remove when the instance is physically removed from the table or OFFLINE

        // otherwise we should NEVER NEVER remove collector as we can lose the link between the dictionary and actual objects.
        // we should always maintain a list of all available sqlinstances (collectors) and flip enabled/disabled switch.

        private void RemoveAllDataCollectors()
        {
            Parallel.ForEach(dataCollectors.Values, delegate (Collector c)
            {
                RemoveDataCollector(c);
            });
        }

        private void StopAllDataCollectors()
        {
            Parallel.ForEach(dataCollectors.Values, delegate (Collector c)
            {
                c.StopAndDispose();
                c.isActive = false;
            });
        }

        private void DoWhenInitFails(Collector c)
        {
            Logger.LogWarning($"Removing schedule for { c.SqlInstance } due to initialisation error. The instance will be rescheduled for collection.");

            RemoveDataCollector(c);
        }
        
        private void DoWhenInstanceRemoved(Collector c)
        {
            Logger.LogInformation($"{ c.SqlInstance } has been removed from SQLWATCH.");

            //what if the "DoWhenOffline triggered first? This will crash the application:
            try
            {
                RemoveDataCollector(c);
            }
            catch (Exception e)
            {
                Logger.LogError(e.ToString());
            }
        }
        
        private void DoWhenOffline(Collector c)
        {
            Logger.LogWarning($"{ c.SqlInstance } is offline. The instance will be rescheduled for collection. If the server has been decomissioned please remove it from SQLWATCH.");

            c.IsOnline = false;

            RemoveDataCollector(c);
        }

        private void DoWhenQueueIsFull()
        {
            if (dataCollectors.Count > 0)
            {
                Logger.LogWarning($"The receiveing queue is not clearing quick enough. Stopping collectors until the queue has cleared.");
            }
            else
            {
                Logger.LogWarning($"The receiveing queue is not clearing quick enough.");
            }
            
            StopAllDataCollectors();
        }
        
        private void RemoveDataCollector (Collector c)
        {
            try
            {
                c.isActive = false;
                c.StopAndDispose();
                dataCollectors.Remove(c.SqlInstance);
                Logger.LogVerbose($"Removed collector for { c.SqlInstance }");
            }
            catch (Exception e)
            {
                Logger.LogError($"Failed to remove collector for { c.SqlInstance }. { e.ToString() }");
            }
        }

        public async Task GetInstancesToMonitor()
        {

            Logger.LogVerbose("Checking for new instances to monitor");

            IDictionary<string, Collector> tmpDataCollectors = new Dictionary<string, Collector>();
            tmpDataCollectors.Clear();
            
            List<SqlWatchInstance> AllRemoteInstances = new List<SqlWatchInstance>();

            using (Config config = new Config())
            {
                AllRemoteInstances = await config.GetRemoteInstancesAsync();

                lock (this)
                {
                    Logger.LogVerbose($"Number of instances defined: {AllRemoteInstances.Count()}");

                    AllRemoteInstances.ForEach(delegate (SqlWatchInstance NewRemoteInstance)
                    {

                        if (!dataCollectors.ContainsKey(NewRemoteInstance.SqlInstance))
                        {

                            Collector dataCollector = new Collector(NewRemoteInstance)
                            {
                                ApplicationName = config.ApplicationName,
                                ConnectionStringRepository = config.RepositoryConnectionString,
                                SqlInstanceRepository = config.centralRepoSqlInstance,
                                SqlDatabaseRepository = config.centralRepoSqlDatabase,
                                SqlDatabase = NewRemoteInstance.SqlInstance == config.centralRepoSqlInstance ? NewRemoteInstance.SqlDatabase : "tempdb",
                                SqlUser = NewRemoteInstance.SqlUser,
                                SqlSecret = NewRemoteInstance.SqlSecret,
                                Hostname = NewRemoteInstance.Hostname,
                                IntegratedSecurity = NewRemoteInstance.IntegratedSecurity,
                                isInitialised = NewRemoteInstance.SqlInstance == config.centralRepoSqlInstance ? true : false,
                                IsActive = false,
                                IsInitialised = false,
                                IsOnline = false,
                                OfflineCounts = 0,
                                IsOffline = true
                            };

                            dataCollectors[NewRemoteInstance.SqlInstance] = dataCollector;

                        }

                    });

                    //remove non-existing instances from the scheduler:
                    tmpDataCollectors = dataCollectors;

                    foreach (Collector c in tmpDataCollectors.Values)
                    {
                        if (!AllRemoteInstances.Exists(x => x.SqlInstance == c.SqlInstance))
                        {
                            DoWhenInstanceRemoved(c);
                        }
                    }

                    if (Collector.collectorCounter > dataCollectors.Count())
                    {
                        Logger.LogError($"Number of Collectors objects ({Collector.collectorCounter}) is greater than the number of Instances {dataCollectors.Count()}.");
                        Logger.LogVerbose($"Setting InvokeCollectionScheduler IsRunning to false becuase the number of collectors does not match.");
                        isRunning = false;
                        return;
                    }

                }


            }

        }

        public async Task CheckInstanceOnline()
        {
            Logger.LogVerbose($"Started checking Instances Online");

            if (IsCheckingOnlineInstances == true)
            {
                Logger.LogVerbose($"Already checking for instances online");
                return;
            }
            else
            {
                IsCheckingOnlineInstances = true;

                //if a server goes down we are going to be checking if its come back online every 1 minute.
                //unless we have more servers down, say 10, then we are going to increase the check to 5 minutes so we do not hold up too many threads.
                int instancesOffline = dataCollectors.Values.Select(c => c.IsOnline == false).Count();

                List<Task> onlineCheckTasks = new List<Task>();

                foreach (Collector c in dataCollectors.Values)
                {
                    onlineCheckTasks.Add(Task.Run(async () =>
                    {
                        if (c.NextOnlineCheck <= DateTime.UtcNow)
                        {
                            string offlinesince = c.LastTimeOnline == Convert.ToDateTime("01/01/0001 00:00:00") ? "has never been online" : "";

                            if (offlinesince == "")
                            {
                                offlinesince = $"has been offline since {c.LastTimeOnline}";
                            }

                            if (await c.IsOnlineAsync())
                            {
                                c.IsOnline = true;
                                c.OfflineCounts = 0;
                                c.LastTimeOnline = DateTime.UtcNow;
                                Logger.LogVerbose($"{c.SqlInstance} is online.");
                                c.NextOnlineCheck = DateTime.UtcNow.AddMinutes(1);
                            }
                            else if (c.OfflineCounts <= 5)
                            {
                                c.IsOnline = false;
                                c.OfflineCounts++;
                                c.NextOnlineCheck = DateTime.UtcNow.AddMinutes(1);

                                Logger.LogWarning($"{c.SqlInstance} {offlinesince}.");
                            }
                            else if (instancesOffline > 10)
                            {
                                c.IsOnline = false;
                                c.OfflineCounts++;
                                c.NextOnlineCheck = DateTime.UtcNow.AddMinutes(5);
                                Logger.LogWarning($"{c.SqlInstance} {offlinesince}. Becuase more than 10 servers are currently offline ({instancesOffline}). We are going to keep checking at a reduced rate to free up threads. If you may want to remove them from the dbo.sqlwatch_config_sql_instance or mark as inactive.");
                            }
                        }
                    }));


                }

                await Task.WhenAll(onlineCheckTasks);
            }

            IsCheckingOnlineInstances = false;
            Logger.LogVerbose($"Finished checking Instances Online");

        }

        public async Task InvokeCollectionScheduler()
        {

            if (isRunning == true)
            {
                Logger.LogVerbose($"InvokeCollectionScheduler is already running.");
                return;
            };

            Logger.LogVerbose($"Setting InvokeCollectionScheduler IsRunning to true.");
            isRunning = true;

            Logger.LogVerbose($"Active threads: {Process.GetCurrentProcess().Threads.Count}");

            //IDictionary<string, Collector> tmpDataCollectors = new Dictionary<string, Collector>();
            //tmpDataCollectors.Clear();

            using (Config config = new Config())
            {

                if (await config.IsRepositoryOnlineAsync() == true)
                {
                    if ( IsQueueEnabled == true)
                    {
                        List<Task> collectorTasks = new List<Task>();

                        foreach (Collector c in dataCollectors.Values)
                        //Parallel.ForEach(dataCollectors.Values, delegate (Collector c)
                        {

                            if (c.IsOnline == true)
                            {
                                if (c.IsActive == false || c.IsInitialised == false)
                                {
                                    Logger.LogVerbose($"Activating collection from {c.SqlInstance}");

                                    //fire and forget. We keep handle of these tasks in dataCollectors
                                    _ = Task.Run(async () => await c.Start());

                                }
                                else
                                {
                                    Logger.LogVerbose($"{c.SqlInstance} has active collector. ");
                                }
                            }
                        };

                        if (collectorTasks.Count() > 0)
                        {
                            await Task.WhenAll(collectorTasks);
                        }
                    }
                    else
                    {
                        Logger.LogWarning($"Unable to avtivate collectors becuase the receiving queue is disabled.");
                    }

                }
                else
                {
                    Logger.LogError("Repository is offline");
                    RemoveAllDataCollectors();
                }
            }

            Logger.LogVerbose($"Setting InvokeCollectionScheduler IsRunning to false because we have reached the end of the method.");
            isRunning = false;
        }
    }
}