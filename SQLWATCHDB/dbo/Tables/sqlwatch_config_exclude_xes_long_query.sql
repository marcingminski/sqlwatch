CREATE TABLE [dbo].[sqlwatch_config_exclude_xes_long_query]
(
	[exclusion_id] tinyint not null identity(1,1) ,
	[statement] varchar(8000),
	[sql_text] varchar(8000),
	[username] varchar(255),
	[client_hostname] [varchar](255) NULL,
	[client_app_name] [varchar](255) NULL,
	constraint pk_sqlwatch_config_exclude_xes_long_query primary key clustered (
		[exclusion_id]
	),
	constraint uq_sqlwatch_config_exclude_xes_long_query unique (
		[statement],[sql_text],[username],[client_hostname],[client_app_name]
	)
)