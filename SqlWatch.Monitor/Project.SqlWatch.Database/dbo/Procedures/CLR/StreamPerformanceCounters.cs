using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class StoredProcedures
{
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void StreamPerformanceCounters ()
    {
        // The problem with reading performance counters is that we often need to read it twice to get calculated value.
        // If we are doing this in SQL DMVs, we can save first read into a table, then read again after few seconds and calculate deltas.
        // .NET does not work like that, every time we invoke PerformanceCounter reader its reset so we almost always have to read it twice
        // This is quite expensive. It's much better to invoke PerformnaceCounter and let it stream continuously.

        // THIS IS TO DO. placeholder for now
    }
}
