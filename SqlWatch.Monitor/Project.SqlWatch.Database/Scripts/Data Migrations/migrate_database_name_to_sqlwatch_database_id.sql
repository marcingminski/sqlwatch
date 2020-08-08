--!!! STOP ALL SQLWATCH-* JOBS, run the script, then run the sqlwatch deployment and re-enable job

set xact_abort on;

begin transaction 

--drop fks, they will be recreated during upgrade:
alter table [dbo].[sqlwatch_logger_disk_utilisation_database] drop constraint [FK_logger_disk_util_database_database]
alter table [dbo].[sqlwatch_logger_index_missing] drop constraint [fk_logger_missing_indexes_database]
alter table [dbo].[sqlwatch_logger_index_usage_stats] drop constraint [fk_index_usage_stats_database]
alter table [dbo].[sqlwatch_logger_index_usage_stats_histogram] drop constraint [fk_logger_index_stats_histogram_database]
alter table [dbo].[sqlwatch_logger_perf_file_stats] drop constraint [fk_pk_sql_perf_mon_file_stats_database]
alter table [dbo].[sqlwatch_logger_perf_master_files] drop constraint [FK_sql_perf_mon_master_files_db]

--migrade database_name to sqlwatch_database_id. column will be renamed during upgrade, leave as is for the time being:
update b
	set database_name = a.sqlwatch_database_id
from [dbo].[sqlwatch_logger_disk_utilisation_database] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

update b
	set database_name = a.sqlwatch_database_id 
from [dbo].[sqlwatch_logger_index_missing_stats] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

update b
	set database_name = a.sqlwatch_database_id 
from [dbo].[sqlwatch_logger_index_usage_stats] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

update b
	set database_name = a.sqlwatch_database_id 
from [dbo].[sqlwatch_logger_index_histogram] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

update b
	set database_name = a.sqlwatch_database_id 
from [dbo].[sqlwatch_logger_perf_file_stats] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

update b
	set database_name = a.sqlwatch_database_id 
from [dbo].[sqlwatch_meta_master_file] b
	inner join [dbo].[sqlwatch_meta_database] a
		on a.database_name = b.database_name
		and a.database_create_date = b.database_create_date
		and a.sql_instance = b.sql_instance
where isnumeric(b.database_name) = 0

commit transaction
--rollback transaction

--select * from [dbo].[sqlwatch_logger_disk_utilisation_database]
--select * from [dbo].[sqlwatch_logger_index_missing]
--select * from [dbo].[sqlwatch_logger_index_usage_stats]
--select * from [dbo].[sqlwatch_logger_index_usage_stats_histogram]
--select * from [dbo].[sqlwatch_logger_perf_file_stats]