CREATE PROCEDURE [dbo].[usp_sqlwatch_repository_populate_tables_to_import]
AS

set nocount on;

--this procedure builds a list of tables to import for SqlWatchImport.exe and only applies if you are importing data from remote sqlwatch instances.
--It does not apply if you are using SqlWatchCollect.exe.
truncate table dbo.sqlwatch_stage_repository_tables_to_import;

--list of tables to exclude from the import:
declare @exclude_tables table (
	table_name nvarchar(512)
);

--exclude tables that have mo meaning outside of the original SQL Instance:
insert into @exclude_tables
values	('sqlwatch_meta_action_queue'),
		('sqlwatch_meta_repository_import_queue'),
		('sqlwatch_meta_repository_import_status'),
		('sqlwatch_meta_repository_import_thread');

-- exclude tables that break the import that need fixing:
insert into @exclude_tables
values	('sqlwatch_logger_whoisactive'),
		('sqlwatch_logger_system_configuration_scd');


declare @include_tables table (
	table_name nvarchar(512)
);

insert into @include_tables
select name
from sys.tables
where name like 'sqlwatch_meta%' or	name like 'sqlwatch_logger%';


;with cte_base_tables (lvl, object_id, name, schema_Name) as (
	
	-- get base list of tables we will be importing
	select 1
		, object_id
		, t.name
		, [schema_Name] = s.name
	from sys.tables t 
	inner join sys.schemas s
		on t.schema_id = s.schema_id
	inner join @include_tables it
		on it.table_name = t.name
	where type_desc = 'USER_TABLE'
	and is_ms_shipped = 0
	and t.name not in (
		select table_name 
		from @exclude_tables
		)

	--now build dependencies so import tables in the right order:
	union all

	select 
		bt.lvl + 1, t.object_id, t.name, S.name as schema_Name
	from cte_base_tables bt
	inner join sys.tables t 
	on exists 
		 (	
			select null 
			from sys.foreign_keys fk
			where fk.parent_object_id = t.object_id
			and fk.referenced_object_id = bt.object_id 
			)
	inner join sys.schemas s 
		on t.schema_id = s.schema_id
		and t.object_id <> bt.object_id
		and bt.lvl < 20 -- this shoult correspond to the value in the SqlWatchImporter.exe
	inner join @include_tables it
		on it.table_name  = t.name
	where t.type_desc = 'USER_TABLE'
		and t.name not in (
			select table_name 
			from @exclude_tables
			)
		and t.is_ms_shipped = 0 
	)
, cte_dependency as (
	select 
		  table_name=d.schema_Name + '.' + d.name
		, dependency_level = MAX (d.lvl)
	from cte_base_tables d
	group by d.schema_Name, d.name
)
insert into dbo.sqlwatch_stage_repository_tables_to_import(
	[table_name],[dependency_level],[has_last_seen],[has_last_updated],
	[has_identity],[primary_key],[joins],[updatecolumns],[allcolumns] 
	)

select d.[table_name],d.[dependency_level],
	c.[has_last_seen],
	[has_last_updated],
	[has_identity],[primary_key],[joins],[updatecolumns],[allcolumns] 
from cte_dependency d

--check if the table contains date_last_seen column
outer apply (
	select has_last_seen = max(case when COLUMN_NAME = 'date_last_seen' then 1 else 0 end)
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_SCHEMA + '.' + TABLE_NAME = d.table_name
) c

-- check if the table has date_updated column
outer apply (
	select has_last_updated = max(case when COLUMN_NAME = 'date_updated' then 1 else 0 end)
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_SCHEMA + '.' + TABLE_NAME = d.table_name
) u

-- build concatenated string of primary keys
outer apply (
select primary_key = isnull(stuff ((
		select ',' + quotename(ccu.COLUMN_NAME)
			from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
			inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
			on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
		where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
		and tc.CONSTRAINT_TYPE = 'Primary Key'
		order by ccu.ORDINAL_POSITION
		for xml path('')),1,1,''),'')
	) pks

-- check if the table has identity
outer apply (
select has_identity = isnull(isnull(( 
		select 1
		from sys.identity_columns 
		where OBJECT_NAME(object_id) = parsename(d.TABLE_NAME,1)
		),0),'')
) hasidentity

-- build string containing all joins required for the merge operation
outer apply (
 select joins = isnull(stuff ((
		select ' and source.' + quotename(ccu.COLUMN_NAME) + ' = target.' + quotename(ccu.COLUMN_NAME)
			from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
			inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
			on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
		where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
		and tc.CONSTRAINT_TYPE = 'Primary Key'
		order by ccu.ORDINAL_POSITION
		for xml path('')),1,5,''),'')
) mergejoins

-- build update statememnt for the merge operation
outer apply (
select updatecolumns = isnull(stuff((
		select ',' + quotename(COLUMN_NAME) + '=source.' + quotename(COLUMN_NAME)
		from INFORMATION_SCHEMA.COLUMNS
		where TABLE_NAME = parsename(d.TABLE_NAME,1)

		--excluding primary keys
		and COLUMN_NAME not in (
				select ccu.COLUMN_NAME
				from INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
				inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE ccu
				on tc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
				where tc.TABLE_NAME = parsename(d.TABLE_NAME,1)
				and tc.CONSTRAINT_TYPE = 'Primary Key'
		)
		--excluding computed columns 
		and COLUMN_NAME not in (
				select cc.name 
				from sys.computed_columns cc
				inner join sys.tables t
					on t.object_id = cc.object_id
				where t.name = parsename(d.TABLE_NAME,1)
		)

		--excluding identity columns (some may be outside of PK)
		and COLUMN_NAME not in (
				select ic.name
				from sys.identity_columns ic
				inner join sys.tables t
					on t.object_id = ic.object_id
				where t.name = parsename(d.TABLE_NAME,1)
		)
		order by ORDINAL_POSITION
		for xml path('')),1,1,''),'')
) updatecolumns

-- build string with all columns in the table
outer apply (
select allcolumns = isnull(stuff ((
		select ',' + quotename(COLUMN_NAME)
		from INFORMATION_SCHEMA.COLUMNS
		where TABLE_NAME = parsename(d.TABLE_NAME,1)
		--excluding computed columns 
		and COLUMN_NAME not in (
				select name 
				from sys.computed_columns
				where object_id = OBJECT_ID(d.TABLE_NAME)
		)
		order by ORDINAL_POSITION
		for xml path('')),1,1,''),'')
) allcolumns
