CREATE PROCEDURE [dbo].[usp_sqlwatch_logger_whoisactive] (
	@min_session_duration_seconds smallint = 15
	)
AS

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	[usp_sqlwatch_logger_whoisactive]

 Description:
	Collect sp_WhoIsActive output

 Parameters
	
 Author:
	Marcin Gminski

 Change Log:
	1.0		2018-08		- Marcin Gminski, Initial version
	1.1		2020-03-18	- Marcin Gminski, move explicit transaction after header to fix https://github.com/marcingminski/sqlwatch/issues/155
	1.2		2020-04-22	- Marcin Gminski, changed getutcdate() to getdate() in where clause as [start_time] is always local
-------------------------------------------------------------------------------------------------------------------
*/

set xact_abort on

	declare @sp_whoisactive_destination_table varchar(255),
			@snapshot_time datetime,
			@snapshot_type_id tinyint  = 11

	--------------------------------------------------------------------------------------------------------------
	-- sp_whoisactive
	-- Please download and install The Great sp_whoisactive from http://whoisactive.com/ and thank Adam Machanic 
	-- for the numerous times sp_whoisactive saved our backs.
	-- an alternative approach would be to use the SQL deadlock monitor and service broker to record blocking
	-- or deadlocked transactions into a table -- or XE to save to xml - but this could cause trouble parsing large
	-- xmls.
	--------------------------------------------------------------------------------------------------------------
	if object_id('master.dbo.sp_WhoIsActive') is not null or object_id('dbo.sp_WhoIsActive') is not null
		begin
			create table [##SQLWATCH_7A2124DA-B485-4C43-AE04-65D61E6A157C] (
				[snapshot_time] datetime2(0) not null
				,[start_time] datetime NOT NULL
				,[session_id] smallint NOT NULL
				,[status] varchar(30) NOT NULL
				,[percent_complete] varchar(30) NULL
				,[host_name] nvarchar(128) NULL
				,[database_name] nvarchar(128) NULL
				,[program_name] nvarchar(128) NULL
				,[sql_text] xml NULL,[sql_command] xml NULL
				,[login_name] nvarchar(128) NOT NULL
				,[open_tran_count] varchar(30) NULL
				,[wait_info] nvarchar(4000) NULL
				,[blocking_session_id] smallint NULL
				,[blocked_session_count] varchar(30) NULL
				,[CPU] varchar(30) NULL
				,[used_memory] varchar(30) NULL
				,[tempdb_current] varchar(30) NULL
				,[tempdb_allocations] varchar(30) NULL
				,[reads] varchar(30) NULL
				,[writes] varchar(30) NULL
				,[physical_reads] varchar(30) NULL
				,[login_time] datetime NULL
				)

			-- we are running WhoIsActive is very lightweight mode without any additional info and without execution plans
			exec dbo.sp_whoisactive
				 @get_outer_command = 1
				,@output_column_list = '[collection_time][start_time][session_id][status][percent_complete][host_name][database_name][program_name][sql_text][sql_command][login_name][open_tran_count][wait_info][blocking_session_id][blocked_session_count][CPU][used_memory][tempdb_current][tempdb_allocations][reads][writes][physical_reads][login_time]'
				,@find_block_leaders = 1
				,@destination_table = [##SQLWATCH_7A2124DA-B485-4C43-AE04-65D61E6A157C]
			-- the insert to tmp then actual table approach is required mainly to use our
			-- snapshot_time and enforce referential integrity with the header table and
			-- to apply any additional filtering:

			exec [dbo].[usp_sqlwatch_internal_insert_header] 
				@snapshot_time_new = @snapshot_time OUTPUT,
				@snapshot_type_id = @snapshot_type_id

begin tran

			insert into [dbo].[sqlwatch_logger_whoisactive] ([snapshot_time],[start_time],
					 [session_id],[status],[percent_complete],[host_name]
					,[database_name],[program_name],[sql_text],[sql_command],[login_name]
					,[open_tran_count],[wait_info],[blocking_session_id],[blocked_session_count]
					,[CPU],[used_memory],[tempdb_current],[tempdb_allocations],[reads]
					,[writes],[physical_reads],[login_time],[snapshot_type_id],[sql_instance])
			select   [snapshot_time] = @snapshot_time
					,[start_time],[session_id],[status],[percent_complete],[host_name]
					,[database_name],[program_name],[sql_text],[sql_command],[login_name]
					,[open_tran_count],[wait_info],[blocking_session_id],[blocked_session_count]
					,[CPU],[used_memory],[tempdb_current],[tempdb_allocations],[reads]
					,[writes],[physical_reads],[login_time], @snapshot_type_id, @@SERVERNAME
			from [##SQLWATCH_7A2124DA-B485-4C43-AE04-65D61E6A157C]
			-- exclude anything that has been running for less that the desired duration in seconds (default 15)
			where [start_time] < dateadd(s,@min_session_duration_seconds,getdate())
			-- unless its being blocked or is a blocker
			or [blocking_session_id] is not null or [blocked_session_count] > 0
		end
	else
		begin
			print 'sp_WhoIsActive not found.'
		end
commit tran