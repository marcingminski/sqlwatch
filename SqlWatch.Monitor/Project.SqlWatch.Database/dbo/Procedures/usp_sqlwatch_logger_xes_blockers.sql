CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_xes_blockers]
AS

set nocount on;
set xact_abort on;

if [dbo].[ufn_sqlwatch_get_product_version]('major') >= 11
	begin

		declare @execution_count bigint = 0,
				@session_name nvarchar(64) = 'SQLWATCH_Blockers',
				@snapshot_time datetime,
				@snapshot_type_id tinyint = 9,
				@filename varchar(8000),
				@sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

		-- even though we may not collect any xes data
		-- we are still going to create a snapshot becausae it makes it easier to then show data on the dashboard as 0 rathern than "No Data"

		exec [dbo].[usp_sqlwatch_internal_insert_header] 
			@snapshot_time_new = @snapshot_time OUTPUT,
			@snapshot_type_id = @snapshot_type_id

		--if the session has not triggered since last run there will not be any new records so we may not bother querying it
		set @execution_count = [dbo].[ufn_sqlwatch_get_xes_exec_count] ( @session_name, 0 )
		if  @execution_count > [dbo].[ufn_sqlwatch_get_xes_exec_count] ( @session_name, 1 )
			begin
				--update execution count
				exec [dbo].[usp_sqlwatch_internal_update_xes_query_count] 
					  @session_name = @session_name
					, @execution_count = @execution_count


				/*  For this to work you must enable blocked process monitor */

				/*  The below code, whilst not directly copied, is inspired by and based on Michael J Stewart blocked process report.
					I have learned how to approach this problem from Michael's blog. Please add his blog to your favourites as its a really good SQL Server Knowledgebase.

					http://michaeljswart.com/2016/02/look-at-blocked-process-reports-collected-with-extended-events/
					https://github.com/mjswart/sqlblockedprocesses licensed under MIT
					https://github.com/mjswart/sqlblockedprocesses/blob/master/LICENSE

					MIT License

					Copyright (c) 2018 mjswart

					Permission is hereby granted, free of charge, to any person obtaining a copy
					of this software and associated documentation files (the "Software"), to deal
					in the Software without restriction, including without limitation the rights
					to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
					copies of the Software, and to permit persons to whom the Software is
					furnished to do so, subject to the following conditions:

					The above copyright notice and this permission notice shall be included in all
					copies or substantial portions of the Software.

					THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
					IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
					FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
					AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
					LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
					OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
					SOFTWARE.	
				
				*/

				declare @event_data table (event_data xml)

				insert into @event_data
				select cast(event_data as xml)
				from sys.fn_xe_file_target_read_file ('SQLWATCH_blockers*.xel', null, null, null) t

				begin transaction

				insert into dbo.sqlwatch_logger_xes_blockers (
						  [monitor_loop]
						, [lockMode]
						, [blocked_spid]
						, [blocked_ecid]
						, [blocked_clientapp]
						, [blocked_currentdbname]
						, [blocked_hostname]
						, [blocked_loginname]
						, [blocked_inputbuff]
						, [blocking_spid]
						, [blocking_ecid]
						, [blocking_clientapp]
						, [blocking_currentdbname]
						, [blocking_hostname]
						, [blocking_loginname]
						, [blocking_inputbuff]
						, [event_time]
						, [blocking_duration_ms]
						, [report_xml]
						, [snapshot_time]
						, snapshot_type_id
						, sql_instance
				)
				
				select
						  [blocked_process_report_details].[monitor_loop]
						, [blocked_process_report_details].[lockMode]
						, [blocked_process_report_details].[blocked_spid]
						, [blocked_process_report_details].[blocked_ecid]
						, [blocked_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name]([blocked_process_report_details].[blocked_clientapp], null)
						, [blocked_process_report_details].[blocked_currentdbname]
						, [blocked_process_report_details].[blocked_hostname]
						, [blocked_process_report_details].[blocked_loginname]
						, [blocked_process_report_details].[blocked_inputbuff]
						, [blocked_process_report_details].[blocking_spid]
						, [blocked_process_report_details].[blocking_ecid]
						, [blocking_clientapp] = [dbo].[ufn_sqlwatch_parse_job_name]([blocked_process_report_details].[blocking_clientapp],null)
						, [blocked_process_report_details].[blocking_currentdbname]
						, [blocked_process_report_details].[blocking_hostname]
						, [blocked_process_report_details].[blocking_loginname]
						, [blocked_process_report_details].[blocking_inputbuff]

						, [bp_report_xml].[event_date]
						, convert(real,[bp_report_xml].[blocking_duration_ms])
						, [bp_report_xml].[bp_report_xml]	

						, [snapshot_time] = @snapshot_time
						, snapshot_type_id = @snapshot_type_id
						, sql_instance = @sql_instance
				from @event_data xet

				cross apply ( 
					select 
					xet.event_data 
				) AS event_data ([xml])

				cross apply  (
					select
						 -- extract blocked process xml contained in the event session xml
						  event_date = event_data.[xml].value('(event/@timestamp)[1]', 'datetime')
						, blocking_duration_ms = event_data.[xml].value('(//event/data[@name="duration"]/value)[1]', 'bigint')/1000
						, bp_report_xml = event_data.[xml].query('//event/data/value/blocked-process-report')
				) as bp_report_xml

				cross apply (
					select 

							-- generic
						  [monitor_loop] = bp_report_xml.value('(//@monitorLoop)[1]', 'nvarchar(100)')
						, [lockMode]= bp_report_xml.value('(./blocked-process-report/blocked-process/process/@lockMode)[1]', 'nvarchar(128)')
						  
						 	-- blocked-process-report
						, [blocked_spid] = bp_report_xml.value('(./blocked-process-report/blocked-process/process/@spid)[1]', 'int')
						, [blocked_ecid] = bp_report_xml.value('(./blocked-process-report/blocked-process/process/@ecid)[1]', 'int')
						, [blocked_clientapp] = bp_report_xml.value('(./blocked-process-report/blocked-process/process/@clientapp)[1]', 'nvarchar(128)')
						, [blocked_currentdbname] = nullif(bp_report_xml.value('(./blocked-process-report/blocked-process/process/@currentdbname)[1]', 'nvarchar(128)'),'')
						, [blocked_hostname] = nullif(bp_report_xml.value('(./blocked-process-report/blocked-process/process/@hostname)[1]', 'nvarchar(128)'),'')
						, [blocked_loginname] = nullif(bp_report_xml.value('(./blocked-process-report/blocked-process/process/@loginname)[1]', 'nvarchar(128)'),'')
						, [blocked_inputbuff] = nullif(bp_report_xml.value('(./blocked-process-report/blocked-process/process/inputbuf)[1]', 'nvarchar(max)'),'')
						  
							-- blocking-process
						, [blocking_spid] = bp_report_xml.value('(./blocked-process-report/blocking-process/process/@spid)[1]', 'int')
						, [blocking_ecid] = bp_report_xml.value('(./blocked-process-report/blocking-process/process/@ecid)[1]', 'int')
						, [blocking_clientapp] = bp_report_xml.value('(./blocked-process-report/blocking-process/process/@clientapp)[1]', 'nvarchar(128)')
						, [blocking_currentdbname] = nullif(bp_report_xml.value('(./blocked-process-report/blocking-process/process/@currentdbname)[1]', 'nvarchar(128)'),'')
						, [blocking_hostname] = nullif(bp_report_xml.value('(./blocked-process-report/blocking-process/process/@hostname)[1]', 'nvarchar(128)'),'')
						, [blocking_loginname] = nullif(bp_report_xml.value('(./blocked-process-report/blocking-process/process/@loginname)[1]', 'nvarchar(128)'),'')
						, [blocking_inputbuff] = nullif(bp_report_xml.value('(./blocked-process-report/blocking-process/process/inputbuf)[1]', 'nvarchar(max)'),'')
						  
					) as blocked_process_report_details

				left join dbo.sqlwatch_logger_xes_blockers b
				on b.event_time = [bp_report_xml].[event_date]
				and b.monitor_loop = [blocked_process_report_details].[monitor_loop]
				and b.[blocked_spid] = [blocked_process_report_details].[blocked_spid]
				and b.[blocked_ecid] = [blocked_process_report_details].[blocked_ecid]
				and b.[blocking_spid] = [blocked_process_report_details].[blocking_spid]
				and b.[blocking_ecid] = [blocked_process_report_details].[blocking_ecid]


				where [blocked_process_report_details].[blocking_spid] is not null
				and [blocked_process_report_details].[blocked_spid] is not null

				-- skip existing rows:
				and b.monitor_loop is null
				and b.event_time is null
				and b.blocked_spid is null

				option (maxdop 1, keep plan)

				commit tran

			end
	end
else
	print 'Product version must be 11 or higher'

