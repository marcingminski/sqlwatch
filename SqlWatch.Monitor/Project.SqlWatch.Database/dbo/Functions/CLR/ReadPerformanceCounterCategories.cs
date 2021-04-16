using System;
using System.Collections;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.Diagnostics;
using Microsoft.SqlServer.Server;

public partial class UserDefinedFunctions
{

    private class CounterProperties
    {
        public SqlString objectName;
        public SqlString counterName;
        public SqlString instanceName;
        public CounterProperties(String objectName, String counterName, String instanceName)
        {
            this.objectName = objectName;
            this.counterName = counterName;
            this.instanceName = instanceName;
        }
    }



    [Microsoft.SqlServer.Server.SqlFunction(
         FillRowMethodName = "GetCounters",
         TableDefinition = "object_name nvarchar(128), counter_name nvarchar(128), instance_name nvarchar(128)")]
    public static IEnumerable ReadPerformanceCounterCategories()
    {

        try
        {

            PerformanceCounterCategory[] categories = PerformanceCounterCategory.GetCategories();

            ArrayList performanceCounterCollection = new ArrayList();

            foreach (PerformanceCounterCategory category in categories)
            {
                string[] instanceNames = category.GetInstanceNames();
                if (instanceNames.Length > 0)
                {
                    // MultiInstance counters
                    foreach (string instanceName in instanceNames)
                    {
                        PerformanceCounter[] counters = category.GetCounters(instanceName);
                        foreach (PerformanceCounter counter in counters)
                        {
                            performanceCounterCollection.Add(new CounterProperties(category.CategoryName, counter.CounterName, instanceName));
                        }
                    }

                }
                else
                {
                    PerformanceCounter[] counters = category.GetCounters();
                    foreach (PerformanceCounter counter in counters)
                    {
                        performanceCounterCollection.Add(new CounterProperties(category.CategoryName, counter.CounterName, string.Empty));
                    }

                }
            }

            return performanceCounterCollection;

        }

        catch
        {
            return null;
        }


    }

    public static void GetCounters(object objCounterProperties,out SqlChars object_name, out SqlChars counter_name, out SqlChars instance_name)
    {
        CounterProperties counterProperties = (CounterProperties)objCounterProperties;
        object_name = new SqlChars(counterProperties.objectName);
        counter_name = new SqlChars(counterProperties.counterName);
        instance_name = new SqlChars(counterProperties.instanceName);
    }
}
