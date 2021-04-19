CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_normalise_plan_handle]
	@plan_handle utype_plan_handle readonly,
	@sql_instance varchar(32)
AS
	set nocount on;
	declare @get_plan_xml bit = dbo.ufn_sqlwatch_get_config_value(22,null);

	merge dbo.sqlwatch_meta_query_plan as target
	using (
		select s.sql_handle, p.plan_handle, s.query_plan_hash, sql_instance = @sql_instance, mq.[sqlwatch_query_id], t.query_plan
		from (
			select distinct plan_handle
			from @plan_handle
			) p
		cross apply sys.dm_exec_query_plan (p.plan_handle) t
						
		inner join sys.dm_exec_query_stats s
		on s.plan_handle = p.plan_handle

		inner join dbo.sqlwatch_meta_query_text mq
		on mq.sql_instance = @sql_instance
		and mq.[sql_handle] = s.sql_handle

		where t.encrypted = 0

		) as source

	on target.[plan_handle] = source.[plan_handle]
	and target.sql_instance = source.sql_instance

	when matched then 
		update set date_last_seen = getutcdate()

	when not matched then
		insert ([sqlwatch_query_id], [sql_instance], [plan_handle], [query_plan_hash], [query_plan], [date_first_seen], [date_last_seen])
		values (source.[sqlwatch_query_id], source.[sql_instance], source.[plan_handle], source.[query_plan_hash], case when @get_plan_xml = 1 then source.[query_plan] else null end, getutcdate(), getutcdate())
	;
RETURN 0
