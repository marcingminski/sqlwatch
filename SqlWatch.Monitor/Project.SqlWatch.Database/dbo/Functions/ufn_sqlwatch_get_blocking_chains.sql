CREATE FUNCTION [dbo].[ufn_sqlwatch_get_blocking_chains] 
(
	@start_date datetime2(0),
	@end_date datetime2(0)
) 

RETURNS @returntable TABLE 
(
	[monitor_loop] [bigint] NULL,
	[event_time] [datetime] NULL,
	[blocking_tree] [nvarchar](4000) NULL,
	[blocking_level] [int] NULL,
	[session_id] [int] NULL,
	[blocking_session_id] [int] NULL,
	[database name] [nvarchar](128) NULL,
	[lock_mode] [nvarchar](128) NULL,
	[blocking_duration_ms] [real] NULL,
	[appname] [nvarchar](128) NULL,
	[hostname] [nvarchar](128) NULL,
	[sql_text] [nvarchar](max) NULL,
	[report_xml] [xml] NULL,
	[sequence] [bigint] NULL
) with schemabinding
AS
BEGIN
		with cte_block_headers AS
		(
			select 
				  session_id = blocking_spid
				, ecid = blocking_ecid
				, monitor_loop
			from [dbo].[sqlwatch_logger_xes_blockers]
			where event_time between @start_date and @end_date

			except
			
			select 
				  session_id = blocked_spid
				, ecid = blocked_ecid
				, monitor_loop
			from [dbo].[sqlwatch_logger_xes_blockers]
			where event_time between @start_date and @end_date
		), 


		cte_blocking_hierarchy AS
		(
			--blockers
			select
					monitor_loop
				,	session_id
				,	ecid
				,	blocking_chain = cast('/' + CAST(session_id as varchar(20)) + '.' + CAST(ecid as varchar(20)) + '/' as varchar(max))
				,	blocking_spid = 0 
				,	blocking_ecid = 0
				,	blocking_level = 0 
				,	blocking_level_t = cast (replicate ( '0', 4 - len(cast(session_id as varchar(10)))) + cast (session_id as varchar(10)) as varchar(max))
			from cte_block_headers
	
			union all
	
			--blocked
			select 
					h.monitor_loop
				,	b.blocked_spid
				,	b.blocked_ecid
				,	cast(h.blocking_chain + CAST(b.blocked_spid as varchar(20)) + '.' + CAST(b.blocked_ecid as varchar(20)) + '/' as varchar(max))
				,	b.blocking_spid
				,	b.blocking_ecid
				,	h.blocking_level+1
				,	blocking_level_t = cast (h.blocking_level_t + right (cast ((1000 + h.session_id) as varchar(100)), 4) as varchar (max))
			from [dbo].[sqlwatch_logger_xes_blockers] b
			join cte_blocking_hierarchy h
				on b.monitor_loop = h.monitor_loop
				and b.blocking_spid = h.session_id
				and b.blocking_ecid = h.ecid
			and b.event_time between @start_date and @end_date
		)
		
		INSERT @returntable
		select 
			  h.monitor_loop
			, event_time = case when h.blocking_level = 0 then bhead.event_time else bproc.event_time end
			, blocking_tree = N'    ' + char (160) + char (160) + replicate (N'|         ', len (blocking_level_t)/4 - 1) +
			  case when (len(blocking_level_t)/4 - 1) = 0
			  then 'HEAD BLOCKER -  '
			  else '|------  ' end
			  + 'SPID '+ case when session_id <=50 then '(SYSTEM)' else '' end + ': ' + cast ( session_id as nvarchar(10))
			, h.blocking_level
			, session_id = h.session_id
			, blocking_session_id = nullif(h.blocking_spid ,0)
			, [database name] = case when bproc.blocking_spid is not null then bproc.[blocked_currentdbname] else bhead.[blocking_currentdbname] end -- isnull(,bht.[database name])
			, [lock_mode] = isnull(bproc.[lockMode], bhead.[lockMode])
			, [blocking_duration_ms] = isnull(bproc.[blocking_duration_ms], bhead.[blocking_duration_ms])
			, [appname]= case when h.blocking_level = 0 then bhead.blocking_clientapp else bproc.blocked_clientapp end
			, [hostname]= case when h.blocking_level = 0 then bhead.[blocking_hostname] else bproc.[blocked_hostname] end
			, [sql_text]= case when h.blocking_level = 0 then bhead.blocking_inputbuff else bproc.[blocked_inputbuff] end
			, report_xml = isnull(bproc.report_xml,bhead.report_xml)
			, sequence = ROW_NUMBER() over (order by h.monitor_loop , h.blocking_chain)
		from cte_blocking_hierarchy h

		--block process details
		left join [dbo].[sqlwatch_logger_xes_blockers] bproc 
			on bproc.monitor_loop = h.monitor_loop
			and bproc.blocked_spid = h.session_id
			and bproc.blocked_ecid = h.ecid
			and bproc.event_time between @start_date and @end_date


		--blocked header details
		outer apply (
			select top 1 
				[monitor_loop]
				, [event_time]
				, [blocked_ecid]
				, [blocked_spid]
				, [blocking_ecid]
				, [blocking_spid]
				, [report_xml]
				, [lockMode]
				, [blocked_clientapp]
				, [blocked_currentdbname]
				, [blocked_hostname]
				, [blocked_loginname]
				, [blocked_inputbuff]
				, [blocking_clientapp]
				, [blocking_currentdbname]
				, [blocking_hostname]
				, [blocking_loginname]
				, [blocking_inputbuff]
				, [blocking_duration_ms]
				, [snapshot_time]
				, [snapshot_type_id]
				, [sql_instance] 
			from [dbo].[sqlwatch_logger_xes_blockers] bheadt 
			where bheadt.monitor_loop = h.monitor_loop
			and bheadt.blocking_spid = h.session_id
			and bheadt.blocking_ecid = h.ecid
			and h.blocking_level=0

		) bhead
	RETURN
END
