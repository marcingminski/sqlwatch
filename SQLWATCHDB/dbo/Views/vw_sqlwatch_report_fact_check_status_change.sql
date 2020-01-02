CREATE VIEW [dbo].[vw_sqlwatch_report_fact_check_status_change] with schemabinding
	as
	select 
	l1.sql_instance,
	l1.check_id,
	l1.check_status,
	[status_start_time] = l1.snapshot_time,
	[status_end_time] = isnull(t.snapshot_time,getutcdate())
	, h.report_time
	, check_count = t.check_count
	, l1.snapshot_type_id
from [dbo].[sqlwatch_logger_check] l1
inner join dbo.sqlwatch_logger_snapshot_header h
	on h.snapshot_time = l1.snapshot_time
	and h.sql_instance = l1.sql_instance
	and h.snapshot_type_id = l1.snapshot_type_id
outer apply (
		select 
			snapshot_time=max(snapshot_time),
			check_count=count(*)
		from [dbo].[sqlwatch_logger_check]
		where check_id = l1.check_id
		and sql_instance = l1.sql_instance
		and snapshot_time > l1.snapshot_time
		and status_change = 0
) t
where l1.status_change = 1
