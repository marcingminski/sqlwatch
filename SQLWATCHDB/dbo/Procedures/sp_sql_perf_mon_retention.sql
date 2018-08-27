CREATE PROCEDURE [dbo].[sp_sql_perf_mon_retention](
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
		from dbo.sql_perf_mon_snapshot_header with (readpast)
		where datediff(day,snapshot_time,getdate()) > @retention_period_days
		set @row_count = @@ROWCOUNT
		commit tran
	end
go