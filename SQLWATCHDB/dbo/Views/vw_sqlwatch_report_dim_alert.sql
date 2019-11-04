CREATE VIEW [dbo].[vw_sqlwatch_report_dim_alert] with schemabinding
	AS 
	select ma.sql_instance, ac.check_id, ac.[check_name], ma.last_check_date, ma.last_check_value, ma.last_check_status, ma.[last_status_change_date], ma.[last_trigger_date]
	from [dbo].[sqlwatch_meta_alert] ma
	inner join [dbo].[sqlwatch_config_alert_check] ac
		on ma.[sql_instance] = ac.[sql_instance]
		and ma.[check_id] = ac.[check_id]
