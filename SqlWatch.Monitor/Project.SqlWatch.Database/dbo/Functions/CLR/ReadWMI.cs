using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class UserDefinedFunctions
{
    [Microsoft.SqlServer.Server.SqlFunction]
    public static SqlString ReadWMI()
    {
        // I believe accessing WMI will require EXTERNAL ACCESS which could be disallowed in many environments. 
        // Accessing Perf counters however only requires UNSAFE (or signed) assemply which is mostly fine.
        // I need to test this but for now this is just a placeholder

        // The benefit of using WMI is that they can provide formatted data instantaneously.
        // They are using the same derivation from raw data as we would have done in PerformanceCounter class
        // but they use high performnace interfaces and results are consistent with the perf monitor.
        // Calculating perfcounter data is difficult and I'd rather use something out of the box.
        // https://docs.microsoft.com/en-us/windows/win32/wmisdk/formatted-performance-data-provider
        return new SqlString (string.Empty);
    }
}
