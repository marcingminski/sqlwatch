CREATE QUEUE [dbo].[sqlwatch_actions]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = [dbo].[usp_sqlwatch_internal_broker_activated_actions_queue],
		MAX_QUEUE_READERS = 1,
		EXECUTE AS OWNER
);