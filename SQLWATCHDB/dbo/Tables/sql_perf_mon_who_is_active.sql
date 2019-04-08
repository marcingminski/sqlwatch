create table [dbo].[sql_perf_mon_who_is_active] (
	[skey] int identity (-2147483648,1) primary key,
	[snapshot_time] datetime not null,
	[start_time] datetime NOT NULL,[session_id] smallint NOT NULL,[status] varchar(30) NOT NULL,[percent_complete] varchar(30) NULL,[host_name] nvarchar(128) NULL,[database_name] nvarchar(128) NULL,[program_name] nvarchar(128) NULL,[sql_text] xml NULL,[sql_command] xml NULL,[login_name] nvarchar(128) NOT NULL,[open_tran_count] varchar(30) NULL,[wait_info] nvarchar(4000) NULL,[blocking_session_id] smallint NULL,[blocked_session_count] varchar(30) NULL,[CPU] varchar(30) NULL,[used_memory] varchar(30) NULL,[tempdb_current] varchar(30) NULL,[tempdb_allocations] varchar(30) NULL,[reads] varchar(30) NULL,[writes] varchar(30) NULL,[physical_reads] varchar(30) NULL
	,[login_time] datetime NULL,
	[snapshot_type_id] tinyint not null default 1 ,
	constraint fk_sql_perf_mon_who_is_active_snapshot_header foreign key ([snapshot_time],[snapshot_type_id]) references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time],[snapshot_type_id]) on delete cascade ,
	)
go
create nonclustered index idx_whoisactive on [dbo].[sql_perf_mon_who_is_active] ([snapshot_time])
