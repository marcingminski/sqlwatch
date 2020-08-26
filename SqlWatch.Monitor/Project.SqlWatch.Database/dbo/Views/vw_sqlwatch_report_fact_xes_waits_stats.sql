CREATE VIEW [dbo].[vw_sqlwatch_report_fact_xes_wait_events] with schemabinding
as

select e.[event_time]
      ,ws.[wait_type]
      ,ws.wait_category
      ,e.[activity_id]
      ,e.[activity_id_sequence]
      ,e.[duration]
      ,e.[signal_duration]
      ,e.[session_id]
      ,e.[username]
      ,e.[client_hostname]
      ,e.[client_app_name]
      ,db.[database_name]
      ,q.[sql_text]
      ,e.[sql_instance]
      ,e.[snapshot_time]
      ,e.[snapshot_type_id]
      ,e.sqlwatch_query_hash
  from [dbo].[sqlwatch_logger_xes_wait_event] e

  inner join dbo.vw_sqlwatch_meta_wait_stats_category ws
	on e.[wait_type_id] = ws.[wait_type_id]
	and e.sql_instance = ws.sql_instance

  inner join dbo.sqlwatch_meta_database db
	on db.sqlwatch_database_id = e.[sqlwatch_database_id]
	and db.sql_instance = e.sql_instance

  left join [dbo].[sqlwatch_meta_sql_query] q
	on q.[sqlwatch_query_hash] = e.[sqlwatch_query_hash]
	and q.sql_instance = e.sql_instance