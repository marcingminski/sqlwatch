CREATE QUEUE [dbo].[sqlwatch_invoke_5s]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = usp_sqlwatch_internal_activated_activation_5s,
		MAX_QUEUE_READERS = 1,
		EXECUTE AS OWNER
)