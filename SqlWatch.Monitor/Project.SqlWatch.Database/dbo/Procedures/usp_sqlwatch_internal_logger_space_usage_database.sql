CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_space_usage_database]
	@xdoc int,
	@snapshot_time datetime2(0),
	@snapshot_type_id tinyint,
	@sql_instance varchar(32)
as

begin
	set nocount on;

	insert into [dbo].[sqlwatch_logger_disk_utilisation_database] (
		  swd.[sqlwatch_database_id]
		, [database_size_bytes] 
		, [unallocated_space_bytes] 
		, [reserved_bytes] 
		, [data_bytes] 
		, [index_size_bytes] 
		, [unused_bytes] 
		, [log_size_total_bytes]
		, [log_size_used_bytes]
		, snapshot_time
		, snapshot_type_id
		, sql_instance

		, [unallocated_extent_page_count]
		, [allocated_extent_page_count]
		, [version_store_reserved_page_count]
		, [user_object_reserved_page_count]
		, [internal_object_reserved_page_count]
		, [mixed_extent_page_count]
	)
	select 
		  swd.[sqlwatch_database_id]
		, [database_size_bytes] 
		, [unallocated_space_bytes] 
		, [reserved_bytes] 
		, [data_bytes] 
		, [index_size_bytes] 
		, [unused_bytes] 

		, su.[total_log_size_in_bytes]
		, su.[used_log_space_in_bytes]
		, @snapshot_time
		, @snapshot_type_id
		, @sql_instance

		, su.[unallocated_extent_page_count]
		, su.[allocated_extent_page_count]
		, su.[version_store_reserved_page_count]
		, su.[user_object_reserved_page_count]
		, su.[internal_object_reserved_page_count]
		, su.[mixed_extent_page_count]

	from openxml (@xdoc, '/CollectionSnapshot/database_space_usage/row',1) 
	with (
			[database_name] nvarchar(128)
			, database_create_date datetime2(3)
			, database_size_bytes bigint
			, unallocated_space_bytes bigint
			, reserved_bytes bigint
			, data_bytes bigint
			, index_size_bytes bigint
			, unused_bytes bigint

			, total_log_size_in_bytes bigint
			, used_log_space_in_bytes bigint
			, unallocated_extent_page_count bigint
			, allocated_extent_page_count bigint 
			, version_store_reserved_page_count bigint
			, user_object_reserved_page_count bigint 
			, internal_object_reserved_page_count bigint
			, mixed_extent_page_count nvarchar(128)
	) su

	inner join [dbo].[sqlwatch_meta_database] swd
		on swd.[database_name] = su.[database_name] collate database_default
		and swd.[database_create_date] = su.[database_create_date]
		and swd.sql_instance = @sql_instance

	left join [dbo].[sqlwatch_config_exclude_database] ed
		on swd.[database_name] like ed.database_name_pattern
		and ed.snapshot_type_id = @snapshot_type_id

	where ed.snapshot_type_id is null
	option (maxdop 1, keep plan);
end;