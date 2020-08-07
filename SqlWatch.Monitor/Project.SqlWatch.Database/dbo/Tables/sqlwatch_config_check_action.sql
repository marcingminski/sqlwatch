CREATE TABLE [dbo].[sqlwatch_config_check_action]
(
	[check_id] smallint not null,
	[action_id] smallint not null,
	[action_every_failure] bit not null constraint df_sqlwatch_config_check_action_every_failure default (0), --whether to send email with every value change as long as its a fail. i.e. we may want to be alerted of every job failure rather than only the first one
	[action_recovery] bit not null constraint df_sqlwatch_config_check_action_recovery default (1), --whether to send a "recovery" email after check has gone back to OK. just to let us know that there is nothing to worry anymore
	[action_repeat_period_minutes] smallint null, --how often to repeat the trigger i.e. if we are low on disk we may want a daily reminder, not just one alert
	[action_hourly_limit] tinyint not null constraint df_sqlwatch_config_check_action_hourly_limit default (2), --no more than 2 alerts per hour, of each alert
	[action_template_id] smallint not null,
	[date_created] datetime not null constraint df_sqlwatch_config_check_action_date_created default (getutcdate()),
	[date_updated] datetime null,

	/*	primary key */
	constraint pk_sqlwatch_config_check_action primary key clustered ([check_id], [action_id]),

	/*  foreign key to config check to make sure we are only referencing valid checks and to 
		delete assosiation with actions when the check is deleted */
	constraint fk_sqlwatch_config_check_action_check foreign key ([check_id])
		references [dbo].[sqlwatch_config_check] ([check_id]) on delete cascade,

	/*	foreign key to action to make sure we only have valid actions and to prevent deletion
		of action if there are checks using it */
	constraint fk_sqlwatch_config_check_action_action foreign key ([action_id])
		references [dbo].[sqlwatch_config_action] ( [action_id] ) on delete no action,

	/*	foreign key to action template to make sure we have a valida template and to prevent deletion
		of the template if there are actions using it */
	constraint fk_sqlwatch_config_check_action_template foreign key ([action_template_id])
		references [dbo].[sqlwatch_config_check_action_template] ([action_template_id])
)
go

create trigger dbo.trg_sqlwatch_config_check_action_updated_date_U
	on [dbo].[sqlwatch_config_check_action]
	for update
	as
	begin
		set nocount on;
		update t
			set [date_updated] = getutcdate()
		from [dbo].[sqlwatch_config_check_action] t
		inner join inserted i
			on i.[check_id] = t.[check_id]
			and i.[action_id] = t.[action_id]
	end
go

create trigger dbo.trg_sqlwatch_config_check_action_D
	on [dbo].[sqlwatch_config_action]
	for delete
	as
	begin
		set nocount on;
		set xact_abort on;

		delete t
		from [dbo].[sqlwatch_logger_check_action] t
		inner join deleted d
			on t.action_id = d.action_id
			and t.sql_instance = @@SERVERNAME;
	end
go
