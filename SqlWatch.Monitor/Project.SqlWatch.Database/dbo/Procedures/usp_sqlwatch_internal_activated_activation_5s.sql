CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_activation_5s]
AS
EXEC [dbo].[usp_sqlwatch_internal_exec_activated]
	@queue = '[dbo].[sqlwatch_invoke_5s]',
	@procedure_name = '[dbo].[usp_sqlwatch_internal_activated_5s]',
	@timer = 5
