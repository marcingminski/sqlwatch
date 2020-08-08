select '##import_' + TABLE_NAME, 'if object_id (''tempdb..##import_' + TABLE_NAME + ''') is null
	begin
		create table ##import_' + TABLE_NAME + ' (
		 ' + stuff((
			select ',['+COLUMN_NAME + '] ' + DATA_TYPE + case when DATA_TYPE like '%char%' then '(' + convert(varchar(50),case when c.CHARACTER_MAXIMUM_LENGTH = -1 then 'max' else convert(varchar(50),c.CHARACTER_MAXIMUM_LENGTH) end) + ')' else '' end
			from INFORMATION_SCHEMA.COLUMNS c
			where c.TABLE_CATALOG = t.TABLE_CATALOG
			and c.TABLE_SCHEMA = t.TABLE_SCHEMA
			and c.TABLE_NAME = t.TABLE_NAME
			order by ORDINAL_POSITION
			for xml path ('')
		  ),1,1,'') + isnull(',
		  constraint pk_tmp_import_' + TABLE_NAME + ' primary key (
			' + stuff ((
				select ',['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
				where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
				and CU.TABLE_CATALOG = T.TABLE_CATALOG
				and CU.TABLE_NAME = T.TABLE_NAME
				and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
				order by CU.ORDINAL_POSITION
				for xml path ('')
			),1,1,'') + '
		  )','') + '
		)
	end'
, 'delete from ##import_' + TABLE_NAME + '
		where sql_instance = ''"+@[User::internal_remote_instance_servername]+"''
	'
from INFORMATION_SCHEMA.TABLES t
where t.TABLE_NAME like 'sqlwatch_logger%'