CREATE FUNCTION [dbo].[ufn_sqlwatch_get_config_value] 
(
	@config_id int = null,
	@p bit = null --backward compatibility as this used to accept two pars.
) 
RETURNS smallint with schemabinding
AS
BEGIN
	return (
			select config_value 
			from dbo.[sqlwatch_config]
			where config_id = @config_id
		);
END;
