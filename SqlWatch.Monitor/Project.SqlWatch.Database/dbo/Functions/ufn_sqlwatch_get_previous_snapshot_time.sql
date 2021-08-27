CREATE FUNCTION [dbo].[ufn_sqlwatch_get_previous_snapshot_time]
(
	@snapshot_type_id tinyint,
	@sql_instance varchar(32),
	@snapshot_time datetime2(0)
)
RETURNS datetime2(0) with schemabinding
AS
BEGIN

return(
	select top 1 snapshot_time=[snapshot_time]
	from [dbo].[sqlwatch_logger_snapshot_header]
	where snapshot_type_id = @snapshot_type_id
	and sql_instance = @sql_instance
	and snapshot_time < @snapshot_time 
	order by [snapshot_time] desc
);
END;