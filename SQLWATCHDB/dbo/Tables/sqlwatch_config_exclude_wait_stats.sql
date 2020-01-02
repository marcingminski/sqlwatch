CREATE TABLE [dbo].[sqlwatch_config_exclude_wait_stats]
(
	[wait_type] nvarchar(60) not null,
	constraint pk_sqlwatch_config_exclude_wait_stats primary key (
		[wait_type]
	)
)
go

create trigger dbo.trg_sqlwatch_config_exclude_wait_stats_sanitise
	on [dbo].[sqlwatch_config_exclude_wait_stats]
	for insert, update
	as
	begin
		update w
			set wait_type = rtrim(ltrim(replace(replace(w.wait_type,char(10),''),char(13),''))) 
		from [dbo].[sqlwatch_config_exclude_wait_stats] w
		inner join inserted i
		on i.wait_type = w.wait_type
	end