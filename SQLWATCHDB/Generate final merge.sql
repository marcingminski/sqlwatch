select + case when exists (
	select top 1 * from SYS.IDENTITY_COLUMNS IC
	where object_name(object_id)= T.TABLE_NAME
) then 'set identity_insert ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' on; ' else '' end +
'insert into ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + '(
	' + stuff((
			select ',' + quotename(COLUMN_NAME)
			from INFORMATION_SCHEMA.COLUMNS C
			where C.TABLE_CATALOG = T.TABLE_CATALOG
			and C.TABLE_NAME = T.TABLE_NAME
			and C.TABLE_SCHEMA = T.TABLE_SCHEMA
			for xml path ('')),1,1,'') + '
)
select s.* from ##import_' + T.TABLE_NAME + ' s
	' + case when T.TABLE_NAME <> 'sqlwatch_logger_snapshot_header' then 'inner join [dbo].[sqlwatch_logger_snapshot_header] hd
		on hd.snapshot_time = s.snapshot_time
		and hd.snapshot_type_id = s.snapshot_type_id
		and hd.sql_instance = s.sql_instance collate database_default ' else '' end + '
	left join ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' t
		on ' + stuff ((
			select ' and s.['+CU.COLUMN_NAME + ']=t.['+CU.COLUMN_NAME + ']' + case when C1.DATA_TYPE like '%char%' or C1.DATA_TYPE like '%text%' then ' collate database_default' else '' end 
			FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
			inner join INFORMATION_SCHEMA.COLUMNS C1
				ON C1.COLUMN_NAME = CU.COLUMN_NAME
				AND C1.TABLE_CATALOG = CU.TABLE_CATALOG
				AND C1.TABLE_NAME = CU.TABLE_NAME
				AND C1.TABLE_SCHEMA = CU.TABLE_SCHEMA
			where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
			and CU.TABLE_CATALOG = T.TABLE_CATALOG
			and CU.TABLE_NAME = T.TABLE_NAME
			and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
			order by CU.ORDINAL_POSITION
			for xml path ('')
		),1,4,'') + '
where ' + stuff ((
			select top 1 ' t.['+CU1.COLUMN_NAME + '] is null' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU1
		where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
		and CU1.TABLE_CATALOG = T.TABLE_CATALOG
		and CU1.TABLE_NAME = T.TABLE_NAME
		and CU1.TABLE_SCHEMA = T.TABLE_SCHEMA
		order by CU1.ORDINAL_POSITION
		for xml path ('')
),1,1,'') + case when exists (
	select top 1 * from SYS.IDENTITY_COLUMNS IC
	where object_name(object_id)= T.TABLE_NAME
) then '; set identity_insert ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' off; ' else '' end

from INFORMATION_SCHEMA.TABLES T
where T.TABLE_NAME like 'sqlwatch_logger%'
order by case when T.TABLE_NAME like '%header' then 1 else 99 end
