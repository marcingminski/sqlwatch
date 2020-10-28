---
nav_order: 10
parent: Configuration
title: Data Collection
has_children: true
---

# Data Collection
{: .no_toc }
---

There are several options that allow to configure data collection behavior.
- TOC 
{:toc}

## Collection schedules

You may adjust collection schedules to your liking, however, it is not recommended to change the frequency of the `SQLWATCH-LOGGER-PERFORMANCE`. It has been optimised to run every minute. Apart from reducing [collection granulatiry](https://sqlwatch.io/blog/impact-of-aggregation-on-granularity-and-observability/) it may cause some dashboard to return null data for some aggregation. The collector also offloads data from XE sessions and if not run frequently, sessions will start rolling over and overwriting collected data.

## Collection exclusion and inclusion

Some data collectors have an option to exclude selected objects from collection and some collectors require explicit definition of the data we want to collect.

Both can be configured in the respective tables: `dbo.sqlwatch_config_exclude_*` and `dbo.sqlwatch_config_include_*`

The biggest difference is that the exclusive collectors will collect everything apart from the excluded items, and the inclusive collectors will not collect anything unless specified.

For example, the database collector will collect all databases apart from those excluded in `[dbo].[sqlwatch_config_exclude_database]` but the index histogram collector will not collect any index histograms unless specified in `[dbo].[sqlwatch_config_include_index_histogram]`.

## Performance counters

Performance counters collected by SQLWATCH are defined in table `[dbo].[sqlwatch_config_performance_counters]`.
Collection of individual performance counters can be set using the `collect` column: `1` for YES (collet) and `0` for NO (do not collect). Disabling the default performance counter collectors will stop them from being collected and therefore may break the default dashboard. New collectors can be added to the list if required. 

Please note the `instance_name` is dynamic and contains actual names of objects i.e. database names. The collection definition takes this into account with a dynamic approach:


|                                               Definition                                               |                                                                                                                                                                  Description                                                                                                                                                                   |
|--------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Will translate to literal 'Elapsed Time:Total(ms)' or '' Note that instance name must a valid instance | Will translate to literal 'Elapsed Time:Total(ms)' or '' Note that instance name must a valid instance                                                                                                                                                                                                                                        |
| _Total                                                                                                 | Will only include '_Total' instances. This is useful if we only want to collect high-level aggregates and are not interested in low-level objects i.e. database                                                                                                                                                                                |
| <* !_Total>                                                                                            | Will not include '_Total' instances, i.e. it will collect any other instances for this particular counter_name but not totals. This is useful if we want to collect low-level objects i.e. database performance and will be aggregating and calculating totals, for example in Power BI. In this case, there is no value in collecting totals.  |
