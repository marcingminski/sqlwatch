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
      --,db.[database_name]
      --,p.plan_handle
      ,e.[sql_instance]
      ,e.[snapshot_time]
      ,e.[snapshot_type_id]
      ,e.plan_handle
      ,e.statement_start_offset
      ,e.statement_end_offset
      ,p.[query_plan_for_query_plan_hash]
  from [dbo].[sqlwatch_logger_xes_wait_event] e

  inner join dbo.vw_sqlwatch_meta_wait_stats_category ws
	on e.[wait_type_id] = ws.[wait_type_id]
	and e.sql_instance = ws.sql_instance

 -- inner join dbo.sqlwatch_meta_database db
	--on db.sqlwatch_database_id = e.[sqlwatch_database_id]
	--and db.sql_instance = e.sql_instance

    left join dbo.[sqlwatch_meta_query_plan] qph
        on qph.sql_instance = e.sql_instance
        and qph.plan_handle = e.plan_handle
        and qph.statement_start_offset = e.statement_start_offset
        and qph.statement_end_offset = e.statement_end_offset

    left join dbo.[sqlwatch_meta_query_plan_hash] p
        on p.sql_instance = qph.sql_instance
        and p.query_plan_hash = qph.query_plan_hash