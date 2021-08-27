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
      ,e.[sql_instance]
      ,e.[snapshot_time]
      ,e.[snapshot_type_id]
	  ,sq.sql_statement_sample
      ,e.query_plan_hash
      ,e.query_hash
      ,db.database_name
      ,e.sqlwatch_procedure_id
  from [dbo].[sqlwatch_logger_xes_wait_event] e

    inner join dbo.vw_sqlwatch_meta_wait_stats_category ws
	    on e.[wait_type_id] = ws.[wait_type_id]
	    and e.sql_instance = ws.sql_instance
        
    inner join dbo.[sqlwatch_meta_database] db 
        on db.sqlwatch_database_id = e.sqlwatch_database_id
        and db.sql_instance = e.sql_instance
        and db.database_create_date = e.database_create_date

	left join [dbo].[sqlwatch_meta_sql_query] sq
		on sq.sql_instance = e.sql_instance
		and sq.query_hash = e.query_hash
        and sq.sqlwatch_database_id = e.sqlwatch_database_id
        and sq.sqlwatch_procedure_id = e.sqlwatch_procedure_id