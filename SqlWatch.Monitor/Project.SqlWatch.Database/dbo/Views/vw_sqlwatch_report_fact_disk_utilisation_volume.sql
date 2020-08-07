CREATE VIEW [dbo].[vw_sqlwatch_report_fact_disk_utilisation_volume] with schemabinding
as

SELECT d.[sqlwatch_volume_id]
	  ,v.volume_name
      ,[volume_free_space_bytes]
      ,[volume_total_space_bytes]
      ,h.report_time
      ,d.[sql_instance]
 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
, d.snapshot_time
, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_disk_utilisation_volume] d

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
		select [volume_name]
		from [dbo].[sqlwatch_meta_os_volume] mov
		where mov.sql_instance = d.sql_instance
		and mov.sqlwatch_volume_id = d.sqlwatch_volume_id
	) v