CREATE TABLE [dbo].[sql_perf_mon_config_wait_stats]
(
	[category_name] [nvarchar](40) not null,
	[wait_type] [nvarchar](45) primary key not null,
	[ignore] [bit] not null
)
go

create nonclustered index idx_wait_stats on [dbo].[sql_perf_mon_config_wait_stats](wait_type)