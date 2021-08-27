CREATE SERVICE [sqlwatch_collector]
	ON QUEUE  [dbo].[sqlwatch_collector]
	(
		[sqlwatch_collector]
	);