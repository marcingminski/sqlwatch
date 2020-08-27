CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_add_procedure]
as

begin
	set nocount on;
	set xact_abort on;

	merge [dbo].[sqlwatch_meta_procedure] as target
	using (

		-- whilst I could use sys.procedures to get a list of procedures in each database, I would have to loop through databases
		-- I am happy to just get procedures that have stats as otherwise there would be nothing to monitor anyway
		select
			distinct [procedure_name]=object_schema_name(ps.object_id, ps.database_id) + '.' + object_name(ps.object_id, ps.database_id),
			sd.sqlwatch_database_id,
			[procedure_type] = 'P',
			sql_instance = [dbo].[ufn_sqlwatch_get_servername]()
		from sys.dm_exec_procedure_stats ps
		inner join dbo.vw_sqlwatch_sys_databases d
			on d.database_id = ps.database_id
		inner join dbo.sqlwatch_meta_database sd
			on sd.database_name = d.name
			and sd.database_create_date = d.create_date
		where ps.type = 'P'

	) as source
	on target.sql_instance = source.sql_instance
	and target.sqlwatch_database_id = source.sqlwatch_database_id
	and target.[procedure_name] = source.[procedure_name]

	when matched and datediff(hour,[date_last_seen],getutcdate()) > 24 then
		update set [date_last_seen] = getutcdate()

	when not matched then 
		insert ([sql_instance],[sqlwatch_database_id],[procedure_name],[procedure_type],[date_first_seen],[date_last_seen])
		values (source.[sql_instance],source.[sqlwatch_database_id],source.[procedure_name],source.[procedure_type],getutcdate(),getutcdate());

end