using System.Data.SqlTypes;
using System.Diagnostics;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlString ReadPerformanceCounterFormatted(string objectName, string counterName, string instanceName)
    {
        try
        {
            PerformanceCounter counterValue = new PerformanceCounter(objectName, counterName, instanceName);

            float returnValue = counterValue.NextValue();

            if (returnValue == 0) {

                //https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecounter
                //For some counters, the NextValue will always return 0 on the first iteration as its a calculated value, it needs a value to compare against:
                //Before we check it again, we're putting it to sleep to let it calm down after invocation:
                System.Threading.Thread.Sleep(20);
                returnValue = counterValue.NextValue();

            }
            //bummer as SqlDouble (float) is non-nullable so if we ask to return a nonexistent counter, we cannot return null
            //To return null we need a nullable type that will accept floating point, so string:
            return returnValue.ToString();
        }
        catch
        {
            return null;
        }
    }
}
