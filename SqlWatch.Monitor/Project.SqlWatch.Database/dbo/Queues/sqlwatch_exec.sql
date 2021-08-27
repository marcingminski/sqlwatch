CREATE QUEUE [dbo].[sqlwatch_exec]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = [dbo].[usp_sqlwatch_internal_broker_activated_exec_queue],
		MAX_QUEUE_READERS = 16,
		EXECUTE AS OWNER
)