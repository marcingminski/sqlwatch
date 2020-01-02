CREATE VIEW [dbo].[vw_sqlwatch_report_config_check_action] with schemabinding
	as
select 
	cc.check_id
	, check_name
	, cc.check_enabled
	, ca.action_id
	, ca.action_description
	, ca.action_enabled
	, ca.action_exec_type
	, ca.action_exec
	, at.action_template_id
	, at.action_template_description

	, ca.action_report_id
	, cr.report_title
	, cr.report_active
	, report_action_id=rca.action_id
	, report_action_description=rca.action_description
	, report_action_enabled=rca.action_enabled
	, report_action_exec_type=rca.action_exec_type
	, report_action_exec=rca.action_exec
from [dbo].[sqlwatch_config_check] cc
inner join [dbo].[sqlwatch_config_check_action] cca
	on cc.check_id = cca.check_id
inner join [dbo].[sqlwatch_config_action] ca
	on ca.action_id = cca.action_id
inner join [dbo].[sqlwatch_config_check_action_template] at
	on at.action_template_id = cca.action_template_id
left join [dbo].[sqlwatch_config_report] cr
	on cr.report_id = ca.action_report_id
left join [dbo].[sqlwatch_config_report_action] ra
	on ra.report_id = cr.report_id
left join [dbo].[sqlwatch_config_action] rca
	on rca.action_id = ra.action_id