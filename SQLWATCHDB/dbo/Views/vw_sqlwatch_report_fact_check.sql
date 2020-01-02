CREATE VIEW [dbo].[vw_sqlwatch_report_fact_check]
	AS 

select 
	  [d].[sql_instance]
	, [d].[snapshot_time]
	, [d].[check_id]
	, c.check_name
	, [d].[check_value]
	, [d].[check_status]
	, [d].[check_exec_time_ms]
	, h.report_time
	, [d].status_change
	, d.snapshot_type_id
from dbo.sqlwatch_logger_check d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance


	/*  using outer apply instead of inner join is SOO MUCH slower...
		BUT it only applies to the columns we select.
		If we do not select any columns from the outer apply, it does not get applied whereas joins
		always do whether we select columns or not. 99% of the time these views will feed PowerBI wher only IDs are required
		and small subset of columns queried. that 1% will be DBAs querying views directly in SSMS (TOP (1000)) in which case, 
		having actual names instead alongisde IDs will make their life easier with small increase in performane penalty */

	outer apply (
		select check_name
		from [dbo].[sqlwatch_meta_check] mc
		where mc.sql_instance = d.sql_instance
		and mc.check_id = d.check_id
	) c
