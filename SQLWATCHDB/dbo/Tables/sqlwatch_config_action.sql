CREATE TABLE [dbo].[sqlwatch_config_action]
(
	[action_id] smallint identity(1,1) not null,
	[action_description] varchar(max),
	[action_exec_type] varchar(50) not null,
	[action_exec] varchar(max) null,
	/* We could have a proc to process specific report and have it run a report via [action_exec] i.e. a simple exec [dbo].[usp_xxx] but having a separate column gives us more control about potential circular references.
	   We must avoid a scenario where a report calls an action that would in turn call the same report, it would be an endless loop. 
	   There are triggers on related columns that prevent circular references 
	   
	   It would also take one more check cycle to complete the report as it would have been queued on the back of the action processing and sent out by the next processing */
	[action_report_id] smallint null,
	[action_enabled] bit not null default 1,
	[date_created] datetime not null constraint df_sqlwatch_config_action_date_created default (getdate()),
	[date_updated] datetime null,

	/* primary key */
	constraint pk_sqlwatch_config_delivery_target primary key clustered ([action_id]),

	/*	foreign key to config report to make sure we only reference valid reports and to prevent deletion of action if
		there is a report using it */
	constraint fk_sqlwatch_config_action_report foreign key ([action_report_id])
		references [dbo].[sqlwatch_config_report] ([report_id]) on delete no action,

	/* check to make sure we always have one of the two and not both and not none */
	constraint chk_sqlwatch_config_media_action check (
			([action_exec] is null and [action_report_id] is not null) 
		or  ([action_exec] is not null and [action_report_id] is null)
		),

	/*	check to only allow given values */
	constraint chk_sqlwatch_config_media_exec check (
		(	[action_exec_type]='T-SQL' 
		or	[action_exec_type]='PowerShell')
		) 
)
go

create trigger dbo.trg_sqlwatch_config_action_updated_U
	on [dbo].[sqlwatch_config_action]
	for update
	as
	begin
		set nocount on;
		update t
			set date_updated = getdate()
		from [dbo].[sqlwatch_config_action] t
		inner join inserted i
		on i.action_id = t.action_id
	end
go

create trigger [dbo].[trg_sqlwatch_config_action_report_circular]
    on [dbo].[sqlwatch_config_action]
    for insert, update
    as
    begin
	    set nocount on
		--prevent circular action to a report.
		--we could create an action that calls report which is configured to call the same action
		--this would result in a never ending loop.		
		if exists (select * 
			from [dbo].[sqlwatch_config_report_action] ra
				inner join inserted ca
				on ca.action_report_id = ra.report_id
				and ca.action_id = ra.action_id) 
			begin
			  raiserror ('You cannot call a report that is calling this action as this would create circular reference.' ,16,1)
			  rollback transaction
			end
    end
go