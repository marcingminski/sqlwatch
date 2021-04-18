using System;
using System.Collections;
using System.Data.SqlTypes;
using System.Diagnostics;

public partial class UserDefinedFunctions
{

    public enum PerformanceCounterType
    {
        NumberOfItemsHEX32 = 0,
        NumberOfItemsHEX64 = 256,
        NumberOfItems32 = 65536,
        NumberOfItems64 = 65792,
        CounterDelta32 = 4195328,
        CounterDelta64 = 4195584,
        SampleCounter = 4260864,
        CountPerTimeInterval32 = 4523008,
        CountPerTimeInterval64 = 4523264,
        RateOfCountsPerSecond32 = 272696320,
        RateOfCountsPerSecond64 = 272696576,
        RawFraction = 537003008,
        CounterTimer = 541132032,
        Timer100Ns = 542180608,
        SampleFraction = 549585920,
        CounterTimerInverse = 557909248,
        Timer100NsInverse = 558957824,
        CounterMultiTimer = 574686464,
        CounterMultiTimer100Ns = 575735040,
        CounterMultiTimerInverse = 591463680,
        CounterMultiTimer100NsInverse = 592512256,
        AverageTimer32 = 805438464,
        ElapsedTime = 807666944,
        AverageCount64 = 1073874176,
        SampleBase = 1073939457,
        AverageBase = 1073939458,
        RawBase = 1073939459,
        CounterMultiBase = 1107494144
    }

    private class CounterRawResults
    {
        public SqlSingle cntr_value;
        public SqlString cntr_type;
        public SqlString cntr_type_desc;

        public CounterRawResults(SqlSingle cntr_value, SqlString cntr_type, SqlString cntr_type_desc)
        {
            this.cntr_value = cntr_value;
            this.cntr_type = cntr_type;
            this.cntr_type_desc = cntr_type_desc;
        }
    }

    [Microsoft.SqlServer.Server.SqlFunction(
           FillRowMethodName = "GetCounterData",
           TableDefinition = "cntr_value real null, cntr_type nvarchar(128) null, cntr_type_desc nvarchar(128) null")]

    public static IEnumerable GetPerformnaceCounterData(string objectName, string counterName, string instanceName, int? period)
    {
        // try
        // {
        // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecounter
        // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecountertype

        ArrayList performanceCounterData = new ArrayList();
            string counterNameBase = counterName + " base";

            PerformanceCounter counter = new PerformanceCounter(objectName, counterName, instanceName);
            string baseCounterName = counterNameBase;

        int performanceCounterType = (int)Enum.Parse(typeof(PerformanceCounterType), counter.CounterType.ToString());

        if (
                counter.CounterType.ToString().StartsWith("Timer100N") ||
                // I cannot find any documentation about the below type which I see in \LogicalDisk\Avg. Disk Read Queue Length
                // I see a referefence to it in WMI but no explanation how to calculate it.
                // I am going to have to return calculated value for this type:
                counter.CounterType.ToString().Contains("5571840") 
                )

        {
            /* 
             * The Timer counter works as follow:
             * Timer100NsInverse: (1 - ((N1 - N0) / (D1 - D0))) x 100, 
             * where the numerator represents the time during the interval when the monitored components were inactive, 
             * and the denominator represents the total elapsed time of the sample interval.
             * 
             * This means that if we were going to return a raw value to calculate later, we'd have to return the raw value + ticks
             * It's easier to just calculate this counter on the fly here. However this requires two readings.
             * We will make the first reading into a dummy variable and the second reading will be the actual:
             * 
             * test against: typeperf "\Processor(_Total)\% Processor Time" -si 1
             * Collecting CPU % is difficult as we have to observe it over a period of time.
             * If you typeperf with 1 second interval it will observe it for 1 second and return averaged value from that period.
             * We cannot observe it for long in here as we need to quit and return data back to SQL as otherwise we will be holding up stored proc.
             * Ideally we'd want a multithreaded .NET app/service that would do what typeperf.exe does.
             */
            float r = counter.NextValue();
            System.Threading.Thread.Sleep((int)(period.HasValue == true ? (int)period : 100));
            performanceCounterData.Add(new CounterRawResults(counter.NextValue(), performanceCounterType.ToString(), counter.CounterType.ToString()));
        }
        else
        {
            performanceCounterData.Add(new CounterRawResults(counter.RawValue, performanceCounterType.ToString(), counter.CounterType.ToString()));
        }
            
        
        return performanceCounterData;
    }

    public static void GetCounterData(object oCounterRawResults, out SqlSingle cntr_value, out SqlChars cntr_type, out SqlChars cntr_type_desc)
    {
        CounterRawResults counterRawResults = (CounterRawResults)oCounterRawResults;

        cntr_value = new SqlSingle((double)counterRawResults.cntr_value);
        cntr_type = new SqlChars(counterRawResults.cntr_type);
        cntr_type_desc = new SqlChars(counterRawResults.cntr_type_desc);

        //counter_base = new SqlChars(counterRawResults.counter_base);
        //counter_base_value = counterRawResults.counter_base_value.HasValue == true ? new SqlInt64((long)counterRawResults.counter_base_value) : new SqlInt64();
    }

}
