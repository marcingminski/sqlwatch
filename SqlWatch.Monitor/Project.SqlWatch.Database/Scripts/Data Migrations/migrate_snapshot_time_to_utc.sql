/* Cascading update was implemented in 1.7.7054.1245
   Database must be upgraded to 1.7.7054.1245 before this can be run.

   It will take some time and may blow transaction log. 
   To persist data integrity it has to be done in one transaction

   -------------------------------------------------------------------
   Steps:
    1. Disable and stop ALL SQLWATCH jobs.
	2. Update database to 1.7
	3. Run the below to update dates to UTC
	4. Re-enable ALL SQLWATCH jobs.

*/

		declare @offsethours int = datediff(hour,getdate(),getutcdate())
		declare @error int

		begin tran migrateutc
		update dbo.sqlwatch_logger_snapshot_header with (tablock)
			set snapshot_time = dateadd(hour,@offsethours,snapshot_time)
			set @error = @@ERROR

			if @error = 0
				begin
					print 'Commiting'
					commit tran migrateutc
				end
			else
				begin
					print 'Rolling back'
					rollback tran migrateutc
				end

--if no error:
--commit tran datemigration

--if error encountered:
--rollback tran datemigration
