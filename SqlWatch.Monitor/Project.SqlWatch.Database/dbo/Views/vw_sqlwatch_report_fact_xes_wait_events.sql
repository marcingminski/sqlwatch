CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_wait_events] with schemabinding
as

select e.[event_time]
      ,ws.[wait_type]
      ,ws.wait_category
      ,e.[duration]
      ,e.[signal_duration]
      ,e.[session_id]
      ,e.[username]
      ,e.[client_hostname]
      ,e.[client_app_name]
      --,p.plan_handle
      ,e.[sql_instance]
      ,e.[snapshot_time]
      ,e.[snapshot_type_id]
      ,e.plan_handle
      ,e.statement_start_offset
      ,e.statement_end_offset
      ,qph.[query_plan_for_query_plan_hash]
      ,db.[database_name]
	  ,pr.[procedure_name]
	  ,sql_text =  coalesce(dbo.ufn_sqlwatch_clean_sql_text(qph.statement_for_query_plan_hash),ed.sql_text)
      ,qp.query_plan_hash
  from [dbo].[sqlwatch_logger_xes_wait_event] e

    inner join dbo.vw_sqlwatch_meta_wait_stats_category ws
	    on e.[wait_type_id] = ws.[wait_type_id]
	    and e.sql_instance = ws.sql_instance

    left join dbo.[sqlwatch_meta_query_plan] qp
        on qp.sql_instance = e.sql_instance
        and qp.plan_handle = e.plan_handle
        and qp.statement_start_offset = e.statement_start_offset
        and qp.statement_end_offset = e.statement_end_offset

    left join dbo.[sqlwatch_meta_query_plan_hash] qph
        on qph.sql_instance = qp.sql_instance
        and qph.query_plan_hash = qp.query_plan_hash
        
    left join dbo.[sqlwatch_meta_database] db 
        on db.sqlwatch_database_id = qp.sqlwatch_database_id
        and db.sql_instance = qp.sql_instance

    left join dbo.[sqlwatch_meta_procedure] pr
        on pr.sqlwatch_procedure_id = qp.sqlwatch_procedure_id
        and pr.sql_instance = qp.sql_instance
			
    cross apply dbo.ufn_sqlwatch_parse_xes_event_data([event_data]) ed;