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
	@retention_period_days - Not used and only kept for backward compatibility with 1.3.x jobs. 
	It will be removed at some point. The period days is now stored in the snapshot type table
	
  @batch_size -	Batch size of how many rows to delete at once. Default 500.

 Author:
	Marcin Gminski

 Change Log:
	1.0		2019-08		- Marcin Gminski, Initial version
	1.1		2019-11-29	- Marcin Gminski, Ability to only leave most recent snapshot with -1 retention
-------------------------------------------------------------------------------------------------------------------
*/
