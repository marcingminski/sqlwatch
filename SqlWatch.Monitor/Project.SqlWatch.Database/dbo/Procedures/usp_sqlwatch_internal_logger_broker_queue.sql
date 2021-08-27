CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_logger_broker_queue]
as
begin
	--only to be run on the local repository
	--it MUST not use the queue as otherwise if the queue grows it wont show any data until this message is cleared
	declare @snapshot_time_new datetime2(0),
			@snapshot_type_id tinyint = 35,
			@sql_instance varchar(32) = @@SERVERNAME;


    exec [dbo].[usp_sqlwatch_internal_logger_new_header] 
	        @snapshot_time_new = @snapshot_time_new OUTPUT,
	        @snapshot_type_id = @snapshot_type_id,
            @sql_instance = @sql_instance;

	insert into [dbo].[sqlwatch_logger_broker_queue_size] (
		[snapshot_time],
		[snapshot_type_id],
		[sql_instance],
		[queue_name],
		[message_count]	
	)

	select
		[snapshot_time] = @snapshot_time_new,
		[snapshot_type_id] = @snapshot_type_id,
		[sql_instance] = @sql_instance,
		[queue_name] = 'sqlwatch_collector',
		[message_count]	= count(*)
	from [dbo].[sqlwatch_collector] WITH(NOLOCK)

	union all

	select
		[snapshot_time] = @snapshot_time_new,
		[snapshot_type_id] = @snapshot_type_id,
		[sql_instance] = @sql_instance,
		[queue_name] = 'sqlwatch_actions',
		[message_count]	= count(*)
	from [dbo].[sqlwatch_collector] WITH(NOLOCK);

end;