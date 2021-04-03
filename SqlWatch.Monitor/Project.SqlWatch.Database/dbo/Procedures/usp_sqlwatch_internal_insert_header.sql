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

	declare @snapshot_time_output table (
		snapshot_time datetime2(0)
	)

	begin transaction

		set @snapshot_time = convert(datetime2(0),GETUTCDATE());

		insert into [dbo].[sqlwatch_logger_snapshot_header] ([snapshot_time], [snapshot_type_id], [sql_instance], [report_time]) 
		output inserted.[snapshot_time] into @snapshot_time_output ( snapshot_time )
		select  [snapshot_time] = @snapshot_time,
				[snapshot_type_id] = @snapshot_type_id,
				[sql_instance] = dbo.ufn_sqlwatch_get_servername(), 
				[report_time] = dateadd(mi, datepart(TZOFFSET,SYSDATETIMEOFFSET()), (CONVERT([smalldatetime],dateadd(minute,ceiling(datediff(second,(0),CONVERT([time],CONVERT([datetime],@snapshot_time)))/(60.0)),datediff(day,(0),@snapshot_time)))))
			
	if @@TRANCOUNT > 0
		commit transaction

	select @snapshot_time_new = snapshot_time from @snapshot_time_output

	if @snapshot_time_new  is null
		begin
			raiserror ('Fatal error: Variable @snapshot_time must not be null. Possible issue with acquiring an application lock.',16,1)
		end
end