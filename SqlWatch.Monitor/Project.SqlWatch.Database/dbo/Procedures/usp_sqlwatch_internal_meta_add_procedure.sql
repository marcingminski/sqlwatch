CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_meta_add_procedure]
	@xdoc int,
	@sql_instance varchar(32)
as
begin
	set nocount on;

	select distinct
		[procedure_name],
		[database_name],
		database_create_date,
		[procedure_type] = [type],
		sql_instance = @sql_instance
	into #t
	from openxml (@xdoc, '/CollectionSnapshot/dm_exec_procedure_stats/row',1)
	--from openxml (@xdoc, '/MetaDataSnapshot/sys_procedures/row',1) 
		with (
			[procedure_name] nvarchar(256) 
			,[database_name] nvarchar(128)
			,database_create_date datetime2(3) 
			,type char(2)
		);

	merge [dbo].[sqlwatch_meta_procedure] as target
	using (

		-- whilst I could use sys.procedures to get a list of procedures in each database, I would have to loop through databases
		-- I am happy to just get procedures that have stats as otherwise there would be nothing to monitor anyway
		select 
			[procedure_name],
			sd.sqlwatch_database_id,
			[procedure_type],
			ps.sql_instance
		from #t ps
		inner join dbo.sqlwatch_meta_database sd
			on sd.[database_name] = ps.[database_name] collate database_default
			and sd.database_create_date = ps.database_create_date
			and sd.sql_instance = ps.sql_instance collate database_default

		--every statement executed in sql server goes through the optimiser and gets an execution plan.
		--from that point of view, stored procedures are just sql queries saved in sql server.
		--to make normalisation simpler, we are going to create a dummy procedure that will "hold" ad-hoc queries.
		union all

		select distinct
			[procedure_name] = 'Ad-Hoc Query 3FBE6AA6'
			,  sqlwatch_database_id
			,  [procedure_type] = 'A' --also a made up type to make sure we keep the separate
			,  sql_instance = @sql_instance
		from dbo.sqlwatch_meta_database d
		where sql_instance = @sql_instance

		-- becuase extended events do not provide any way to gather object_id without going back to dmvs, we need an "unknown" option
		-- this is because when we query extended evnts we only get xml as is without parsing and we do not join onto dmvs at source only at target 
		union all

		select distinct
			[procedure_name] = 'Unknown'
			,  sqlwatch_database_id
			,  [procedure_type] = 'X' --also a made up type to make sure we keep the separate
			,  sql_instance = @sql_instance
		from dbo.sqlwatch_meta_database d
		where sql_instance = @sql_instance

	) as source
	on target.sql_instance = source.sql_instance
	and target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.[procedure_name] = source.[procedure_name] collate database_default

	when matched then
		update set [date_last_seen] = getutcdate()

	when not matched then 
		insert ([sql_instance],[sqlwatch_database_id],[procedure_name],[procedure_type],[date_first_seen],[date_last_seen])
		values (source.[sql_instance],source.[sqlwatch_database_id],source.[procedure_name],source.[procedure_type],getutcdate(),getutcdate());

end;