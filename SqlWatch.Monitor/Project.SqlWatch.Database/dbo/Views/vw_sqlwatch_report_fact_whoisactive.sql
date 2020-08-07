CREATE VIEW [dbo].[vw_sqlwatch_report_fact_whoisactive] with schemabinding
as
SELECT [sqlwatch_whoisactive_record_id]
      ,report_time
      ,[start_time]
      ,[session_id]
      ,[status]
      ,[percent_complete]
      ,[host_name]
      ,[database_name]
      ,[program_name]
      ,[sql_text] = replace(replace(convert(nvarchar(max),[sql_text]),'<?query --
',''),'
--?>','')
      ,[sql_command] = replace(replace(convert(nvarchar(max),[sql_command]),'<?query --
',''),'
--?>','')
      ,[login_name]
      ,[open_tran_count]=convert(real,[open_tran_count])
      ,[wait_info]
      ,[blocking_session_id]=convert(bigint,[blocking_session_id])
      ,[blocked_session_count]=convert(bigint,[blocked_session_count])
      ,[CPU] = convert(real,replace([CPU],',',''))
      ,[used_memory] = convert(real,replace([used_memory],',',''))
      ,[tempdb_current] = convert(real,replace([tempdb_current],',',''))
      ,[tempdb_allocations] = convert(real,replace([tempdb_allocations],',',''))
      ,[reads] = convert(real,replace([reads],',',''))
      ,[writes] = convert(real,replace([writes],',',''))
      ,[physical_reads] = convert(real,replace([physical_reads],',',''))
      ,[login_time]
      ,d.[sql_instance]
	  ,[wait_type] = case when [wait_info] like '%:%' then substring(substring([wait_info],patindex('%)%',[wait_info])+1,len([wait_info])),1,patindex('%:%',substring([wait_info],patindex('%)%',[wait_info]),len([wait_info])))-2) else substring([wait_info],patindex('%)%',[wait_info])+1,len([wait_info])) end
	  ,[wait_time_ms] = convert(bigint,substring([wait_info],2,patindex('%)%',[wait_info])-4))
      ,[end_time] = case 
				when convert(bigint,substring([wait_info],2,patindex('%)%',[wait_info])-4)) >= 2147483648 then
					/* Dateadd can only handle integers, for very long running processes we have to drop resolution and convert to seconds to avoid overlfow. 
					   https://github.com/marcingminski/sqlwatch/issues/148 */
					dateadd(s,(convert(bigint,substring([wait_info],2,patindex('%)%',[wait_info])-4))/1000.0),convert(datetime,ltrim([start_time])))
				else
					dateadd(ms,convert(bigint,substring([wait_info],2,patindex('%)%',[wait_info])-4)),convert(datetime,ltrim([start_time])))
				end
      ,[last_collection] = case when ROW_NUMBER() over (partition by [session_id], [start_time] order by d.[snapshot_time] desc) = 1 then 1 else 0 end
      ,[session_id_global] = dense_rank() over (order by [start_time], [session_id])
      ,[lapsed_seconds] = datediff(s,[start_time],d.[snapshot_time])
	 --for backward compatibility with existing pbi, this column will become report_time as we could be aggregating many snapshots in a report_period
	, d.snapshot_time
	, d.snapshot_type_id
  FROM [dbo].[sqlwatch_logger_whoisactive] d
  	inner join dbo.sqlwatch_logger_snapshot_header h
		on  h.snapshot_time = d.[snapshot_time]
		and h.snapshot_type_id = d.snapshot_type_id
		and h.sql_instance = d.sql_instance
