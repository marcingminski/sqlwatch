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
	(2	,'Last Seen Items (date_last_seen) retention days'	,30),

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
	(8	,'Error on NULL check value'						,1), 

	/*	when SQLWATCH xes are disabled we will try get data from system_health session if enabled.
		Quite often however system_health session is quite large and it can take couple of minutes ot parse xml
		It is recommended to use SQLWATCH sessions	*/
	(9	,'Fail back to system_health session'				,0)  

	/*	collecting table sizing in databases with large amount of tables can take a long time. Some users report
		~10 minutes collection time for databses with 64k (64000) tables. This parameter will limit the total number
		of tables we collect. */
	--,(10	,'Table utilisation collector table limit'			,1000) --I don't think this has any value now the collecor has been tweaked
;

merge dbo.sqlwatch_config as target
using @config as source
on target.config_id = source.config_id
when not matched then 
	insert (config_id, config_name, config_value)
	values (source.config_id, source.config_name, source.config_value);