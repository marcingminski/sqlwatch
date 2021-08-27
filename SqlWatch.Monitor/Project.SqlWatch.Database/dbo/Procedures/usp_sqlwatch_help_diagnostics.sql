CREATE PROCEDURE [dbo].[usp_sqlwatch_help_diagnostics]
as

select [info] = 'A simple proc to help you see whats going on in the broker and help diagnose problems'

--get queue and service status:
select 
	  [service] = s.name 
	, [queue] = q.name
	, q.is_receive_enabled
	, q.is_activation_enabled
	, q.activation_procedure
	, info = 'is_receive_enabled and is_activation_enabled should both return 1 which means they are active and listening for messages'
from   sys.services s
	inner join sys.service_queues q
		on s.service_queue_id = q.object_id
where q.is_ms_shipped = 0

-- get items in the queue as of now -- handy if you have stuck errors
select *, cast(message_body as xml) 
from [dbo].[sqlwatch_exec];

select [info] = 'This should return a row for each initiator (is_initiator=1) STARTED_OUTBOUND status and all the other rows shuold have status CLOSED (as these have finished and are waiting for SQL to clean them up)
There may be messages that are currently being processed or are awaiting processing but in general they will drop off soon into CLOSED'
select * from sys.conversation_endpoints
where far_service = 'sqlwatch_exec'
order by lifetime desc;