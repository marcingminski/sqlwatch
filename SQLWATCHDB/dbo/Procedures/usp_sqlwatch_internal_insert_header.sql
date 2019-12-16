CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_insert_header]
	@snapshot_time_new datetime2(0) OUTPUT ,
	@snapshot_type_id tinyint
as

begin

	set xact_abort on;
	set nocount on;

	declare @report_time datetime2(0),
			@snapshot_time datetime2(0) = GETUTCDATE()

	merge [dbo].[sqlwatch_logger_snapshot_header] as target
	using (
		select
			snapshot_time = @snapshot_time,
			snapshot_type_id = @snapshot_type_id,
			sql_instance = @@SERVERNAME, 
			report_time = dateadd(mi, datepart(TZOFFSET,SYSDATETIMEOFFSET()), (CONVERT([smalldatetime],dateadd(minute,ceiling(datediff(second,(0),CONVERT([time],CONVERT([datetime],@snapshot_time)))/(60.0)),datediff(day,(0),@snapshot_time)))))
	) as source
	on target.snapshot_time = source.snapshot_time
	and target.snapshot_type_id = source.snapshot_type_id
	and target.sql_instance = source.sql_instance

	when not matched then
		insert ([snapshot_time], [snapshot_type_id], [sql_instance], [report_time])
		values (source.[snapshot_time], source.[snapshot_type_id], source.[sql_instance], source.[report_time]);

	select @snapshot_time_new = @snapshot_time
	return 
end