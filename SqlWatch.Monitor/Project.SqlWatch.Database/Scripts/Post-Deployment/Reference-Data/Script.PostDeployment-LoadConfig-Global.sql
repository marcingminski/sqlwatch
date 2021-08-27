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
	config_value smallint,
	config_description nvarchar(max)
	)
insert into @config (config_id, config_name, config_value, config_description)
values
	/*	How many days to keep in the app_log table	*/
	(1	,'Internal application log retention days'			,2
	,	'How many days worth of logs we should keep in the dbo.sqlwatch_app_log table. 
This table is used to log SQLWATCH''s own errors and messages to help with debugging. 2 days should be plenty.'),

	/*	Delete objects that have not been seen by x days	*/
	(2	,'Last Seen Items (date_last_seen) retention days'	,7
		,'Tells how long we should keep the metadata for deleted objects. 
SQLWATCH keeps track of your databases, tables, jobs and few other things. If you drop the original database or table the date_last_seen will not be updated and eventually any row with date_last_seen will be purged after this many days.'),

	/*	When action fails, the record is retained in the queue tables with an error status
		How many days should we keep these for?	*/
	(3	,'Action Queue Failed Items retention days'			,30
		,NULL),

	/*	When action succeeds, the rerord is kept in the action table with the success status
		How many days should we keep these for?	*/
	(4	,'Action Queue Success Items retention days'		,7
		,NULL),

	/*	When deleting objects not seen in x days (config=2) how many should we delete at once?	*/
	(5	,'Last Seen Items purge batch size'					,100
		,'Tells how many rows we should delete in a single batch when removing metadata based on the "last_seen_field". 
Normally you would not be dropping many objects very often but if you do, you can tweak this value if needed. Becuase SQLWATCH relies on referential integrity and cascade deletes to automatically delete dependant data, this parameter is critical to make sure deleting data does not impact your server.
A good example would be deleting a database from dbo.sqlwatch_meta_database. A single rows in this table will have children rows in meta_table, meta_index and so on. Deleting a single row from the meta_database table will result in deleting hundreds of thousands or rows from dependant tables hene the need to limit the impact of this action.
Note that when deleting from dbo.sqlwatch_meta_database we automatically limit the batch size to 1. This parameter will apply to any other meta table.'),

	/*	When applying retention policy, how many header rows should we delete at once?
		Each header could have thousands and more of childs. Use carefuly.	*/
	(6	,'Logger Retention batch size'						,500
		,'Tells how many rows we should delete as part of a single batch when removing logger data as part of the data retention routine.
Becuase SQLWATCH relies on referential integrity and cascade deletes to automatically delete data, deleting even a single header row could translate to thousands of rows deleted from dependant tables.
This is crucial in making sure retention does not impact your server'),

	/*	Should we log info messages or only warnings and errors?	*/
	(7	,'Internal application logging level.'	,1
		,'Follows the .NET logginc standard (0 - Off, 1 - Error, 2 - Warning, 3 - Info, 4 - Verbose). In normal operation level 2 should be enough to highlight errors and warnings.
Info level can make the "dbo.sqlwatch_app_log" table grow very fast but it will show you informative messages related to the SQLWATCH operation. Verbose will impact performance and should only be enabled to debug problems.
Note this DOES NOT affect logging levels for exe applications.'),

	/*	when check returns null we can log error and fail the job, 
		or log warning and not fail the job.	*/
	(8	,'Error on NULL check value'						,0
		,'When checks return NULL value, we can either throw an error or warning. By default we return warning. Checks that return NULL could indicate that the data is not being collected.'), 

	/*	when SQLWATCH xes are disabled we will try get data from system_health session if enabled.
		Quite often however system_health session is quite large and it can take couple of minutes ot parse xml
		It is recommended to use SQLWATCH sessions	*/
	(9	,'Fail back to system_health session'				,0
		,'It is advisable to have SQLWATCH XE Sessions enabled as they have been designed to store minimal data for high frequency offloads to minimise CPU usage whilst parsing XML. However, if you cannot have SQLWATCH XES enabled, we will attempt to get as much data as we can from the default system_health session.
Be aware that parsing the default session can be CPU expensive so we will not do it by default.' )  

	/*	collecting table sizing in databases with large amount of tables can take a long time. Some users report
		~10 minutes collection time for databses with 64k (64000) tables. This parameter will limit the total number
		of tables we collect. */
	--,(10	,'Table utilisation collector table limit'			,1000) --I don't think this has any value now the collecor has been tweaked

	/*	when SQLWATCH xes are disabled we will try get data from system_health session if enabled.
		Quite often however system_health session is quite large and it can take couple of minutes ot parse xml
		It is recommended to use SQLWATCH sessions	*/
	,(11	,'Log flapping checks in the app_log'				,0
			,NULL)
	
	/* how often should we re-run failed checks (CHECK_ERROR) in minutes: */
	,(12	,'Re-run CHECK_ERROR frequency minutes' ,60
			,'When checks return CHECK_ERROR it means there was an error in the check code. We should delay re-checking failed checks as there is no point running failling code.
Whilst the code will not fix itself, if we disabled the check it would never re-run even after deploying new, fixed version.')

	/* are we using queues? */
	--,(13	,'Use Broker Activation' ,0
	--		,NULL)

	/* Intelligent index collection - Usage Stats Age. Set to -1 to disable. */
	,(14	,'Index Usage Age Hours' ,24
			,NULL)

	/* Intelligent index collection. Max Batch Size. Set to -1 to disable. */
	,(15	,'Index Usage Batch Size' ,1000
			,NULL)

	/* When using [use_baseline] in Checks, the check can raise the error when value is over the baseline, even though is within the recommended setting
	   or it can be more relaxed and not raise alerts untill its above the recommended value. 
	   For example, imagine a system with Readahead pages/sec baselined to 20. The default check would raise an alert if the value was over 25.
	   If we set Baseline mode to strict, we're going to raise alert if the value is over 20 (more than baselined)
	   If we set Baseline mode to relaxed, we're not going to raise alert of the value is over 20 but less than 25 (more than baseline but less than recommended.
	   
	   Normally I would recommend the relaxed baselining so you get less alerts whilst maintaining good performance.
	   Only use stric baselining if you have an agreed SLA or have done it on the back of performance testing etc... */
	,(16	,'Strict Baseline Checks' ,0
			,NULL)

	/* Baseline variance percentage.
	   When setting baseline, we have to allow for some flex, for example, baseline may say 20 Readahead pages/sec.
	   With 20% variance we will not raise alert when the counter hits 24. */
	,(17	,'Baseline Check Threshold Deviation %' ,20
			,NULL)

	/* Check variance percentage.
	   Same as above but for normal checks with no baseline. */
	,(18	,'Default Check Threshold Deviation %' ,10
			,NULL)

	/* This will allow to create checks for each SQL Instance in the central repository as in 
		https://github.com/marcingminski/sqlwatch/issues/250 
		By default, this is disabled. To enable, change to 1 and re-run the "expand checks" procedure or wait 1 hour */
	,(19	,'Expand Checks by SQL Instance' ,0
			,NULL)

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
	--,(21	,'Use CLR to collect performance counters. This is experimental.' ,0
	--		,NULL)

	/* Whether to collect all execution plans  */
	,(22	,'Collect Execution Plans' , 1
			,NULL)

	/* Whether to store raw event data in xml from xes. Handy for debugging on in cases where we werent able to capture query plan,
		the event data in most cases will have sql text*/
	,(23	,'Store RAW XML Event Data' , 1
			,NULL)

	/* Managed by SqlWatchCollect. If set to 1, performance collection via broker will be disabled. */
	,(24	,'Using SqlWatchCollect' , 0
			,'Tells whether we are using SqlWatchCollect.exe to collecto performance data. When set to 1 the internal performance collector invoked via broker will be disabled.
Note this will be set to when we run SqlWatchCollect.exe. If you stop using the .exe and want to go back to local collection via broker, set it back to 0.')

	,(25	,'Is Collector Queue Enabled', 1
			,'This configuration item will update automatically. We are using it to minimise querying sys tables before starting each conversation.')

	,(26	,'Long Running Request Time (s)', 5
			,'How long a query should run for before we log it as "long running". Note that we only check every 5 seconds so if you say 7 seconds, We will not catch it.')

;

merge dbo.sqlwatch_config as target
using @config as source
on target.config_id = source.config_id

when matched then
	update set 
		config_name = source.config_name
		,config_description = source.config_description

when not matched then 
	insert (config_id, config_name, config_value, config_description )
	values (source.config_id, source.config_name, source.config_value, source.config_description);