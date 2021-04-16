using System;
using System.Data.SqlTypes;
using System.Diagnostics;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlString ReadPerformanceCounterFormatted(string objectName, string counterName, string instanceName)
    {
        try
        {

            PerformanceCounter counter = new PerformanceCounter(objectName, counterName, instanceName);
            
            float returnValue = counter.NextValue();

            if (counter.CounterType.ToString().StartsWith("Timer100N")) {

                //https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecounter
                //https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecountertype
                //Timer100NsInverse Counter type calculates values over a period of time so we have to read the counter, wait, and read it again.
                //The recommended wait is 1s:
                System.Threading.Thread.Sleep(1000);
                returnValue = counter.NextValue();

            }
            //bummer as SqlDouble (float) is non-nullable so if we ask to return a nonexistent counter, we cannot return null.
            //If we do not do try catch and ask for nonexistent counter the .NET will return a hard error and break the batch.
            //To return null we need a nullable type that will accept floating point, so string:
            //return returnValue.ToString();
            return returnValue.ToString();
        }
        catch
        {
            return null;
        }
    }
}
