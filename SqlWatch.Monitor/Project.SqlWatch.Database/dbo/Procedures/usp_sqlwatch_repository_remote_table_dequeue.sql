CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_remote_table_dequeue]
	@sql_instance_out varchar(32) output,
	@object_name_out nvarchar(512) output,
	@load_type_out char(1) output
as
begin

	set xact_abort on;
	begin transaction

		declare @output table (
			sql_instance varchar(32),
			object_name nvarchar(512),
			load_type char(1)
		)

		;with cte_get_queue_item as (
			select top 1 * 
			from [dbo].[sqlwatch_meta_repository_import_queue] x with (readpast)
			where import_status = 'Ready' 
				--items without dependency on parent object:
				or (import_status is null and parent_object_name is null)
				--items with dependency on the parent object where the parent has been processed and dequeued:
				or (import_status is null and not exists (
						select * 
						from [dbo].[sqlwatch_meta_repository_import_queue]
						where object_name = x.parent_object_name
						)
					)
			order by [priority]
			) 
		update c
			set import_status = 'Running', [import_start_time] = SYSDATETIME()
		output deleted.sql_instance, deleted.object_name, deleted.load_type into @output
		from cte_get_queue_item c

	commit transaction

	select 
			@sql_instance_out = sql_instance
		,	@object_name_out = object_name
		,	@load_type_out = load_type
	from @output

return

end