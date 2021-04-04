CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_activated_activation_async]
AS

PRINT 'usp_sqlwatch_internal_activated_activation_async'
EXEC [dbo].[usp_sqlwatch_internal_exec_activated]
	@queue = '[dbo].[sqlwatch_exec_async]',
	@procedure_name = null