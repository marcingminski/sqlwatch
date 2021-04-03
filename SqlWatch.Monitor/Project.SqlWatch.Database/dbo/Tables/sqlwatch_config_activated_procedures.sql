CREATE TABLE [dbo].[sqlwatch_config_activated_procedures]
(
	[procedure_name] nvarchar(128),
	[timer_seconds] int,

	constraint pk_sqlwatch_config_activated_procedures primary key clustered (
		[procedure_name]
	)
)
