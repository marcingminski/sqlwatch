CREATE VIEW [dbo].[vw_sqlwatch_sql_config_for_sqlwatch_repository]
as

select * from sys.configurations
where name in (
	'blocked process threshold (s)', -- should be set to 5s
	'optimize for ad hoc workloads' -- shuold be set to 1 (for grafana mainly)
	)
