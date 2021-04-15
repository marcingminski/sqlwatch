CREATE FUNCTION [dbo].[ufn_sqlwatch_get_check_status]
(
	@threshold varchar(100),
	@value decimal(28,5),
	@variance_percent smallint
)
RETURNS bit with schemabinding
AS
BEGIN
	--1: MATCH, 0: NOT MATCH
	declare @variance_percent_dec_max decimal(10,2) = (1+(@variance_percent * 1.0 / 100)),
			@variance_percent_dec_min decimal(10,2) = (1-(@variance_percent * 1.0 / 100)),
			@return bit = 0,
			@threshold_value decimal(28,5) = [dbo].[ufn_sqlwatch_get_threshold_value](@threshold),
			@threshold_comparator varchar(2) = [dbo].[ufn_sqlwatch_get_threshold_comparator](@threshold)

	if @threshold_comparator = '<='
		begin
			if @value  <= @threshold_value * @variance_percent_dec_min
				begin
					set @return = 1
				end
		end
	else if @threshold_comparator = '>='
		begin
			if @value >= @threshold_value * @variance_percent_dec_max
				begin
					set @return = 1
				end
		end
	else if @threshold_comparator = '<>'
		begin
			if @value <> @threshold_value
				begin
					set @return = 1
				end
		end
	else if @threshold_comparator = '<'
		begin
			if @value < @threshold_value * @variance_percent_dec_min
				begin
					set @return = 1
				end
		end
	else if @threshold_comparator = '>'
		begin
			if @value > @threshold_value * @variance_percent_dec_max
				begin
					set @return = 1
				end
		end
	else if @threshold_comparator = '='
		begin
			if @value = @threshold_value
				begin
					set @return = 1
				end
		end
	else if @value = @threshold_value
		begin
				begin
					set @return = 1
				end
		end
	else
		begin
			set @return = 0
		end

	return @return
END
