CREATE QUEUE [dbo].[sqlwatch_invoke_1m]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = usp_sqlwatch_internal_activated_activation_1m,
		MAX_QUEUE_READERS = 1,
		EXECUTE AS OWNER
)