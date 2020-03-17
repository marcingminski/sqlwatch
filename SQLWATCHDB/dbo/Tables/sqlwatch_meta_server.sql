CREATE TABLE [dbo].[sqlwatch_meta_server]
(
	[physical_name] nvarchar(128),
	[servername] varchar(32) not null,
	[service_name] nvarchar(128),
	[local_net_address] varchar(50),
	[local_tcp_port] varchar(50),
	[utc_offset_minutes] int not null constraint df_sqlwatch_meta_server_offset default (DATEDIFF(mi, GETUTCDATE(), GETDATE())),
	[sql_version] nvarchar(2048),
	constraint pk_sqlwatch_meta_server primary key clustered (
		[servername]
		),
	constraint fk_sqlwatch_meta_config_sql_instance foreign key ([servername])
		references dbo.sqlwatch_config_sql_instance ([sql_instance]) on delete cascade
)
go

-- https://github.com/marcingminski/sqlwatch/issues/153
create trigger dbo.trg_sqlwatch_meta_server_delete_import_status
	on [dbo].[sqlwatch_meta_server]
	for delete
	as
	begin
		set nocount on;
		set xact_abort on;

		delete from [dbo].[sqlwatch_meta_repository_import_status]
		where [sql_instance] in (
			select [sql_instance]
			from deleted
			)
	end
go

--https://support.microsoft.com/en-us/help/321843/error-message-1785-occurs-when-you-create-a-foreign-key-constraint-tha
create trigger dbo.trg_sqlwatch_meta_server_delete_header
	on [dbo].[sqlwatch_meta_server]
	for delete
	as
	begin
		set nocount on;
		set xact_abort on;

		declare @rowcount bigint = 1,
				@rowcounttotal bigint = 0,
				@message varchar(512) = ''

		declare @deleted_instances table (
			sql_instance varchar(32)
			)

		insert into @deleted_instances
		select [servername] from deleted

		Print 'Begin batch delete from [dbo].[sqlwatch_logger_snapshot_header]. Terminating this batch may lead to orphaned records being left in child tables.
If this happens, please re-add sql_instance to the config and meta tables and re-do the deletion.'
		while @rowcount > 0
			begin
				delete top (100) h
				from [dbo].[sqlwatch_logger_snapshot_header] h
				inner join @deleted_instances d
					on h.sql_instance = d.sql_instance

				set @rowcount = @@ROWCOUNT
				set @rowcounttotal = @rowcounttotal + @rowcount
				set @message = '	Deleted ' + convert(varchar(10),@rowcount) + ' rows in a batch.'
				raiserror (@message,10,1)
			end
		Print 'End batch delete from [dbo].[sqlwatch_logger_snapshot_header].
Deleted ' + convert(varchar(10),@rowcounttotal) + ' rows in total.'
	end