CREATE TABLE [dbo].[sqlwatch_meta_repository_import_thread]
(
	thread_name varchar(128) not null,
	thread_start_time datetime2(7) not null,
	constraint pk_sqlwatch_meta_repository_import_thread primary key clustered  (
		thread_name
		)
)
