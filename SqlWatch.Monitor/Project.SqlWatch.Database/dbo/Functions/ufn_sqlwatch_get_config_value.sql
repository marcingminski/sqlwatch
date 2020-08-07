CREATE FUNCTION [dbo].[ufn_sqlwatch_get_config_value] 
(
	@config_id int = null,
	@config_name varchar(255) = null
) 
RETURNS nvarchar(max) with schemabinding
AS
BEGIN
	declare @config_value nvarchar(max)

	if @config_id is not null
		begin
			select @config_value = config_value 
			from dbo.[sqlwatch_config]
			where config_id = @config_id
		end
	else if @config_name is not null
		begin
			select @config_value = config_value 
			from dbo.[sqlwatch_config]
			where config_name = @config_name
		end

	return @config_value
END
