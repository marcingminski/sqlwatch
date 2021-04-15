CREATE FUNCTION [dbo].[ufn_sqlwatch_get_check_baseline]
(
	@check_id bigint,
	@baseline_id smallint = null,
	@sql_instance varchar(32)
)
RETURNS real with schemabinding
AS
BEGIN
	declare @default_baseline_id smallint

	if @baseline_id is null
		begin
			select @baseline_id = baseline_id 
			from [dbo].[sqlwatch_meta_baseline]
			where is_default = 1
			and sql_instance = @sql_instance
		end

		return (
		select baseline_check_value=avg(check_value)
		from [dbo].[sqlwatch_logger_check] lc

		inner join [dbo].[sqlwatch_meta_snapshot_header_baseline] b
			on b.snapshot_time = lc.snapshot_time
			and b.sql_instance = lc.sql_instance
			and b.snapshot_type_id = lc.snapshot_type_id

		where b.baseline_id = @baseline_id
			and lc.check_id = @check_id
		)
END
