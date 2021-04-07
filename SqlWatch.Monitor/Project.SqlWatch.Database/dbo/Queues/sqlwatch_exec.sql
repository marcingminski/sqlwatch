CREATE QUEUE [dbo].[sqlwatch_exec]
	WITH STATUS = ON,
	ACTIVATION (
		PROCEDURE_NAME = [dbo].[usp_sqlwatch_internal_exec_activated],
		MAX_QUEUE_READERS = 15,
		EXECUTE AS OWNER
)