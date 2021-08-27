using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace SqlWatchCollect
{
    class CollectionTimer : SqlWatchInstance, IDisposable
    {
        void IDisposable.Dispose() { }

        public static int timerCounter = 0;

        private readonly Collector dataCollector;
        public CollectionTimer(Collector dataCollector)
        {
            this.dataCollector = dataCollector;
            SqlDatabase = dataCollector.SqlDatabase;
            SqlInstance = dataCollector.SqlInstance;
            SqlUser = dataCollector.SqlUser;
            SqlSecret = dataCollector.SqlSecret;

            timerCounter++;
            Logger.LogVerbose($"Total Number of Timers created: {timerCounter}");
        }

        ~CollectionTimer()
        {
            IsDisposed = true;
            timerCounter--;
            Logger.LogVerbose($"Timer {this.TimerId} for {this.SqlInstance} destroyed");
        }

        public DateTime LastTimerPool { get; set; } = Convert.ToDateTime("1970-01-01");

        public bool IsDisposed = false;

        public int TimerInterval { get; set; }

        public Guid TimerId { get; set; }

        public string TimerActiveDays { get; set; }

        public string TimerActiveHours { get; set; }

        public DateTime TimerActiveFrom { get; set; }

        public DateTime TimerActiveTo { get; set; }


        public List<double> AverageDuration = new List<double>();

        
        public List<int> TimerSnapshots = new List<int>();

        
        private bool IsTimerRunning = false;

        
        private AutoTimer timer;
        
        public class AutoTimer : System.Timers.Timer
        {
            public readonly string name;

            public AutoTimer(Guid timerId)
            {
                this.name = $"Timer_{timerId.ToString().Replace("-", "")}";
            }
        }

        
        private bool _disposed = false;

        
        private SafeHandle _safeHandle = new SafeFileHandle(IntPtr.Zero, true);

        public void Dispose() => Dispose(true);

        protected virtual void Dispose(bool disposing)
        {
            if (_disposed)
            {
                return;
            }

            if (disposing)
            {
                // Dispose managed state (managed objects).
                // I'm not gonna lie, this is as explained on from docs.microsoft.com
                // but I do not know what it means.
                _safeHandle?.Dispose();
            }

            _disposed = true;
        }

        public void StopAndDispose()
        {

            try
            {
                timer.Stop();
                timer.Dispose();
                
                Logger.LogVerbose($"Stopping timer { timer.name } for {this.SqlInstance}");

                Dispose();
            }
            catch (Exception e)
            {
                Logger.LogError($"Error whilst stopping timer { timer.name } for {this.SqlInstance}: { e.ToString() }");
            }
        }
        
        public async Task Start()
        {
            timer = new AutoTimer(this.TimerId);
            timer.Interval = this.TimerInterval;
            timer.Elapsed += Timer_Tick;
            timer.AutoReset = false;

            Logger.LogVerbose($"Starting new timer ({timer.name}) with interval {this.TimerInterval} for {this.SqlInstance}");

            //run the timer immediately instead of waiting for the first interval.
            //this will also Start the timer cycle:
            await Task.Run(() => Timer_Tick(timer, null));
        }

        private bool IsTimerActive()
        {

            DateTime Now = DateTime.UtcNow;
            string nowDay = System.DateTime.UtcNow.ToString("ddd");
            int nowHour = Convert.ToInt32(System.DateTime.UtcNow.ToString("HH"));

            bool isvalid = false;

            if (Now >= TimerActiveFrom & Now <= TimerActiveTo)
            {
                if (TimerActiveDays.Contains(nowDay))
                {
                    if (nowHour >= Convert.ToInt32(TimerActiveHours.Substring(0, 2)) & nowHour <= Convert.ToInt32(TimerActiveHours.Substring(3, 2)))
                    {
                        isvalid = true;
                    }
                }
            }

            return isvalid;
        }

        private async Task Timer_Work()
        {

            if (IsDisposed != false)
            {
                return;
            }

            DateTime timerShouldPoolNotEarlierThan = DateTime.UtcNow.AddSeconds(TimerInterval/1000 * -1);

            if (LastTimerPool > timerShouldPoolNotEarlierThan)  
            {
                Logger.LogWarning($"The execution of timer {TimerId} was skipped due to too frequent pools. Last pool was {timerShouldPoolNotEarlierThan} seconds ago, at {LastTimerPool} but the timer interval is {TimerInterval}");
                return;
            }

            Stopwatch sw = Stopwatch.StartNew();
            Guid g = Guid.NewGuid();

            using (Dialog Dialog = new Dialog())
            {
                Guid ConversationHandle = await Dialog.CreateNewConversationAsync();
                Logger.LogVerbose($"Timer { timer.name } created a new conversation dialog ({ConversationHandle}) for { this.SqlInstance }");

                using (CollectionSnapshot CollectionSnapshot = new CollectionSnapshot(this.dataCollector))
                {
                    using (CollectionWriter collectionWriter = new CollectionWriter(ConversationHandle))
                    {

                        try
                        {
                            IsTimerRunning = true;
                            var exceptions = new ConcurrentQueue<Exception>();

                            //Metadata snasphot:
                            if (this.TimerId.ToString().ToUpper() == "B7686F08-DCAF-4EFC-94E8-3BD8D2C8E8A5")
                            {
                                foreach (string m in new[] { "meta_server", "sys_databases", "sys_master_files", "sys_jobs" })
                                {
                                    string xml_message = string.Empty;
                                    try
                                    {
                                        xml_message = await CollectionSnapshot.GetRemoteMetaDataXml(m);

                                        await Task.WhenAll(collectionWriter.WriteMessage(xml_message, "mtype_sqlwatch_meta"));

                                    }
                                    catch (Exception e)
                                    {
                                        exceptions.Enqueue(e);
                                    }
                                }
                            }
                            else
                            {
                                foreach (int snapshotTypeId in TimerSnapshots)
                                {
                                    try
                                    {
                                        string xml_message = string.Empty;

                                        if (snapshotTypeId == 17)
                                        {
                                            xml_message = await CollectionSnapshot.GetWmiWin32Volume();
                                        }
                                        else
                                        {
                                            xml_message = await CollectionSnapshot.GetRemoteSnapshotDataXml(snapshotTypeId, timer.Interval);
                                        }

                                        await Task.WhenAll(collectionWriter.WriteMessage(xml_message, "mtype_sqlwatch_collector"));

                                    }
                                    catch (Exception e)
                                    {
                                        exceptions.Enqueue(e);
                                    }
                                };
                                //}
                            }

                            if (exceptions.Count > 0) throw new AggregateException(exceptions);

                            AverageDuration.Add(sw.Elapsed.TotalMilliseconds);
                        }

                        //catch (SqlException e)
                        catch (AggregateException ae)
                        {

                            foreach (var e in ae.Flatten().InnerExceptions)
                            {
                                Logger.LogError(e.Message, $"{timer.name} ({ this.SqlInstance })");

                                if (e.Message.Contains("A network-related or instance-specific error occurred while establishing a connection to SQL Server") ||
                                    e.Message.Contains("The specified network name is no longer available"))
                                {
                                    Logger.LogWarning($"Removing currently active { timer.name } because { this.SqlInstance } appears to be offline.");

                                    timer.Stop();

                                    timer.Dispose();

                                    return;

                                }
                                else if (e.Message.Contains("Timeout"))
                                {
                                    Logger.LogWarning($"Pausing { timer.name } for { this.SqlInstance } due to server timeouts.");

                                    timer.Stop();

                                    Task.Delay(1000 * 60).Wait();

                                    Logger.LogInformation($"Resuming { timer.name } for { this.SqlInstance }.");

                                }
                            }
                        }

                        finally
                        {
                            if (AverageDuration.Count > 5)
                            {
                                AverageDuration.RemoveAt(0);

                                Logger.LogVerbose($"Average { timer.name } duration over the last { AverageDuration.Count } collections was { AverageDuration.Average() }ms");

                                if (Convert.ToInt32(AverageDuration.Max()) > Convert.ToInt32(timer.Interval))
                                {
                                    int newInterval = Convert.ToInt32((double)Math.Round(AverageDuration.Max() * this.TimerInterval) / this.TimerInterval) + 1000;
                                    Logger.LogWarning($"Changing { timer.name } schedule for { this.SqlInstance } from { timer.Interval / 1000 }s to every { newInterval / 1000 }s based on past execution times.");
                                    timer.Interval = newInterval;
                                }
                                else if (Convert.ToInt32(timer.Interval) != this.TimerInterval & AverageDuration.Max() <= this.TimerInterval)
                                {
                                    timer.Interval = this.TimerInterval;
                                    Logger.LogInformation($"Restoring { timer.name } default Collection schedule ({ timer.Interval / 1000 }s) for { this.SqlInstance } ");
                                }
                            }

                            Logger.LogVerbose($"Completed Collection from { this.SqlInstance } in { sw.Elapsed.TotalMilliseconds }ms. Timer { timer.name } ({ g }) ");

                            LastTimerPool = DateTime.UtcNow;
                        }
                    }

                    await Dialog.EndConversation(ConversationHandle);
                    Logger.LogVerbose($"Sending END message for { ConversationHandle }");
                };
            }
        }

        private async void Timer_Tick(object sender, EventArgs args)
        {
            if (IsDisposed != false)
            {
                return;
            }

            AutoTimer aTimer = sender as AutoTimer;

            if (IsTimerActive() == false)
            {
                Logger.LogVerbose($"Timer { aTimer.name } is inactive, disable or invalid.");
                return;
            }
            else if (IsTimerRunning == true)
            {

                Logger.LogWarning($"Previous instance of the { aTimer.name } for { this.SqlInstance } is still running. New snapshot will not be collected.");
                return;
            }
            else
            {
                await Timer_Work();

                IsTimerRunning = false;

                if (IsDisposed != false) 
                {
                    return;
                }

                if (timer.AutoReset == false)
                {
                    timer.Start();
                }
            }
        }
    }
}