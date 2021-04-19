/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/


Print 'Populating dbo.sqlwatch_config...'

declare @config table (
	config_id int,
	config_name varchar(255),
	config_value smallint
	)
insert into @config (config_id, config_name, config_value)
values
	/*	How many days to keep in the app_log table	*/
	(1	,'Application Log (app_log) retention days'			,7),

	/*	Delete objects that have not been seen by x days	*/
	(2	,'Last Seen Items (date_last_seen) retention days'	,2),

	/*	When action fails, the record is retained in the queue tables with an error status
		How many days should we keep these for?	*/
	(3	,'Action Queue Failed Items retention days'			,30),

	/*	When action succeeds, the rerord is kept in the action table with the success status
		How many days should we keep these for?	*/
	(4	,'Action Queue Success Items retention days'		,7),

	/*	When deleting objects not seen in x days (config=2) how many should we delete at once?	*/
	(5	,'Last Seen Items purge batch size'					,100),

	/*	When applying retention policy, how many header rows should we delete at once?
		Each header could have thousands and more of childs. Use carefuly.	*/
	(6	,'Logger Retention batch size'						,500),

	/*	Should we log info messages or only warnings and errors?	*/
	(7	,'Logger Log Info messages'							,0),

	/*	when check returns null we can log error and fail the job, 
		or log warning and not fail the job.	*/
	(8	,'Error on NULL check value'						,0), 

	/*	when SQLWATCH xes are disabled we will try get data from system_health session if enabled.
		Quite often however system_health session is quite large and it can take couple of minutes ot parse xml
		It is recommended to use SQLWATCH sessions	*/
	(9	,'Fail back to system_health session'				,0)  

	/*	collecting table sizing in databases with large amount of tables can take a long time. Some users report
		~10 minutes collection time for databses with 64k (64000) tables. This parameter will limit the total number
		of tables we collect. */
	--,(10	,'Table utilisation collector table limit'			,1000) --I don't think this has any value now the collecor has been tweaked

	/*	when SQLWATCH xes are disabled we will try get data from system_health session if enabled.
		Quite often however system_health session is quite large and it can take couple of minutes ot parse xml
		It is recommended to use SQLWATCH sessions	*/
	,(11	,'Log flapping checks in the app_log'				,0)
	
	/* how often should we re-run failed checks (CHECK_ERROR) in minutes: */
	,(12	,'Re-run CHECK_ERROR frequency minutes' ,60)

	/* are we using queues? */
	,(13	,'Use Broker Activation' ,0)

	/* Intelligent index collection - Usage Stats Age. Set to -1 to disable. */
	,(14	,'Index Usage Age Hours' ,24)

	/* Intelligent index collection. Max Batch Size. Set to -1 to disable. */
	,(15	,'Index Usage Batch Size' ,1000)

	/* When using [use_baseline] in Checks, the check can raise the error when value is over the baseline, even though is within the recommended setting
	   or it can be more relaxed and not raise alerts untill its above the recommended value. 
	   For example, imagine a system with Readahead pages/sec baselined to 20. The default check would raise an alert if the value was over 25.
	   If we set Baseline mode to strict, we're going to raise alert if the value is over 20 (more than baselined)
	   If we set Baseline mode to relaxed, we're not going to raise alert of the value is over 20 but less than 25 (more than baseline but less than recommended.
	   
	   Normally I would recommend the relaxed baselining so you get less alerts whilst maintaining good performance.
	   Only use stric baselining if you have an agreed SLA or have done it on the back of performance testing etc... */
	,(16	,'Strict Baseline Checks' ,0)

	/* Baseline variance percentage.
	   When setting baseline, we have to allow for some flex, for example, baseline may say 20 Readahead pages/sec.
	   With 20% variance we will not raise alert when the counter hits 24. */
	,(17	,'Baseline Check Threshold Deviation %' ,20)

	/* Check variance percentage.
	   Same as above but for normal checks with no baseline. */
	,(18	,'Default Check Threshold Deviation %' ,10)

	/* This will allow to create checks for each SQL Instance in the central repository as in 
		https://github.com/marcingminski/sqlwatch/issues/250 
		By default, this is disabled. To enable, change to 1 and re-run the "expand checks" procedure or wait 1 hour */
	,(19	,'Expand Checks by SQL Instance' ,0)

	/*	This is similar to Last Seen Items (date_last_seen) retention days
	    but it looks at the [is_record_deletd] flag and removes anything
		with the flag set to 1 and date last seen older than the hours below. 
		The difference is that the last seen is non deterministic - the object
		may exist but we have not checked for it yet. 
		The deleted flag is deterministic and it means we have checked and the 
		object does not exist for sure.

		** THIS IS NOT YET USED BECUASE IT WILL NOT WORK WITH CENTRAL REPOSITORY
		   IF WE DELETE THE RECORD IN SOURCE, THE CENTRAL REPO WILL STILL HAVE IT
		   UNTIL WE RUN A FULL MERGE LOAD WHICH WE WOULD HAVE TO DO PERIODICALLY
		   WHICH IS ALSO QUITE RESOURCE HEAVY AND WOULD REQUIRE LOTS OF .NET CHANGES 
		   IT IS EASIER TO JUST LET THE RECORDS DROP OFF AFTER PERIOD OF LAST_SEEN_DATE 
		   INSTEAD, WE COULD CHANGE THE Last Seen Items (date_last_seen) retention days TO HOURS
		   AND HAVE RECORDS DROP OFF AFTER 1 HOUR OF NOT BEING SEEN - ALTHOUGH THERE'S A RISK THAT IF
		   THE OBJECT EXISTS BUT WE FAIL TO COLLECT IT, OR IF THE CENTRAL REPO IMPORT RUNS RARELY, 
		   THE LAST SEEN WILL NOT BE UPDATED AND MAY BE DELETED PREMATURELY.
		   *** */
	---,(20	,'Purge deleted items after x hours'	,1)

	/* use CLR to collect performance counters. Experimental */
	,(21	,'Use CLR to collect performance counters. This is experimental.' ,0)

	/* Whether to collect execution plans into [dbo].[sqlwatch_meta_plan_handle].
		If enabled execution plans will be pulled as xml into the table */
	,(22	,'Collect Execution Plans and SQL text' ,1)
;

merge dbo.sqlwatch_config as target
using @config as source
on target.config_id = source.config_id
when not matched then 
	insert (config_id, config_name, config_value)
	values (source.config_id, source.config_name, source.config_value);