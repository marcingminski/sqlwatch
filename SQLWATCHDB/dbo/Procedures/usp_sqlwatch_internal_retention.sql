CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_retention](
	@retention_period_days smallint = 7, 
	@batch_size smallint = 500
	)
as

/*
-------------------------------------------------------------------------------------------------------------------
 Procedure:
	usp_sqlwatch_internal_retention

 Description:
	Process retention of each snapshot based on the snapshot_retention_days.
	Deleting from the header [sqlwatch_logger_snapshot_header] will also delete from child tables through cascade
	action. To avoid blowing transaction logs we have running batches of 500 rows by default. This can be adjusted
	by passing different batch size as a parameter. This procedure should run every hour so there is never too 
	much to delete. Do not leave this to run once a day or once a week, the more often it runs the less it will do.
	Average execution does not exceed few seconds.

 Parameters
	@retention_period_days	-	Not used and only kept for backward compatibility with 1.3.x jobs. 
								It will be removed at some point. The period days is now stored in the snapshot type table
	@batch_size				-	Batch size of how many rows to delete at once. Default 500.

 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-08		- Marcin Gminski, Initial version
	1.1		2019-11-29	- Marcin Gminski, Ability to only leave most recent snapshot with -1 retention
-------------------------------------------------------------------------------------------------------------------
*/
set nocount on;
declare @row_count int = 1
while @row_count > 0
	begin
		begin tran
			delete 
			from dbo.[sqlwatch_logger_snapshot_header]
			where exists (
					select top (@batch_size) sh.[snapshot_time], sh.snapshot_type_id, st.snapshot_retention_days
					from dbo.[sqlwatch_logger_snapshot_header] sh
					inner join [dbo].[sqlwatch_config_snapshot_type] st
						on sh.[snapshot_type_id] = st.[snapshot_type_id]

					/*	2019-11-29, in version 2.2 I have introduced new retention type of -1 which means:
					    "delete all but the most recent snapshot". This is handy for keeping only the most recent
						snapshot of index stats or histograms which otherwise can get quite large. In order to 
						achieve that, we had to add a join and find the most recent snapshot for each type. 
						
						This change has increased execution time from ~40ms to ~150ms on the same table sizes.
						However, to counter act that, I have moved TOP into the select rather than delete
						which brings it down from ~150ms to ~4ms so much quicker than the original	*/
					left join (
						 select snapshot_time=max(snapshot_time), sh2.snapshot_type_id, sh2.sql_instance
						 from dbo.[sqlwatch_logger_snapshot_header] sh2
						 inner join [dbo].[sqlwatch_config_snapshot_type] st2
							on sh2.[snapshot_type_id] = st2.[snapshot_type_id]
						 where st2.snapshot_retention_days = -1
						 group by sh2.snapshot_type_id, sh2.sql_instance
						) m
						on m.snapshot_type_id = st.snapshot_type_id
						and m.snapshot_time = sh.report_time
						and m.sql_instance = sh.sql_instance

					where sh.snapshot_time < case 
						when st.snapshot_retention_days = -1 then m.snapshot_time 
						else dateadd(day,-st.snapshot_retention_days,getutcdate()) end
					and dbo.[sqlwatch_logger_snapshot_header].[snapshot_time] = sh.[snapshot_time]
					and dbo.[sqlwatch_logger_snapshot_header].snapshot_type_id = sh.snapshot_type_id
			)
			set @row_count = @@ROWCOUNT
		commit tran
	end
go