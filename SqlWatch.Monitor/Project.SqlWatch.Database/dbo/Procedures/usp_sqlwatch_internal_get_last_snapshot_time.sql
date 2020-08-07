CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_get_last_snapshot_time]
	@sql_instance nvarchar(25),
	@snapshot_type_id smallint
AS
	select [snapshot_time] = isnull(max([snapshot_time]),'1970-01-01') from [dbo].[sqlwatch_logger_snapshot_header]
	where [sql_instance]= @sql_instance
	and [snapshot_type_id] = @snapshot_type_id
