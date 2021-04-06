CREATE QUEUE [dbo].[sqlwatch_exec_async]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = usp_sqlwatch_internal_activated_activation_async,
		MAX_QUEUE_READERS = 15,
		EXECUTE AS OWNER
)