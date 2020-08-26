if exists (select * from sys.server_event_sessions where name = 'SQLWATCH_blockers')
	DROP EVENT SESSION [SQLWATCH_blockers] ON SERVER 
	Print 'Dropped Event Session [SQLWATCH_blockers]'
GO

if exists (select * from sys.server_event_sessions where name = 'SQLWATCH_long_queries')
	DROP EVENT SESSION [SQLWATCH_long_queries] ON SERVER 
	Print 'Dropped Event Session [SQLWATCH_long_queries]'
GO

if exists (select * from sys.server_event_sessions where name = 'SQLWATCH_waits')
	DROP EVENT SESSION [SQLWATCH_waits] ON SERVER 
	Print 'Dropped Event Session [SQLWATCH_waits]'
GO

