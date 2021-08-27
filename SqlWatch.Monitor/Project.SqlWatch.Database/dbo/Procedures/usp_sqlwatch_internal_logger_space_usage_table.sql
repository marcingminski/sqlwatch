CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_space_usage_table]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@snapshot_time_previous datetime2(0)
as
begin
	set nocount on;

	exec [dbo].[usp_sqlwatch_internal_meta_add_table]
		@xdoc = @xdoc,
		@sql_instance = @sql_instance;

	select
		table_name 
		,[database_name] 
		,database_create_date 
		,row_count 
		,total_pages
		,used_pages 
		,[data_compression] 
		,snapshot_time = @snapshot_time
		,snapshot_type_id = @snapshot_type_id
		,sql_instance = @sql_instance
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/table_space_usage/row',1) 
	with (
		table_name nvarchar(512)
		,[database_name] nvarchar(128)
		,database_create_date datetime2(3)
		,row_count real
		,total_pages real
		,used_pages real
		,[data_compression] tinyint
	)
	option (maxdop 1, keep plan);

	insert into [dbo].[sqlwatch_logger_disk_utilisation_table](
		  sqlwatch_database_id
		, sqlwatch_table_id
		, row_count
		, total_pages
		, used_pages
		, [data_compression]
		, snapshot_type_id
		, snapshot_time
		, sql_instance
		, row_count_delta
		, total_pages_delta
		, used_pages_delta
		)
	select 
		mt.sqlwatch_database_id,
		mt.sqlwatch_table_id,
		t.row_count,
		t.total_pages,
		t.used_pages,
		t.[data_compression],
		t.snapshot_type_id,
		t.snapshot_time,
		t.sql_instance,
		row_count_delta = convert(real,isnull(t.row_count - dt.row_count,0)),
		total_pages_delta = convert(real,isnull(t.total_pages - dt.total_pages,0)),
		used_pages_delta = convert(real,isnull(t.used_pages - dt.used_pages,0))
	from #t t

	inner join [dbo].[sqlwatch_meta_database] mdb
		on mdb.database_name = t.database_name collate database_default
		and mdb.database_create_date = t.database_create_date 
		and mdb.sql_instance = t.sql_instance collate database_default

	inner join [dbo].[sqlwatch_meta_table] mt
		on mt.table_name = t.table_name collate database_default
		and mt.sqlwatch_database_id = mdb.sqlwatch_database_id
		and mt.sql_instance = t.sql_instance collate database_default

	left join [dbo].[sqlwatch_logger_disk_utilisation_table] dt
		on dt.sqlwatch_database_id = mdb.sqlwatch_database_id
		and dt.sql_instance = t.sql_instance
		and dt.sqlwatch_table_id = mt.sqlwatch_table_id
		and dt.snapshot_time = @snapshot_time_previous 

	where t.sql_instance = @sql_instance;
end;