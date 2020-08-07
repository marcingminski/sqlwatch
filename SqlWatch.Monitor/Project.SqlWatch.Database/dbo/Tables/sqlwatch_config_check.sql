CREATE TABLE [dbo].[sqlwatch_config_check]
(
	[check_id] smallint identity (1,1) not null,
	[check_name] nvarchar(50) not null,
	[check_description] nvarchar(2048) null,
	[check_query] nvarchar(max) not null, --the sql query to execute to check for value, the return should be a one row one value which will be compared against thresholds. 
	[check_frequency_minutes] smallint null, --how often to run this check, by default the ALERT agent job runs every 2 minutes but we may not want to run all checks every 2 minutes.
	[check_threshold_warning] varchar(100) null, --warning is optional
	[check_threshold_critical] varchar(100) not null, --critical is not optional
	[check_enabled] bit not null default 1, --if enabled the check will be processed
	[date_created] datetime not null constraint df_sqlwatch_config_check_date_created default (getdate()),
	[date_updated] datetime null,
	[ignore_flapping] bit not null constraint df_sqlwatch_config_check_flapping default (0),

	/* primary key */
	constraint pk_sqlwatch_config_check primary key clustered ([check_id])
)
go

/*	do not use negative IDs for user checks as they may be overwritten with the next release.
	with that being said, if user updates default check we populate updated date and never
	touch it again */
create trigger dbo.trg_sqlwatch_config_check_id_I
	on [dbo].[sqlwatch_config_check]
	for insert
	as
	begin
		set nocount on;
		if exists (select * from inserted where check_id < 0)
			begin
				raiserror('Negative IDs are for checks shipped with SQLWATCH and may be overwritten in the future.',16,1)
				if @@TRANCOUNT > 0
					ROLLBACK TRAN
			end
	end
go

/*	maintain meta table withouth having to run extra DML every time checks run
	this will also ensure integrity without having FKs between meta and config
	(we cannot have FK as meta gets imported into central repo and config is not designed
	to be imported into central repo) 
	This trigger will only fire when new checks are added or modified */
create trigger dbo.trg_sqlwatch_config_check_meta_IU
	on [dbo].[sqlwatch_config_check]
	for insert, update
	as
	begin
		set nocount on;
		merge dbo.sqlwatch_meta_check  as target
		using inserted as source
		on target.check_id = source.check_id
		and target.sql_instance = @@SERVERNAME

		when not matched 
			then insert (
			  [sql_instance], [check_id], [check_name], [check_description], [check_query]
			, [check_frequency_minutes], [check_threshold_warning], [check_threshold_critical])
			values (@@SERVERNAME, source.[check_id], source.[check_name], source.[check_description], source.[check_query]
			, source.[check_frequency_minutes], source.[check_threshold_warning], source.[check_threshold_critical])

		when matched
			then update
				set 
				  [check_name] = source.[check_name]
				, [check_description] = source.[check_description]
				, [check_query] = source.[check_query]
				, [check_frequency_minutes] = source.[check_frequency_minutes]
				, [check_threshold_warning] = source.[check_threshold_warning]
				, [check_threshold_critical] = source.[check_threshold_critical]
				
		;
	end
go

create trigger dbo.trg_sqlwatch_config_check_meta_D
	on [dbo].[sqlwatch_config_check]
	for delete
	as
	begin
		set nocount on;
		delete t
		from dbo.sqlwatch_meta_check t
		where t.check_id in (select check_id from deleted)
		and t.check_id not in (select check_id from inserted)
		and t.sql_instance = @@SERVERNAME
	end
go

create trigger dbo.trg_sqlwatch_config_check_U
	on [dbo].[sqlwatch_config_check]
	for update
	as
	begin
		set nocount on;
		update t
			set date_updated = getutcdate()
		from [dbo].[sqlwatch_config_check] t
		inner join inserted i
			on i.[check_id] = t.[check_id]
	end
go