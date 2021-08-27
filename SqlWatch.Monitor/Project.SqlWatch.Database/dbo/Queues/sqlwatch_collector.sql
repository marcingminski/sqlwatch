CREATE QUEUE [dbo].[sqlwatch_collector]
	WITH STATUS = ON
	,ACTIVATION (
		PROCEDURE_NAME = [dbo].[usp_sqlwatch_internal_broker_activated_collector_queue],
		MAX_QUEUE_READERS = 8,
		EXECUTE AS OWNER
);