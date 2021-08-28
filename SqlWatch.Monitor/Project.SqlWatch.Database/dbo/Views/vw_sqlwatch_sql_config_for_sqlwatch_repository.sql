CREATE VIEW [dbo].[vw_sqlwatch_sql_config_for_sqlwatch_repository]
as

select [configuration_id], [name], [value], [minimum], [maximum], [value_in_use], [description], [is_dynamic], [is_advanced]
from sys.configurations
where name in (
	'blocked process threshold (s)', -- should be set to 5s
	'optimize for ad hoc workloads' -- shuold be set to 1 (for grafana mainly)
	)
	;