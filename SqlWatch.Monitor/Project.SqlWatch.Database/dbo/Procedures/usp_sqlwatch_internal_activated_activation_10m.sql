CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_activation_10m]
AS
EXEC [dbo].[usp_sqlwatch_internal_exec_activated]
	@queue = '[dbo].[sqlwatch_invoke_10m]',
	@procedure_name = '[dbo].[usp_sqlwatch_internal_activated_10m]',
	@timer = 600
