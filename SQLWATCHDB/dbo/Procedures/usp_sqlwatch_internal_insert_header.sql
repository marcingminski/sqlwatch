CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_insert_header]
	@snapshot_time_new datetime2(0) OUTPUT ,
	@snapshot_type_id tinyint
as

begin

	set xact_abort on;
	set nocount on;

	declare @snapshot_time datetime2(0),
			@sql_instance varchar(32),
			@lockresult int

	/*	We have to make sure we only access the header table in a single thread in order to "allocate" snapshot times.
		They are datetime2(0) which means accureate to 1 second. If we have multithreaded procesing (repository) we may
		be having many threads trying to insert the same @snapshot_time.
		The database is in RCSI which makes blocking difficult but in this case we actually want blocking and queueing.  */
	set transaction isolation level serializable
	begin transaction
	set lock_timeout 1000; 
	--exec @lockresult = master.dbo.sp_getapplock @Resource = 'usp_sqlwatch_internal_insert_header', @LockMode = 'Exclusive'

	--if @lockresult >= 0
	--	begin
			select @snapshot_time = convert(datetime2(0),GETUTCDATE()), @sql_instance = @@SERVERNAME

			insert into [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [snapshot_type_id], [sql_instance], [report_time]) 
				select  [snapshot_time] = @snapshot_time,
						[snapshot_type_id] = @snapshot_type_id,
						[sql_instance] = @@SERVERNAME, 
						[report_time] = dateadd(mi, datepart(TZOFFSET,SYSDATETIMEOFFSET()), (CONVERT([smalldatetime],dateadd(minute,ceiling(datediff(second,(0),CONVERT([time],CONVERT([datetime],@snapshot_time)))/(60.0)),datediff(day,(0),@snapshot_time)))))
				where not exists (
					select * from [dbo].[sqlwatch_logger_snapshot_header] t
					where t.sql_instance = @sql_instance
					and t.snapshot_type_id = @snapshot_type_id
					and t.snapshot_time = @snapshot_time
					)

			--exec @lockresult = master.dbo.sp_releaseapplock @Resource = 'usp_sqlwatch_internal_insert_header'
		--end
			
	if @@TRANCOUNT > 0
		commit transaction

	if @snapshot_time is not null
		begin	
			select @snapshot_time_new = @snapshot_time
			return 
		end
	else
		begin
			raiserror ('Fatal error: Variable @snapshot_time must not be null. Possible issue with acquiring an application lock.',16,1)
		end
end