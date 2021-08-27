--CREATE FUNCTION [dbo].[ufn_sqlwatch_get_xes_exec_count]
--(
--	@session_name nvarchar(64),
--	@mode bit = null
--)
--RETURNS bigint
--AS
--BEGIN
--		--the mode parameter will allow us to run this function in two ways:
--		--0 get the count from the xe session
--		--1 get the count from our stage table for comparison

--		declare @execution_count bigint = 0,
--				@address varbinary(8),
--				@return varchar(10);

--		--we're getting session address in a separate batch
--		--becuase when we join xe_sessions with xe_session_targets
--		--the execution goes up to 500ms. two batches run in 4 ms.

--		if @mode = 0
--			begin
--				select @address = address 
--				from sys.dm_xe_sessions
--				where name = @session_name
--				option (keepfixed plan)

--				select @execution_count = isnull(execution_count,0)
--				from sys.dm_xe_session_targets t
--				where event_session_address = @address
--				and target_name = 'event_file'
--				option (keepfixed plan)
--			end
--		else
--			begin
--				select @execution_count = execution_count
--				from [dbo].[sqlwatch_stage_xes_exec_count]
--				where session_name = @session_name
--				option (keep plan)
--			end

--	RETURN @execution_count
--END
