CREATE FUNCTION [dbo].[ufn_sqlwatch_get_check_status]
(
	@threshold varchar(100),
	@value decimal(28,5)
)
RETURNS bit
AS
BEGIN
	RETURN (
		select case 
			when left(@threshold,2) = '<=' then
				case when @value <= convert(decimal(28,5),replace(@threshold,'<=','')) then 1 else 0 end
			when left(@threshold,2) = '>=' then
				case when @value >= convert(decimal(28,5),replace(@threshold,'>=','')) then 1 else 0 end
			when left(@threshold,2) = '<>' then
				case when @value <> convert(decimal(28,5),replace(@threshold,'<>','')) then 1 else 0 end
			when left(@threshold,1) = '>' then
				case when @value > convert(decimal(28,5),replace(@threshold,'>','')) then 1 else 0 end
			when left(@threshold,1) = '<' then
				case when @value < convert(decimal(28,5),replace(@threshold,'<','')) then 1 else 0 end
			when left(@threshold,1) = '=' then
				case when @value = convert(decimal(28,5),replace(@threshold,'=','')) then 1 else 0 end
		else
			case when @value = convert(decimal(28,5),replace(@threshold,'=','')) then 1 else 0 end
		end
	)
END
