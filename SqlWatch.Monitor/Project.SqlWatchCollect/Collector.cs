using Microsoft.SqlServer.Management.Smo;
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;

namespace SqlWatchCollect
{
    public class Collector : SqlWatchInstance, IDisposable
    {
        void IDisposable.Dispose() { }

        public static int collectorCounter = 0;

        public Collector(SqlWatchInstance NewRemoteInstance)
        {
            lock (this)
            {
                this.SqlInstance = NewRemoteInstance.SqlInstance;
                this.SqlDatabase = NewRemoteInstance.SqlDatabase;
                this.SqlUser = NewRemoteInstance.SqlUser;
                this.SqlSecret = NewRemoteInstance.SqlSecret;
                this.Hostname = NewRemoteInstance.Hostname;

                collectorCounter++;
                Logger.LogVerbose($"Created new Collector instance for {NewRemoteInstance.SqlInstance}. Total Number of Collector instances created is {collectorCounter}.");

            }
        }

        ~Collector()
        {
            collectorCounter--;
            Logger.LogVerbose($"Collector for {SqlInstance} destroyed");
        }

        private readonly IDictionary<Guid, CollectionTimer> collectionTimers = new Dictionary<Guid, CollectionTimer>();

        public DateTime NextOnlineCheck { get; set;  } = Convert.ToDateTime("1970-01-01");

        public string ConnectionStringRepository { get; set; }

        public string SqlInstanceRepository { get; set; }

        public string SqlDatabaseRepository { get; set; }

        public int Id { get; set; }

        public bool isInitialised { get; set; } = false;

        public bool isInitialising { get; set; } = false;

        public bool isActive { get; set; } = false;


        private System.Timers.Timer ringBufferTimer; //A2719CB0-D529-46D6-8EFE-44B44676B54B


        private System.Timers.Timer collectionTimerScheduler;


        private bool ringBufferTimerRunning = false;

        public class TimerData
        {
            public Guid TimerId { get; set; }

            public int TimerInterval { get; set; }

            public string TimerActiveDays { get; set; }

            public string TimerActiveHours { get; set; }

            public DateTime TimerActiveFrom { get; set; }

            public DateTime TimerActiveTo { get; set; }

        }

        public class AutoTimer : System.Timers.Timer
        {
            public readonly string name;

            public AutoTimer(Guid timerId)
            {
                this.name = timerId.ToString().Replace("-","") + "Timer";
            }
        }

        public class SnapshotsList
        {
            public readonly string name;

            public SnapshotsList(string name)
            {
                this.name = name;
            }
        }

        private bool _disposed = false;
        
        private SafeHandle _safeHandle = new SafeFileHandle(IntPtr.Zero, true);

        public class CollectorStatus
        {
            public string SqlWatchInstance { get; set; }

            public bool isInitialised { get; set; }

            public bool isInitialising { get; set; }

            public bool isRunning { get; set; }
        }

        public void Dispose() => Dispose(true);

        // Protected implementation of Dispose pattern.
        protected virtual void Dispose(bool disposing)
        {
            if (_disposed)
            {
                return;
            }

            if (disposing)
            {
                // Dispose managed state (managed objects).
                _safeHandle?.Dispose();
            }

            _disposed = true;
        }

        public async Task<CollectorStatus> GetCollectorStatus()
        {

            CollectorStatus collectorStatus = new CollectorStatus();

            using (SqlConnection remoteConnection = new SqlConnection(this.ConnectionString))
            {
                string sqlCmd = "select * from dbo.SqlWatchCollector";

                using (SqlCommand remoteCommand = new SqlCommand(sqlCmd, remoteConnection))
                {
                    remoteCommand.CommandType = CommandType.Text;

                    await remoteConnection.OpenAsync();
                    SqlDataReader reader = await remoteCommand.ExecuteReaderAsync();

                    if (reader.HasRows)
                    {
                        while (reader.Read())
                        {
                            collectorStatus = new CollectorStatus
                            {
                                SqlWatchInstance = reader["sql_instance"].ToString(),
                                isInitialised = Convert.ToBoolean(reader["is_initialised"]),
                                isInitialising = Convert.ToBoolean(reader["is_initialising"]),
                                isRunning = Convert.ToBoolean(reader["is_collecting"])

                            };
                        }
                    }
                }
            }

            return collectorStatus;
        }

        public async Task SetCollectorStatus()
        {

            CollectorStatus collectorStatus = new CollectorStatus();

            using (SqlConnection remoteConnection = new SqlConnection(this.ConnectionString))
            {
                string sqlCmd = @"update dbo.SqlWatchCollector 
                            set is_initialised = @is_initialised,
                                is_initialising = @is_initialising,
                                is_collecting = @is_collecting
                            @where sql_instance = @sql_instance";

                using (SqlCommand remoteCommand = new SqlCommand(sqlCmd, remoteConnection))
                {
                    remoteCommand.CommandType = CommandType.Text;
                    remoteCommand.Parameters.Add("@sql_instance", SqlDbType.VarChar, 32).Value = this.SqlInstance;
                    remoteCommand.Parameters.Add("@is_initialised", SqlDbType.Bit).Value = collectorStatus.isInitialised;
                    remoteCommand.Parameters.Add("@is_initialising", SqlDbType.Bit).Value = collectorStatus.isInitialising;
                    remoteCommand.Parameters.Add("@is_collecting", SqlDbType.Bit).Value = collectorStatus.isRunning;

                    try
                    {
                        await remoteConnection.OpenAsync();
                        await remoteCommand.ExecuteNonQueryAsync();
                    }
                    catch (SqlException e)
                    {
                        Logger.LogError(e.Errors[0].Message, e.Server);
                    }

                }
            }
        }

        public async Task Start()
        {

            await Task.Run(async () =>
            {

                var mre = new ManualResetEvent(false);

                while (this.IsInitialised == false)
                {
                    if (this.isInitialising == false)
                    {
                        this.IsInitialised = await Initialise();
                    }
                    await Task.Delay(5000);
                }

                if (this.isActive)
                {
                    Logger.LogVerbose($"The collector for { this.SqlInstance } is already running.");
                    return;
                }

                this.isActive = true;

                Logger.LogInformation($"Starting new collector for { this.SqlInstance }");

                //define static timers for the application use
                ringBufferTimer = new System.Timers.Timer();
                ringBufferTimer.Interval = 1000 * 60;
                ringBufferTimer.AutoReset = true;
                ringBufferTimer.Elapsed += RingBuffer_Elapsed;
                ringBufferTimer.Enabled = false;

                collectionTimerScheduler = new System.Timers.Timer();
                collectionTimerScheduler.Interval = 1000 * 60;
                collectionTimerScheduler.AutoReset = false;
                collectionTimerScheduler.Elapsed += CollectionTimerScheduler_Elapsed; ;
                collectionTimerScheduler.Enabled = false;

                //run now:
                RingBuffer_Elapsed(null, null);
                ringBufferTimer.Start();

                CollectionTimerScheduler_Elapsed(null, null);
                collectionTimerScheduler.Start();

                mre.WaitOne();

                Logger.LogWarning($"Collector has ended for {this.SqlInstance}");
            });

            return;
        }

        //analogically to the collectionScheduler, we should never remove timers only flip enabled/disabled so we always maintai a link between the dictionary and the object

        private void DoWhenTimerRemoved(CollectionTimer t)
        {
            Logger.LogWarning($"Timer { t.TimerId } for { SqlInstance } has been removed.");
            t.StopAndDispose();
            collectionTimers.Remove(t.TimerId);
        }
        
        private void DoWhenTimerChanged(CollectionTimer t)
        {
            Logger.LogWarning($"Timer { t.TimerId } for { SqlInstance } has changed. Resetting timer.");
            t.StopAndDispose();
            collectionTimers.Remove(t.TimerId);
        }

        private async Task CheckRemovedTimers()
        {
            List<TimerData> AllTimers = new List<TimerData>();

            AllTimers = await GetTimersAsync();

            await Task.Run(() =>
            {
                //dispose timers that have been removed or changed at source:
                foreach (CollectionTimer t in collectionTimers.Values)
                {

                    if (!(AllTimers.Exists(x => x.TimerId == t.TimerId)))
                    {
                        DoWhenTimerRemoved(t);
                    }

                    AllTimers.ForEach(delegate (TimerData tx)
                    {
                        if (tx.TimerId == t.TimerId)
                        {
                            if (tx.TimerActiveDays != t.TimerActiveDays)
                            {
                                DoWhenTimerChanged(t);
                            }

                            if (tx.TimerActiveHours != t.TimerActiveHours)
                            {
                                DoWhenTimerChanged(t);
                            }

                            if (tx.TimerActiveFrom != t.TimerActiveFrom)
                            {
                                DoWhenTimerChanged(t);
                            }

                            if (tx.TimerActiveTo != t.TimerActiveTo)
                            {
                                DoWhenTimerChanged(t);
                            }

                            if (tx.TimerInterval * 1000 != t.TimerInterval)
                            {
                                DoWhenTimerChanged(t);
                            }
                        }
                    });
                }
            });
        } 

        private async Task AddNewTimers()
        {
            List<TimerData> AllTimers = new List<TimerData>();

            AllTimers = await GetTimersAsync();

            Logger.LogVerbose($"Number of timers defined per instance {this.SqlInstance}: {AllTimers.Count()}");

            Logger.LogVerbose($"Number of Running timers: {CollectionTimer.timerCounter }. Number of total timers: {AllTimers.Count() * Collector.collectorCounter}");


            //now create timers based on the timer definition in [dbo].[sqlwatch_config_timer]
            AllTimers.ForEach(delegate (TimerData NewDynamicTimer)
            {

                //add new timers:
                if (!collectionTimers.ContainsKey(NewDynamicTimer.TimerId))
                {

                    Logger.LogVerbose($"Timer {NewDynamicTimer.TimerId} not in collection for {this.SqlInstance}");

                    CollectionTimer collectionTimer = new CollectionTimer(this)
                    {
                        TimerId = NewDynamicTimer.TimerId,
                        TimerInterval = NewDynamicTimer.TimerInterval * 1000,
                        TimerSnapshots = GetSnapshotIdsForTimerAsync(NewDynamicTimer.TimerId).Result,
                        TimerActiveDays = NewDynamicTimer.TimerActiveDays,
                        TimerActiveHours = NewDynamicTimer.TimerActiveHours,
                        TimerActiveFrom = NewDynamicTimer.TimerActiveFrom,
                        TimerActiveTo = NewDynamicTimer.TimerActiveTo
                    };

                    collectionTimers[NewDynamicTimer.TimerId] = collectionTimer;

                    //total number of timers is number of defined timers x number o instances:
                    if (CollectionTimer.timerCounter > AllTimers.Count() * Collector.collectorCounter)
                    {
                        Logger.LogError($"Number of running Timers ({CollectionTimer.timerCounter}) is greater than the number of timers defined ({AllTimers.Count() * Collector.collectorCounter}).");
                        collectionTimer.Dispose();
                        return;
                    }
                    else
                    {
                        _ = Task.Run(async () => await collectionTimer.Start());
                    }
                }

            });
        }

        private void CollectionTimerScheduler_Elapsed(object sender, ElapsedEventArgs e)
        {
            Logger.LogVerbose($"Checking for new timers ({ SqlInstance })");

            Task.Run(async () =>
            {
                await CheckRemovedTimers().ContinueWith(
                    t=> AddNewTimers()
                    );
            });

            collectionTimerScheduler.Start();

        }

        public async Task<List<TimerData>> GetTimersAsync()
        {
            List<TimerData> ListTimerData = new List<TimerData>();

            using (Config config = new Config())
            {
                using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
                {
                    string sql = @"select [timer_id], [timer_seconds], timer_active_days, timer_active_hours_utc, timer_active_from_date_utc, timer_active_to_date_utc
                            from [dbo].[sqlwatch_config_timer] (nolock)
                            where timer_type = 'C'
                            and [timer_seconds] is not null
                            and timer_active_days is not null
                            and timer_active_hours_utc is not null
                            and timer_active_from_date_utc is not null
                            and timer_active_to_date_utc is not null
                            and timer_enabled = 1
                            and getutcdate() between timer_active_from_date_utc and timer_active_to_date_utc
                            order by timer_seconds asc";

                    using (SqlCommand repositoryCommand = new SqlCommand(sql, repositoryConnection))
                    {
                        repositoryCommand.CommandType = CommandType.Text;

                        await repositoryConnection.OpenAsync();
                        SqlDataReader reader = await repositoryCommand.ExecuteReaderAsync();

                        if (reader.HasRows)
                        {
                            while (reader.Read())
                            {
                                TimerData TimerData = new TimerData
                                {
                                    TimerId = Guid.Parse(reader["timer_id"].ToString()),
                                    TimerInterval = Convert.ToInt32(reader["timer_seconds"]),
                                    TimerActiveDays = Convert.ToString(reader["timer_active_days"]),
                                    TimerActiveHours = Convert.ToString(reader["timer_active_hours_utc"]),
                                    TimerActiveFrom = Convert.ToDateTime(reader["timer_active_from_date_utc"]),
                                    TimerActiveTo = Convert.ToDateTime(reader["timer_active_to_date_utc"])
                                };

                                ListTimerData.Add(TimerData);
                            }
                        }
                    }
                }
            }

            return ListTimerData;
        }

        public async Task<List<int>> GetSnapshotIdsForTimerAsync(Guid timerId)
        {
            List<int> SnapshotIds = new List<int>();

            using (Config config = new Config())
            {
                using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
                {
                    string sql = @"select snapshot_type_id 
                            from dbo.sqlwatch_config_snapshot_type (nolock)
                            where timer_id = @timerid
                            and [collect] = 1
                            order by snapshot_type_id asc;";

                    using (SqlCommand repositoryCommand = new SqlCommand(sql, repositoryConnection))
                    {
                        repositoryCommand.CommandType = CommandType.Text;
                        repositoryCommand.Parameters.Add("@timerid", SqlDbType.UniqueIdentifier).Value = timerId;

                        await repositoryConnection.OpenAsync();
                        SqlDataReader reader = await repositoryCommand.ExecuteReaderAsync();

                        if (reader.HasRows)
                        {
                            while (reader.Read())
                            {
                                SnapshotIds.Add(Convert.ToInt32(reader["snapshot_type_id"]));
                            }
                        }
                    }
                }
            }

            return SnapshotIds;
        }

        private void RingBuffer_Elapsed(object sender, ElapsedEventArgs ae)
        {
            //string timerId = "A2719CB0-D529-46D6-8EFE-44B44676B54B";

            if (ringBufferTimerRunning == true)
            {
                return;
            }

            Logger.LogVerbose($"Offloading ring buffer data on { SqlInstance } to local table");

            ringBufferTimerRunning = true;

            Stopwatch sw = Stopwatch.StartNew();

            Task.WhenAll(
                    Task.Run(async () =>
                    {

                        using (CollectionSnapshot CollectionSnapshot = new CollectionSnapshot(this))
                        {
                            try
                            {
                                await Task.WhenAll(CollectionSnapshot.OffloadSchedulerMonitorData());

                            }
                            catch (Exception e)
                            {
                                Logger.LogError(e.ToString());
                            }
                        }
                    })
                );

            sw.Stop();

            ringBufferTimerRunning = false;

            ringBufferTimer.Start();
        }

        public async Task<bool> IsOnlineAsync()
        {

            try
            {
                using (SqlConnection conn = new SqlConnection(this.ConnectionString))
                {

                    await conn.OpenAsync();
                    Logger.LogVerbose($"Server { this.SqlInstance } is online.");
                    return true;

                }
            }
            catch
            {
                Logger.LogVerbose($"Server {this.SqlInstance} is offline.");
                return false;

            }
        }

        public void StopAndDispose()
        {

            try
            {

                this.isActive = false;

                if (isInitialised)
                {
                    ringBufferTimer.Stop();
                    ringBufferTimer.Dispose();

                    collectionTimerScheduler.Stop();
                    collectionTimerScheduler.Dispose();
                }

            }
            catch (NullReferenceException)
            {
                Logger.LogVerbose("The instance has not yet been initialised");
            }
            catch (Exception e)
            {
                Logger.LogError(e.ToString());
            }
            finally
            {
                foreach (CollectionTimer t in collectionTimers.Values)
                {
                    t.StopAndDispose();
                }

                isActive = false;

                Logger.LogWarning($"Stopped Data Collector for { this.SqlInstance }");

                Dispose();
            }
        
        }
        
        public async Task<bool> Initialise()
        {

            this.isInitialising = true;

            return await Task.Run(async() =>
            {

                //Only push objects to remote instances.

                if (this.SqlDatabase == "tempdb")
                {

                    try
                    {

                        Logger.LogInformation($"Initialising Collector for { this.SqlInstance }");

                        //    string sqlCmd = @"if object_id('dbo.sqlwatch_poller_status') is null
                        //begin
                        //    create table dbo.sqlwatch_poller_status (
                        //        [sql_instance] varchar(32),
                        //        [sqlwatch_version] varchar(255),
                        //        [last_init] datetime2(0)
                        //    );

                        //    insert into dbo.sqlwatch_poller_status(sql_instance, [sqlwatch_version], [last_init])
                        //    values (@sql_instance, @sqlwatch_version, null);
                        //end;";

                        //    string sqlWatchVersion = string.Empty;

                        //    using (Config config = new Config())
                        //    {
                        //        sqlWatchVersion = await config.GetSqlWatchVersion();
                        //    }

                        //    using (SqlConnection remoteConnection = new SqlConnection(this.ConnectionString))
                        //    {
                        //        using (SqlCommand remoteCommand = new SqlCommand(sqlCmd, remoteConnection))
                        //        {

                        //            remoteCommand.CommandType = CommandType.Text;
                        //            remoteCommand.Parameters.Add("@sql_instance", SqlDbType.VarChar, 32).Value = this.SqlInstance;
                        //            remoteCommand.Parameters.Add("@sqlwatch_version", SqlDbType.VarChar, 255).Value = sqlWatchVersion; 

                        //            try
                        //            {
                        //                await remoteConnection.OpenAsync();
                        //                await remoteCommand.ExecuteNonQueryAsync();
                        //            }
                        //            catch (SqlException e)
                        //            {
                        //                Logger.LogError(e.Errors[0].Message, e.Server, sqlCmd);
                        //            }
                        //        }
                        //    }


                        string[] functions = {
                                "dbo.ufn_sqlwatch_get_product_version",
                                "dbo.ufn_sqlwatch_get_sql_version",
                                "dbo.ufn_sqlwatch_get_xes_timestamp",
                                "dbo.ufn_sqlwatch_convert_local_to_utctime",
                                "dbo.ufn_sqlwatch_get_sql_statement"
                            };

                        //TO DO TODO remove references to dbo.sqlwatch_config_exclude_wait_stats 
                        //in get_snapshot_data so this table does not need pushing
                        string[] configtables = {
                                "dbo.sqlwatch_config_exclude_wait_stats",
                                "dbo.sqlwatch_config_performance_counters",
                            };

                        string[] stagetables = {
                                "dbo.sqlwatch_stage_ring_buffer",
                                "dbo.sqlwatch_stage_xes_exec_count"
                            };

                        string[] procedures = {
                                "dbo.usp_sqlwatch_internal_create_xes",
                                "dbo.usp_sqlwatch_internal_get_data_collection_snapshot_xml",
                                "dbo.usp_sqlwatch_internal_get_data_metadata_snapshot_xml",
                                "dbo.usp_sqlwatch_internal_get_data_xes",
                                "dbo.usp_sqlwatch_internal_foreachsqlwatchdb",
                                "dbo.usp_sqlwatch_logger_ring_buffer_scheduler_monitor"
                            };

                        string[] views = {
                                "dbo.vw_sqlwatch_sys_databases",
                                "dbo.vw_sqlwatch_sys_configurations"
                            };


                        Logger.LogVerbose($"Initialising config tables on {this.SqlInstance}");

                        bool r1 = await PushObject("table", configtables);

                        if (r1)
                        {
                            Logger.LogVerbose($"Initialising stage tables on {this.SqlInstance}");
                            bool r2 = await PushObject("table", stagetables);

                            if (r2)
                            {
                                Logger.LogVerbose($"Initialising functions on {this.SqlInstance}");
                                bool r3 = await PushObject("function", functions);

                                if (r3)
                                {
                                    Logger.LogVerbose($"Initialising views on {this.SqlInstance}");
                                    bool r4 = await PushObject("view", views);

                                    if (r4)
                                    {
                                        Logger.LogVerbose($"Initialising procedures on {this.SqlInstance}");
                                        bool r5 = await PushObject("procedure", procedures);

                                        if (r5)
                                        {
                                            Logger.LogVerbose($"Pushing config data to {this.SqlInstance}");
                                            bool r6 = await PushTableData(configtables);

                                            if (r6)
                                            {

                                                Logger.LogVerbose($"Pushing stage data to {this.SqlInstance}");
                                                bool r7 = await PushTableData(stagetables);

                                                if (r7)
                                                {
                                                    Logger.LogVerbose($"Initialising XES on {this.SqlInstance}");
                                                    bool xes = await CreateXes();

                                                    if (xes)
                                                    {
                                                        Logger.LogInformation($"Getting Metadata from { this.SqlInstance }");

                                                        bool mData = await GetMetaDataInit();

                                                        if (mData)
                                                        {
                                                            this.isInitialised = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    }
                    catch (Exception e)
                    {
                        Logger.LogError(e.ToString());
                        this.isInitialised = false;
                        throw new Exception();
                    }
                }
                else
                {
                    this.isInitialised = true;
                }

                Logger.LogVerbose($"Initialised { this.SqlInstance }");
                this.isInitialising = false;
                return this.isInitialised;
            });

        }

        public async Task<bool> GetMetaDataInit()
        {
            bool retStatus = false;

            using (Dialog Dialog = new Dialog())
            {
                //metadata has to go in sequence so we are using single conversation for the whole batch:
                Guid ConversationHandle = await Dialog.CreateNewConversationAsync();

                using (CollectionSnapshot CollectionSnapshot = new CollectionSnapshot(this))
                {

                    //minimum metadata required for performance collector to work.
                    //remaining metadata will be collecting ruing runtime

                    try
                    {
                        await Task.WhenAll(
                                Task.Run(async () =>
                                {
                                    foreach (string m in new[] {
                                        "meta_server"
                                        , "sys_databases"
                                        , "sys_master_files"
                                        , "sys_jobs"
                                        , "dm_os_memory_clerks"
                                        , "dm_os_wait_stats"
                                        , "dm_os_performance_counters" })
                                    {
                                        string xml_message = string.Empty;

                                        Logger.LogVerbose($"Getting {m} from {SqlInstance}");

                                        xml_message = await CollectionSnapshot.GetRemoteMetaDataXml(m);

                                        using (CollectionWriter collectionWriter = new CollectionWriter(ConversationHandle))
                                        {
                                            await collectionWriter.WriteMessage(xml_message, "mtype_sqlwatch_meta");
                                        }

                                    }
                                })
                            );

                        retStatus = true;
                    }
                    catch (Exception e)
                    {
                        Logger.LogError(e.Message.ToString());
                        retStatus = false;
                        throw new Exception(e.Message, e);
                    }
                }
            }

            return retStatus;
        }
        
        public async Task<bool> PushTableData(string[] tables)
        {
            bool retStatus = false;

            foreach (string table in tables)
            {
                string sql = "";

                try
                {
                    Logger.LogVerbose($"Pushing data to {table} on {SqlInstance}");

                    if (table.StartsWith("dbo.sqlwatch_config"))
                    {
                        using (SqlBulkCopyGeneric SqlBulkCopyGeneric = new SqlBulkCopyGeneric())
                        {
                            sql = $@"select * from { table }";
                            SqlBulkCopyGeneric.sql = sql;
                            SqlBulkCopyGeneric.targetTableName = table;
                            SqlBulkCopyGeneric.connectionStringSource = this.ConnectionStringRepository;
                            SqlBulkCopyGeneric.connectionStringTarget = this.ConnectionString;
                            await SqlBulkCopyGeneric.BulkCopySqlReaderAsync();

                        }
                    } else if (table.StartsWith("dbo.sqlwatch_meta"))
                    {
                        using (SqlBulkCopyGeneric SqlBulkCopyGeneric = new SqlBulkCopyGeneric())
                        {
                            sql = $@"select * from { table} where sql_instance = '{ this.SqlInstance }'";
                            SqlBulkCopyGeneric.sql = sql;
                            SqlBulkCopyGeneric.targetTableName = table;
                            SqlBulkCopyGeneric.connectionStringSource = this.ConnectionStringRepository;
                            SqlBulkCopyGeneric.connectionStringTarget = this.ConnectionString;
                            await SqlBulkCopyGeneric.BulkCopySqlReaderAsync();

                        }
                    }

                    retStatus = true;
                }
                catch (SqlException e)
                {
                    Logger.LogError(e.Errors[0].Message, e.Server, sql);
                    retStatus = false;
                    throw;
                }
            }

            return retStatus;
        }

        public async Task<bool> PushObject (string type, string[] objects)
        {
            bool retVal = false;

            using (Config config = new Config())
            {
                using (SqlConnection repositoryConnection = new SqlConnection(config.RepositoryConnectionString))
                {
                    Server sqlServerRemote = new Server();
                    Server sqlServerRepository = new Server();

                    try
                    {
                        sqlServerRepository.ConnectionContext.ServerInstance = config.centralRepoSqlInstance;
                        sqlServerRepository.ConnectionContext.ApplicationName = this.ApplicationName;

                    }
                    catch (Exception e)
                    {
                        Logger.LogError(e.ToString());
                        throw;
                    }

                    try
                    {
                        sqlServerRemote.ConnectionContext.ServerInstance = this.Hostname != "" ? this.Hostname : this.SqlInstance;
                        sqlServerRemote.ConnectionContext.ApplicationName = this.ApplicationName;
                        
                        if (this.IntegratedSecurity == false)
                        {
                            sqlServerRemote.ConnectionContext.LoginSecure = false;
                            sqlServerRemote.ConnectionContext.Password = Tools.Decrypt(this.SqlSecret);
                            sqlServerRemote.ConnectionContext.Login = this.SqlUser;
                        }
                        else
                        {
                            if (this.SqlUser != "") 
                            {
                                sqlServerRemote.ConnectionContext.LoginSecure = true;
                                sqlServerRemote.ConnectionContext.ConnectAsUserName = this.SqlUser;
                                sqlServerRemote.ConnectionContext.ConnectAsUserPassword = Tools.Decrypt(this.SqlSecret);
                            }
                        }

                    }
                    catch (Exception e)
                    {
                        Logger.LogError(e.ToString());
                        throw;
                    }


                    Database sqlDatabaseRepository = new Database();
                    Database sqlDatabaseRemote = new Database();

                    sqlDatabaseRepository = sqlServerRepository.Databases[config.centralRepoSqlDatabase];
                    sqlDatabaseRemote = sqlServerRemote.Databases[(this.SqlDatabase)];

                    ScriptingOptions options = new ScriptingOptions();
                    options.AllowSystemObjects = false;
                    options.WithDependencies = false;
                    options.NoCommandTerminator = true;

                    foreach (string o in objects){

                        Logger.LogVerbose($"Pushing { o } to { SqlInstance } ");

                        StringBuilder sb = new StringBuilder();
                        StringCollection collection = new StringCollection();
                        bool existsInRemote = false;

                        switch (type)
                        {
                            case "function":
                                foreach (UserDefinedFunction sqlFunction in sqlDatabaseRepository.UserDefinedFunctions.Cast<Microsoft.SqlServer.Management.Smo.UserDefinedFunction>().Where(sqlFunction => sqlFunction.Schema + '.' + sqlFunction.Name == o))
                                {
                                    collection = sqlFunction.Script(options);

                                    if (sqlDatabaseRemote.UserDefinedFunctions.Contains(sqlFunction.Name))
                                    {
                                        existsInRemote = true;
                                    }
                                }
                                break;

                            case "view":
                                foreach (View sqlView in sqlDatabaseRepository.Views.Cast<Microsoft.SqlServer.Management.Smo.View>().Where(sqlView => sqlView.Schema + '.' + sqlView.Name == o))
                                {
                                    collection = sqlView.Script(options);

                                    if (sqlDatabaseRemote.Views.Contains(sqlView.Name))
                                    {
                                        existsInRemote = true;
                                    }
                                }
                                break;

                            case "procedure":
                                foreach (StoredProcedure sqlProcedure in sqlDatabaseRepository.StoredProcedures.Cast<Microsoft.SqlServer.Management.Smo.StoredProcedure>().Where(sqlProcedure => sqlProcedure.Schema + '.' + sqlProcedure.Name == o))
                                {
                                    collection = sqlProcedure.Script(options);

                                    if (sqlDatabaseRemote.StoredProcedures.Contains(sqlProcedure.Name))
                                    {
                                        existsInRemote = true;
                                    }
                                }
                                break;

                            case "table":
                                foreach (Table sqlTable in sqlDatabaseRepository.Tables.Cast<Microsoft.SqlServer.Management.Smo.Table>().Where(sqlTable => sqlTable.Schema + '.' + sqlTable.Name == o))
                                {
                                    options.ClusteredIndexes = true;
                                    options.Default = true;
                                    options.DriAll = false;
                                    options.Indexes = true;
                                    options.IncludeHeaders = false;
                                    options.IncludeIfNotExists = false;

                                    if (sqlDatabaseRemote.Tables.Contains(sqlTable.Name))
                                    {
                                        sb.Append($"drop table { o };");
                                    }

                                    collection = sqlTable.Script(options);
                                }
                                break;

                        }

                        foreach (string s in collection)
                        {
                            if (s != "SET ANSI_NULLS ON" && s != "SET QUOTED_IDENTIFIER ON")
                            {
                                sb.Append(s);
                                sb.Append(Environment.NewLine);
                            }
                        }

                        sb.Replace("with schemabinding", "");
                        sb.Replace("DATA_COMPRESSION = PAGE", "DATA_COMPRESSION = NONE");
                        sb.Replace("DATA_COMPRESSION = ROW", "DATA_COMPRESSION = NONE");

                        switch (type)
                        {
                            case "function":
                                if (existsInRemote == true)
                                {
                                    sb.Replace("CREATE FUNCTION", "ALTER FUNCTION");
                                }
                                break;

                            case "view":
                                if (existsInRemote == true)
                                {
                                    sb.Replace("CREATE VIEW", "ALTER VIEW");
                                }
                                break;

                            case "procedure":
                                if (existsInRemote == true)
                                {
                                    sb.Replace("CREATE PROCEDURE", "ALTER PROCEDURE");
                                }
                                break;
                        }

                        string sql = sb.ToString();

                        this.ConnectTimeout = 300;

                        using (SqlConnection remoteConnection = new SqlConnection(ConnectionString))
                        {

                            using (SqlCommand remoteCommand = new SqlCommand(sql, remoteConnection))
                            {

                                try
                                {
                                    await Task.WhenAll(Task.Run(async () =>
                                    {
                                        await remoteConnection.OpenAsync();
                                        await remoteCommand.ExecuteNonQueryAsync();
                                    }));

                                    retVal = true;

                                }
                                catch (SqlException e)
                                {
                                    Logger.LogError(e.Errors[0].Message, e.Server, sql);
                                    throw;
                                }
                            }
                        }
                    }
                }
            }

            return retVal;
        }
         
        public async Task<bool> CreateXes()
        {
            bool retStatus = false;

            using (SqlConnection remoteConnection = new SqlConnection(this.ConnectionString))
            {
                string sql = "dbo.usp_sqlwatch_internal_create_xes";

                using (SqlCommand remoteCommand = new SqlCommand(sql, remoteConnection))
                {
                    remoteCommand.CommandType = CommandType.StoredProcedure;

                    Logger.LogVerbose($"Creating XES on { this.SqlInstance } ({ this.SqlDatabase })");

                    try
                    {
                        await remoteConnection.OpenAsync();
                        await remoteCommand.ExecuteNonQueryAsync();

                        retStatus = true;
                    }
                    catch (SqlException e)
                    {
                        Logger.LogError(e.Errors[0].Message, e.Server, sql);
                        retStatus = false;
                        throw;
                    }
                }
            }

            return retStatus;
        }

    }
};