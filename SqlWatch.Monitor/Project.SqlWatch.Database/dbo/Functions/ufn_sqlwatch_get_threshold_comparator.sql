CREATE FUNCTION [dbo].[ufn_sqlwatch_get_threshold_comparator]
(
	@threshold varchar(50)
)
RETURNS varchar(2) with schemabinding
AS
BEGIN
	declare @return varchar(2)

	if left(@threshold,2) = '<='
		begin
			set @return = '<='
		end
	else if left(@threshold,2) = '>='
		begin
			set @return = '>='
		end
	else if left(@threshold,2) = '<>'
		begin
			set @return =  '<>'
		end
	else if left(@threshold,1) = '<'
		begin
			set @return = '<'
		end
	else if left(@threshold,1) = '>'
		begin
			set @return ='>'
		end
	else if left(@threshold,1) = '='
		begin
			set @return = '='
		end

		return @return
END
