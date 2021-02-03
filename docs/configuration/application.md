---
nav_order: 5
parent: Configuration
title: Application
---

# Global Application Configuration
{: .no_toc }
---

The global configuration drives how the application behaves and its functionality. The configuration is in the `[dbo].[sqlwatch_config]` table:

```
SELECT [config_id]
      ,[config_name]
      ,[config_value]
  FROM [SQLWATCH].[dbo].[sqlwatch_config]
```

## Action Queue Failed Items retention days
Number of days to keep failed items in the action queue table `[dbo].[sqlwatch_meta_action_queue]`. 

## Action Queue Success Items retention days
Number of days to keep successful items in the action queue table `[dbo].[sqlwatch_meta_action_queue]`.

## Application Log (`app_log`) retention days
Number of days to keep records in the `[dbo].[sqlwatch_app_log]` table.

## Error on NULL check value
Specifies whether we should raise a critical error (severity 16) or just a warning when the check returns a NULL value. Normally checks MUST return a value and NULL would indicate problems with the underlying data or the check query. 

When set to `1` and the check returns NULL value, the agent job `SQLWATCH-INTERNAL-CHECKS` will also fail and the error will be logged in `[dbo].[sqlwatch_app_log]` table. 

When set to `0`, only a warning will be logged in `[dbo].[sqlwatch_app_log]` and the job will not fail.

## Fail back to system_health session
SQLWATCH comes with its own Extended Events Sessions that have been optimise for its data collection. If the SQLWATCH XE sessions are disabled, we can try collect basic metrics from the default `system_health` session. It is however recommended to enable SQLWATCH XES.

## Last Seen Items (`date_last_seen`) retention days
Number of days to keep removed or excluded items. For example, a table that has been deleted, or a database that has been dropped will have the `date_last_seen` date in the past. We will remove those items after certain number of days. This setting applies to selected "meta" tables that have the `date_last_seen` field.

## Last Seen Items purge batch size
The number of records to delete at once when purging removed items based on the `date_last_seen`. This setting applies to selected "meta" tables that have the `date_last_seen` field.

## Logger Log Info messages
Specifies whether to log INFO messages in the `[dbo].[sqlwatch_app_log]` table. They may be handy to see more details but will increase the size of the table dramatically.

If set to `1`, the `INFO` messages will be saved in the table.

If set to `0` only `WARNING` and `ERROR` messages will be saved. This is recommended setting.

## Logger Retention batch size
Number of rows to delete in each batch when running data retention job. This applies to all logger tables and is based on the retention specified in the `[dbo].[sqlwatch_config_snapshot_type]` table.