---
nav_order: 15
title: Configuration
has_children: true
---

# Configuration
{: .no_toc }
---

SQLWATCH has been designed with "set it and forget it" approach and does not require any maintenance or extensive post-installation configuration to get started. It will run out of the box. However, some configuration is available.

- TOC 
{:toc}

## Blocked Process Monitor

To enable SQLWATCH to record blocking chains we must to set the `blocked process threshold` to the appropriate time window. Learn more about [Blocked Process Threshold](https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/blocked-process-threshold-server-configuration-option)

The blocked process monitor will log any transactions (queries) that are being blocked for longer than the set threshold. In the example below, we are setting it to log blocking chains lasting longer than 15 seconds.

```
exec sp_configure 'show advanced options', 1 ;  
RECONFIGURE ;  
exec sp_configure 'blocked process threshold', 15 ;  
RECONFIGURE ; 
```

To make this easier, SQLWATCH comes with a stored procedure that can execute the above configuration:

```
--default threshold will be 15 seconds:
exec [dbo].[usp_sqlwatch_config_set_blocked_proc_threshold] 

--to apply different threshold:
exec [dbo].[usp_sqlwatch_config_set_blocked_proc_threshold] @threshold_seconds = x 
```

## Retention periods

Retention periods are configurable for each snapshot and stored in the `[dbo].[sqlwatch_config_snapshot_type]` table in the `[snapshot_retention_days]` column. If you are offloading data to a central repository or Azure, you can drop local retention to a day or two. 

A negative value indicates that only the most recent snapshot will be kept regardless its age.

The action retention is executed by `SQLWATCH-INTERNAL-RETENTION` and runs every hour by default.

## Logging level

By default, SQLWATCH will only log Warnings and Errors in the `[dbo].[sqlwatch_app_log]` table. To enable verbose (informational) logging you can change the item 7 value to 1, or to 0 to disable verbose logging:

```
  update [dbo].[sqlwatch_config]
  set config_value = 1 
  where config_id = 7
```

Remember to change it back to 0 after you have done investigating the issue as it may cause the `app_log` table to grow rapidly.

## Table and Index compression

You may wish to compress data in SQLWATCH to improve storage utilisation and I/O performance at the cost of CPU utilisation. You can do so by running:

```
exec [dbo].[usp_sqlwatch_config_set_table_compression];
exec [dbo].[usp_sqlwatch_config_set_index_compression];
```

## Recreate agent jobs

To create all default SQLWATCH agent jobs you can run:

```
--add any missing SQLWATCH jobs, will not remove existing SQLWATCH jobs:
exec [dbo].[usp_sqlwatch_config_set_default_agent_jobs]

--remove existing and recreate all SQLWATCH jobs:
exec [dbo].[usp_sqlwatch_config_set_default_agent_jobs] @remove_existing = 1
```


