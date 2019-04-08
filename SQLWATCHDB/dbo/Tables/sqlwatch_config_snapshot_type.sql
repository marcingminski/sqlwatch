CREATE TABLE [dbo].[sqlwatch_config_snapshot_type]
(
	[snapshot_type_id] tinyint NOT NULL PRIMARY KEY,
	[snapshot_type_desc] varchar(255) not null,
	[snapshot_retention_days] smallint not null,
)
