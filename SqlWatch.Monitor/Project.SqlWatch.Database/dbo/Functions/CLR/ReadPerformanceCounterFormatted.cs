using System;
using System.Data.SqlTypes;
using System.Diagnostics;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlDouble ReadPerformanceCounterFormatted(string objectName, string counterName, string instanceName, int? period)
    {
        try
        {
            // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecounter
            // https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecountertype

            PerformanceCounter counter = new PerformanceCounter(objectName, counterName, instanceName);
            
            SqlDouble returnValue = counter.NextValue();

            if (counter.CounterType.ToString().StartsWith("Timer100N")) 
            {
                System.Threading.Thread.Sleep((int)(period.HasValue == true ? period : 50));
                returnValue = counter.NextValue();
            }
            return returnValue;
        }
        catch
        {
            return new SqlDouble();
        }
    }
}
