CREATE TABLE [dbo].[sqlwatch_config]
(
	[config_id] int not null,
	[config_name] varchar(255) not null,
	[config_value] smallint not null,
	constraint pk_sqlwatch_config primary key clustered (config_id)
)
go

create unique nonclustered index idx_sqlwatch_sys_config_name 
	on dbo.[sqlwatch_config] (config_name) include (config_value)
