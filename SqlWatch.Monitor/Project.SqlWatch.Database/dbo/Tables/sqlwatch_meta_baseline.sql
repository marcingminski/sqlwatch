CREATE TABLE [dbo].[sqlwatch_meta_baseline]
(
	[baseline_id] smallint not null,
	sql_instance varchar(32) not null,
	baseline_start datetime2(0) not null,
	baseline_end datetime2(0) not null,
	[is_default] bit not null,
	[comments] varchar(max) null,
	[date_updated] datetime not null, 

	constraint pk_sqlwatch_meta_baseline primary key clustered (
		[baseline_id], sql_instance
	),

	constraint fk_sqlwatch_meta_retention_sql_instance foreign key (sql_instance)
		references dbo.sqlwatch_config_sql_instance ([sql_instance]) on delete cascade
)
GO

CREATE UNIQUE INDEX idx_sqlwatch_meta_retention_default
    ON [dbo].[sqlwatch_meta_baseline] (sql_instance, [is_default])
    WHERE [is_default] = 1
GO

CREATE UNIQUE INDEX idx_sqlwatch_meta_baseline_dates
	ON [dbo].[sqlwatch_meta_baseline] (baseline_start, baseline_end, sql_instance)
GO