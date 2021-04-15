CREATE FUNCTION [dbo].[ufn_sqlwatch_get_threshold_deviation]
(
	@threshold varchar(50),
	@variance smallint
)
RETURNS decimal(28,5) with schemabinding
AS
BEGIN
	declare @return decimal(28,5),
			@threshold_value decimal(28,5) = [dbo].[ufn_sqlwatch_get_threshold_value](@threshold),
			@threshold_comparator varchar(2) = [dbo].[ufn_sqlwatch_get_threshold_comparator](@threshold);

	if left(@threshold_comparator,1) = '<' 
		begin
			set @return = case when @threshold_value = 0 then ( 0 - ( @variance * 1.0 / 100 ) ) else @threshold_value * ( 1 - ( @variance * 1.0 / 100 ) ) end
		end
	else if left(@threshold_comparator,1) = '>'
		begin
			set @return = case when @threshold_value = 0 then ( 0 + ( @variance * 1.0 / 100 ) ) else @threshold_value * ( 1 + ( @variance * 1.0 / 100 ) ) end 
		end
	else
		--anything else such as = or <> will not no variance
		begin
			set @return = @threshold_value
		end


	return @return;
END
