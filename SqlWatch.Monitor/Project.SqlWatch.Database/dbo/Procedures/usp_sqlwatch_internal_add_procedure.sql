CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_procedure]
as

begin
	set nocount on;
	set xact_abort on;

	declare @sql_instance varchar(32) = [dbo].[ufn_sqlwatch_get_servername]();

	merge [dbo].[sqlwatch_meta_procedure] as target
	using (

		-- whilst I could use sys.procedures to get a list of procedures in each database, I would have to loop through databases
		-- I am happy to just get procedures that have stats as otherwise there would be nothing to monitor anyway
		select
			distinct [procedure_name]=object_schema_name(ps.object_id, ps.database_id) + '.' + object_name(ps.object_id, ps.database_id),
			sd.sqlwatch_database_id,
			[procedure_type] = 'P',
			sql_instance = @sql_instance
		from sys.dm_exec_procedure_stats ps
		inner join dbo.vw_sqlwatch_sys_databases d
			on d.database_id = ps.database_id
		inner join dbo.sqlwatch_meta_database sd
			on sd.database_name = d.name collate database_default
			and sd.database_create_date = d.create_date
		where ps.type = 'P'

		union all

		--every statement executed in sql server goes through the optimiser and gets an execution plan.
		--from that point of view, stored procedures are just sql queries saved in sql server.
		--to make normalisation simpler, we are going to create a dummy procedure that will "hold" ad-hoc queries.
		select [procedure_name] = 'Ad-Hoc Query 3FBE6AA6'
			,  sqlwatch_database_id
			,  [procedure_type] = 'A' --also a made up type to make sure we keep the separate
			,  sql_instance = @sql_instance
		from dbo.sqlwatch_meta_database d

	) as source
	on target.sql_instance = source.sql_instance
	and target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.[procedure_name] = source.[procedure_name] collate database_default

	when matched and datediff(hour,[date_last_seen],getutcdate()) > 24 then
		update set [date_last_seen] = getutcdate()

	when not matched then 
		insert ([sql_instance],[sqlwatch_database_id],[procedure_name],[procedure_type],[date_first_seen],[date_last_seen])
		values (source.[sql_instance],source.[sqlwatch_database_id],source.[procedure_name],source.[procedure_type],getutcdate(),getutcdate());

end