CREATE TABLE [dbo].[sqlwatch_config_baseline]
(
	baseline_id smallint not null identity(1,1),
	baseline_start datetime2(0) not null,
	baseline_end datetime2(0) not null,
	[is_default] bit not null,
	[comments] varchar(max) null,

	constraint pk_sqlwatch_config_baseline 
		primary key clustered (baseline_id)

);
go

CREATE UNIQUE INDEX idx_sqlwatch_config_baseline_default
    ON [dbo].[sqlwatch_config_baseline] ([is_default])
    WHERE [is_default] = 1;
GO

CREATE UNIQUE INDEX idx_sqlwatch_config_baseline_dates
	ON [dbo].[sqlwatch_config_baseline] (baseline_start, baseline_end);
GO

create trigger trg_sqlwatch_config_baseline_meta_add
on [dbo].[sqlwatch_config_baseline]
for insert
as
begin
	declare @sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

	insert into [dbo].[sqlwatch_meta_baseline] (sql_instance, baseline_id, baseline_start, baseline_end, [is_default], [comments], [date_updated])
	select @sql_instance
		, inserted.baseline_id
		, inserted.baseline_start
		, inserted.baseline_end
		, inserted.is_default
		, inserted.comments
		, GETUTCDATE()
	from inserted;

	--SQL Server does not support per-row triggers but we have to iterate through every inserted row here to load header based on baseline dates.
	--Whilst cusors in triggers are genearally bad approach, this will not be run very often as the baselines should never change often.

	declare @baseline_start datetime2(0),
			@baseline_end datetime2(0),
			@baseline_id smallint;

	declare cur_insert cursor for

	select baseline_id, baseline_start, baseline_end 
	from inserted

	open cur_insert ;
	fetch next from cur_insert 
	into @baseline_id, @baseline_start, @baseline_end;

	while @@FETCH_STATUS = 0
		begin

			insert into [dbo].[sqlwatch_meta_snapshot_header_baseline] with (tablock) (
					baseline_id
				,	snapshot_time
				,	[snapshot_type_id]
				,	sql_instance
				) 
			select @baseline_id, snapshot_time, [snapshot_type_id], @sql_instance
			from dbo.sqlwatch_logger_snapshot_header h
			where sql_instance = @sql_instance
			and snapshot_time between @baseline_start and @baseline_end;

			fetch next from cur_insert 
			into @baseline_id, @baseline_start, @baseline_end;
		end

	close cur_insert;
	deallocate cur_insert;
end
go

create trigger trg_sqlwatch_config_baseline_meta_remove
on [dbo].[sqlwatch_config_baseline]
for delete
as
begin
	declare @sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

	delete m 
	from [dbo].[sqlwatch_meta_baseline] m
	inner join deleted d
	on m.baseline_id = d.baseline_id
	and m.sql_instance = @sql_instance;

end
go

create trigger trg_sqlwatch_config_baseline_meta_update
on [dbo].[sqlwatch_config_baseline]
instead of update
as
begin

	--updating baseline dates will not be supported, only the default flag and comments
	--to update baseline dates we need to remove and recreate the baseline so we can ring fence new data set

	if exists (
		select *
		from inserted i
		inner join deleted d
		on d.baseline_id = i.baseline_id
		and (
				d.baseline_start <> i.baseline_start
			or	d.baseline_end <> i.baseline_end
			)
		)
		begin
			raiserror('Changes to the baseline dates are not allowed. To modify baseline dates create new baseline and delete the old one.', 16,1);			
		end
	else
		begin
			declare @sql_instance varchar(32) = dbo.ufn_sqlwatch_get_servername();

			update m
				set is_default = i.is_default,
					comments = i.comments

			from [dbo].[sqlwatch_config_baseline] m
			inner join inserted i
			on m.baseline_id = i.baseline_id;

			update m
				set is_default = i.is_default,
					comments = i.comments

			from [dbo].[sqlwatch_meta_baseline] m
			inner join inserted i
			on m.baseline_id = i.baseline_id
			and m.sql_instance = @sql_instance;

		end;
end;
go