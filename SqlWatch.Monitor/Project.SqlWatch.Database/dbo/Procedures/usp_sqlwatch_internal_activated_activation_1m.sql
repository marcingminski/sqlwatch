CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_activation_1m]
AS
EXEC [dbo].[usp_sqlwatch_internal_exec_activated]
	@queue = '[dbo].[sqlwatch_invoke_1m]',
	@procedure_name = '[dbo].[usp_sqlwatch_internal_activated_1m]',
	@timer = 60