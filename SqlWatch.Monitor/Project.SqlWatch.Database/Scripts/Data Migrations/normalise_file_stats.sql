--!! DISABLE ALL SQLWATCH JOBS, run this script, then upgrade sqlwatch as usual and re-enable jobs !!!

set xact_abort on
begin transaction

update b
	set [logical_file_name] = a.sqlwatch_master_file_id
from [dbo].[sqlwatch_logger_perf_file_stats] b
	inner join [dbo].[sqlwatch_meta_master_file] a
		on b.sqlwatch_database_id = a.sqlwatch_database_id
		and b.sql_instance = a.sql_instance
		and b.[logical_file_name] = a.[file_name]
where isnumeric(b.[sqlwatch_master_file_id]) = 0

--remove master files for non-existing databases:
delete from [dbo].[sqlwatch_logger_perf_file_stats]
where isnumeric([logical_file_name]) = 0

select * from [dbo].[sqlwatch_logger_perf_file_stats]

commit transaction
--rollback transaction