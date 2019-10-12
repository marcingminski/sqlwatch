--DIRABLE COLLECTOR JOB!!!

CREATE TABLE [dbo].[sqlwatch_meta_wait_stats]
(
	[sql_instance] nvarchar(25) not null,
	[wait_type] nvarchar(60) not null, 
	[wait_type_id] smallint identity (-32768,1) not null,
	constraint pk_sqlwatch_meta_wait_stats primary key (
		[sql_instance], [wait_type]
		)
)

insert into [dbo].[sqlwatch_meta_wait_stats] ([sql_instance], [wait_type])
select distinct @@SERVERNAME, dm.[wait_type]
from sys.dm_os_wait_stats dm
left join [dbo].[sqlwatch_meta_wait_stats] ws
	on ws.[sql_instance] = @@SERVERNAME
	and ws.[wait_type] = dm.[wait_type] collate database_default
where ws.[wait_type] is null

select * into [dbo].[sqlwatch_logger_perf_os_wait_stats_bak]
from [dbo].[sqlwatch_logger_perf_os_wait_stats]

select ws.[wait_type_id], wait_type_id, 
	waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms, snapshot_time, snapshot_type_id, ws.sql_instance
into #sqlwatch_logger_perf_os_wait_stats
from [dbo].[sqlwatch_logger_perf_os_wait_stats] ws
			inner join [dbo].[sqlwatch_meta_wait_stats] ms
			on ms.sql_instance = ws.sql_instance
			and ms.wait_type = ws.[wait_type_id]

begin tran fred

delete from [dbo].[sqlwatch_logger_perf_os_wait_stats]

insert into [dbo].[sqlwatch_logger_perf_os_wait_stats]
select  wait_type_id, 
	waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms, snapshot_time, snapshot_type_id, sql_instance
from #sqlwatch_logger_perf_os_wait_stats

ALTER TABLE [dbo].[sqlwatch_logger_perf_os_wait_stats] DROP CONSTRAINT [pk_sql_perf_mon_wait_stats] WITH ( ONLINE = OFF )
GO
DROP INDEX [idx_sqlwatch_wait_stats_001] ON [dbo].[sqlwatch_logger_perf_os_wait_stats]
GO



alter table [dbo].[sqlwatch_logger_perf_os_wait_stats] alter column [wait_type_id] smallint not null


ALTER TABLE [dbo].[sqlwatch_logger_perf_os_wait_stats] ADD  CONSTRAINT [pk_sql_perf_mon_wait_stats] PRIMARY KEY CLUSTERED 
(
	[snapshot_time] ASC,
	[snapshot_type_id] ASC,
	[sql_instance] ASC,
	[wait_type_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_sqlwatch_wait_stats_001] ON [dbo].[sqlwatch_logger_perf_os_wait_stats]
(
	[sql_instance] ASC
)
INCLUDE([wait_type_id],[waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms],[snapshot_time],[snapshot_type_id]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO