CREATE FUNCTION [dbo].[ufn_sqlwatch_get_check_status]
(
	@threshold varchar(100),
	@value decimal(28,5),
	@variance_percent smallint
)
RETURNS bit
AS
BEGIN
	declare @variance_percent_dec_max decimal(10,2) = @variance_percent * 0.01 + 1,
			@variance_percent_dec_min decimal(10,2) = @variance_percent * 0.01

	RETURN (
		select 
			case
				-- less or equal
				when left(@threshold,2) = '<=' then
					case
						when @value <= convert(decimal(28,5),replace(@threshold,'<=','')) * @variance_percent_dec_min
						then 1 else 0 end

				-- less than
				when left(@threshold,1) = '<' then
					case 
						when @value < convert(decimal(28,5),replace(@threshold,'<','')) * @variance_percent_dec_min
						then 1 else 0 end
					
				-- greater or equal
				when left(@threshold,2) = '>=' then
					case 
						when @value >= convert(decimal(28,5),replace(@threshold,'>=','')) * @variance_percent_dec_max
						then 1 else 0 end
				
				-- greater than
				when left(@threshold,1) = '>' then
					case 
						when @value > convert(decimal(28,5),replace(@threshold,'>','')) * @variance_percent_dec_max
						then 1 else 0 end
				
				-- exact mismatch -- no variance
				when left(@threshold,2) = '<>' then
					case when @value <> convert(decimal(28,5),replace(@threshold,'<>','')) then 1 else 0 end
		
				-- exact match -- no variance
				when left(@threshold,1) = '=' then
					case when @value = convert(decimal(28,5),replace(@threshold,'=','')) then 1 else 0 end
			else
				-- exact match -- no variance
				case when @value = convert(decimal(28,5),replace(@threshold,'=','')) then 1 else 0 end
			end

	)
END
