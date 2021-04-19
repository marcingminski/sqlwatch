CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_normalise_query_text]
	@plan_handle [utype_plan_handle] readonly,
	@sql_instance varchar(32)
AS
	set nocount on ;
	declare @get_sql_text bit = dbo.ufn_sqlwatch_get_config_value(22,null);

	merge dbo.sqlwatch_meta_query_text as target
	using (
		select s.sql_handle, p.plan_handle, t.text, s.query_hash, sql_instance = @sql_instance
		from (
				select distinct plan_handle
				from @plan_handle
			) p
		cross apply sys.dm_exec_sql_text (p.plan_handle) t 
		inner join sys.dm_exec_query_stats (nolock) s 
		on s.plan_handle = p.plan_handle
		where t.encrypted = 0

		) as source
	on target.sql_handle = source.sql_handle
	and target.sql_instance = source.sql_instance

	when matched then
		update set date_last_seen = getutcdate()
					
	when not matched then
		insert ([sql_instance], [sql_handle], [query_hash], sql_text, date_first_seen, date_last_seen)
		values (source.[sql_instance], source.[sql_handle], source.[query_hash], case when @get_sql_text = 1 then source.text else null end, getutcdate(), getutcdate())
		;
RETURN 0
