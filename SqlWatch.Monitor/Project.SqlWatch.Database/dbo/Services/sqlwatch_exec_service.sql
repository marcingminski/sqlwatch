CREATE SERVICE [sqlwatch_exec_service]
	ON QUEUE [dbo].[sqlwatch_exec_queue]
	(
		[DEFAULT]
	)
