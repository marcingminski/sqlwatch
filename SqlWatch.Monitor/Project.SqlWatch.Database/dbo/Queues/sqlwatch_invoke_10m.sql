CREATE QUEUE [dbo].[sqlwatch_invoke_10m] 
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = usp_sqlwatch_internal_activated_activation_10m,
		MAX_QUEUE_READERS = 1,
		EXECUTE AS OWNER
)
