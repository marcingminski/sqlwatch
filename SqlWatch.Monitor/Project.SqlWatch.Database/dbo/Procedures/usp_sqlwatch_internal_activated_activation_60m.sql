CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_activation_60m]
AS

EXEC [dbo].[usp_sqlwatch_internal_exec_activated]
	@queue = '[dbo].[sqlwatch_invoke_60m]',
	@procedure_name = '[dbo].[usp_sqlwatch_internal_activated_60m]',
	@timer = 3600