CREATE TYPE [dbo].[utype_sqlwatch_sys_dm_os_memory_clerks] AS TABLE
(
	[type] varchar(60),
	[memory_node_id] smallint,
	[single_pages_kb] bigint,
	[multi_pages_kb] bigint,
	[virtual_memory_reserved_kb] bigint,
	[virtual_memory_committed_kb] bigint,
	[awe_allocated_kb] bigint,
	[shared_memory_reserved_kb] bigint,
	[shared_memory_committed_kb] bigint,
	snapshot_type_id tinyint,
	snapshot_time datetime2(0),
	sql_instance varchar(32)
);
