CREATE TABLE [dbo].[sqlwatch_config_snapshot_type]
(
	[snapshot_type_id] tinyint NOT NULL,
	[snapshot_type_desc] varchar(255) not null,
	[snapshot_retention_days] smallint not null,
	--[snapshot_retention_days_trend] smallint constraint df_sqlwatch_config_snapshot_type_days_trend default (730),
	[collect] bit not null constraint df_sqlwatch_config_snapshot_type_collection default 1,
	[timer_id] uniqueidentifier null,

	constraint pk_sqlwatch_config_snapshot_type primary key clustered (
		[snapshot_type_id]
	),

	constraint fk_sqlwatch_config_snapshot_type_timer
		foreign key (timer_id)
		references dbo.[sqlwatch_config_timer] (timer_id)
);