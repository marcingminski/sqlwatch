CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_long_queries] with schemabinding
as

SELECT
       d.event_time
      ,d.[event_name]
      ,d.[session_id]
      ,d.[cpu_time]
      ,d.[physical_reads]
      ,d.[logical_reads]
      ,d.[writes]
      ,d.[spills]
      ,d.[username]
      ,d.[client_hostname]
      ,d.[client_app_name]
      ,d.[duration_ms]
      ,report_time
      ,d.[sql_instance]
      ,[long_query_id]
	  --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
	  , d.snapshot_time
	  , d.snapshot_type_id
    , qph.[query_plan_for_query_plan_hash]
	  , db.[database_name]
	  , pr.[procedure_name]
	  , coalesce(dbo.ufn_sqlwatch_clean_sql_text(qph.statement_for_query_plan_hash),ed.sql_text)
		  as sql_text
  FROM [dbo].[sqlwatch_logger_xes_long_queries] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance

    left join dbo.[sqlwatch_meta_query_plan] qp
        on qp.sql_instance = d.sql_instance
        and qp.plan_handle = d.plan_handle
        and qp.statement_start_offset = d.statement_start_offset
        and qp.statement_end_offset = d.statement_end_offset

    left join dbo.[sqlwatch_meta_query_plan_hash] qph
        on qph.sql_instance = qp.sql_instance
        and qph.query_plan_hash = qp.query_plan_hash

    left join dbo.[sqlwatch_meta_database] db 
        on db.sqlwatch_database_id = qp.sqlwatch_database_id
        and db.sql_instance = qp.sql_instance

    left join dbo.[sqlwatch_meta_procedure] pr
        on pr.sqlwatch_procedure_id = qp.sqlwatch_procedure_id
        and pr.sql_instance = qp.sql_instance

	cross apply dbo.ufn_sqlwatch_parse_xes_event_data([event_data]) ed