CREATE TABLE [dbo].[sqlwatch_config_activated_procedures]
(
	[procedure_name] nvarchar(128),
	[timer_seconds] int,

	constraint pk_sqlwatch_config_activated_procedures primary key clustered (
		[procedure_name]
	)
)
go

create trigger trg_sqlwatch_config_activated_procedures_insert
on [dbo].[sqlwatch_config_activated_procedures]
for insert
as
begin
	declare @sql nvarchar(max) = '';
	select @sql = @sql + '
CREATE QUEUE SQLWATCH_' + parsename([procedure_name],1) + ';
CREATE SERVICE SQLWATCH_' + parsename([procedure_name],1) + '
	ON QUEUE SQLWATCH_' + parsename([procedure_name],1) + '
	(
		[DEFAULT]
	)
	
	' from inserted

	exec (@sql);

end
go

create trigger trg_sqwlatch_config_activated_procedure_delete
on dbo.sqlwatch_config_activated_procedures
for delete
as
begin
	declare @sql nvarchar(max) = '';

	select @sql = @sql + '
DROP SERVICE SQLWATCH_' + parsename([procedure_name],1) + ';
DROP QUEUE SQLWATCH_' + parsename([procedure_name],1) + ';'
	from deleted;

	exec (@sql);
end