CREATE TABLE [dbo].[sqlwatch_meta_check]
(
	[sql_instance] varchar(32) not null constraint df_sqlwatch_meta_check_sql_instance default (@@SERVERNAME),

	/* repeat columns from sqlwatch_config_check so we can detach it from config and retain all the information when sending to central repo */
	[check_id] smallint not null,
	[check_name] nvarchar(50)  null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) null, 
	[check_frequency_minutes] smallint null, 
	[check_threshold_warning] varchar(100) null, 
	[check_threshold_critical] varchar(100) null, 

	[last_check_date] datetime null,
	[last_check_value] real null,
	[last_check_status] varchar(50) null,
	[last_status_change_date] datetime null,

	/*	primary key */
	constraint pk_sqlwatch_meta_alert primary key clustered ([sql_instance], [check_id]),

	/*	foreign key to meta server */
	constraint fk_sqlwatch_meta_check_server foreign key (sql_instance)
		references dbo.sqlwatch_meta_server (servername) on delete cascade

	/*	foreign key to the config check to make sure we only have valid records in the meta 
		and to process deletion when the check is deleted
	
		we have to detach meta from the config as it would make it impossible to import into 
		central repository without also importing all the config tables.
		meta_check will need to maintain itself same way as all other meta tables */
	--constraint fk_sqlwatch_meta_alert_check foreign key ([check_id])
	--	references [dbo].[sqlwatch_config_check] ([check_id]) on delete cascade
)
go

create trigger trg_sqlwatch_meta_check_delete
	on [dbo].[sqlwatch_meta_check]
	for delete
	as
	begin
		set nocount on;
		set xact_abort on;

		/* prevent orphan meta records and abort deletion if there is an existing check_id in config */
		if exists (
			select * 
			from [dbo].[sqlwatch_config_check]
			where check_id in (select check_id from deleted)
			and check_id not in (select check_id from inserted)
			and exists (select * from deleted where sql_instance = @@SERVERNAME)
			)
			begin
				raiserror('Unable to delete meta record as there are existing config records. Please delete config first',16,1)
				if @@TRANCOUNT > 0
					begin
						rollback transaction
					end
			end
			
	end
