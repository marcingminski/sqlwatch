CREATE VIEW [dbo].[vw_sqlwatch_help_last_snapshot_time] with schemabinding
	as
select 
	  h.sql_instance
	, h.snapshot_type_id
	, t.snapshot_type_desc
	, snapshot_time_utc=max(snapshot_time)
	, snapshot_time_local = max(dateadd(minute,[snapshot_time_utc_offset],snapshot_time))
	, snapshot_age_minutes = datediff(minute,max(snapshot_time),getutcdate())
	, snapshot_age_hours = datediff(hour,max(snapshot_time),getutcdate())
from dbo.sqlwatch_logger_snapshot_header h
inner join dbo.sqlwatch_config_sql_instance s
	on h.sql_instance = s.sql_instance
inner join dbo.sqlwatch_config_snapshot_type t
	on t.snapshot_type_id = h.snapshot_type_id
where ( s.sql_instance = @@SERVERNAME or (s.sql_instance <> @@SERVERNAME and repo_collector_is_active = 1))
and ( (t.collect = 1 and h.sql_instance = @@SERVERNAME) or h.sql_instance <> @@SERVERNAME )
	
	----these snapshots do not have to run within given schedule:
	--and snapshot_type_id not in (	
	--19, --actions
	--20, --reports
	--21  --log
	--)

group by h.sql_instance, h.snapshot_type_id, t.snapshot_type_desc
