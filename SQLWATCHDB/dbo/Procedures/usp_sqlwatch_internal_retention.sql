CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_retention](
	--this is only kept for backward compatibility so we dont have to change existing jobs for now:
	@retention_period_days smallint = 7, 
	@batch_size smallint = 500
	)
as

set nocount on;
declare @row_count int = 1
while @row_count > 0
	begin
		begin tran
			delete top (@batch_size) 
			from dbo.sql_perf_mon_snapshot_header
			where exists (
					select sh.[snapshot_time], sh.snapshot_type_id, st.snapshot_retention_days
					from dbo.sql_perf_mon_snapshot_header sh
					inner join [dbo].[sql_perf_mon_config_snapshot_type] st
						on sh.[snapshot_type_id] = st.[snapshot_type_id]
					where datediff(day,sh.snapshot_time,getdate()) > st.snapshot_retention_days
					and dbo.sql_perf_mon_snapshot_header.[snapshot_time] = sh.[snapshot_time]
					and dbo.sql_perf_mon_snapshot_header.snapshot_type_id = sh.snapshot_type_id
			)
			set @row_count = @@ROWCOUNT
		commit tran
	end
go