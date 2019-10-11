SELECT variable_name='sql_get_' + T.TABLE_NAME, sql_expression_type_1=
'"exec (''/* SQLWATCH get remote instance ' + T.TABLE_SCHEMA + '.' + TABLE_NAME + ' */' + case when T.TABLE_NAME <> 'sqlwatch_logger_snapshot_header' then '
declare @snapshot_type_id tinyint, @snapshot_time datetime
select top 1 @snapshot_type_id = snapshot_type_id from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' (nolock)
select @snapshot_time = snapshot_time from ##sqlwatch_logger_snapshot_header_last
where snapshot_type_id = @snapshot_type_id
and [sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''' else '' end + '

select ' + stuff ((
	select ',s.['+COLUMN_NAME + ']' from INFORMATION_SCHEMA.COLUMNS c
	where c.TABLE_CATALOG = T.TABLE_CATALOG
	and c.TABLE_SCHEMA = T.TABLE_SCHEMA
	and c.TABLE_NAME = T.TABLE_NAME
	order by c.ORDINAL_POSITION
	for xml path ('')),1,1,'') +
	' from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' s (nolock)
	  ' + case when T.TABLE_NAME = 'sqlwatch_logger_snapshot_header' then '
	  	inner join ##sqlwatch_logger_snapshot_header_last th 
       on s.sql_instance = th.sql_instance COLLATE database_default 
       and s.snapshot_type_id = th.snapshot_type_id 
	where s.snapshot_time >= th.snapshot_time
      and s.[sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''
	   /* do not pull very recent snapshots as data collection may be in the flight */
	  and s.[snapshot_time] < dateadd(minute,-1,getdate())' else '
	  where s.snapshot_time >= @snapshot_time
      and s.[sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''' end + '
	order by ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'') + ''') with result sets ((' + stuff ((
	select ',['+C.COLUMN_NAME + '] ' + C.DATA_TYPE + 
		+ case when C.DATA_TYPE like '%char%' then '(' + convert(varchar(100),C.CHARACTER_MAXIMUM_LENGTH) + ')' else '' end
		+ case when C.IS_NULLABLE = 'YES' then ' NULL' else ' NOT NULL' end
	from INFORMATION_SCHEMA.COLUMNS C
	where C.TABLE_CATALOG = T.TABLE_CATALOG
	and C.TABLE_NAME = T.TABLE_NAME
	and C.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by C.ORDINAL_POSITION
	for xml path ('')),1,1,'') + '))"'

, sql_expression_type_2='
select ' + stuff ((
	select ',s.['+COLUMN_NAME + ']' from INFORMATION_SCHEMA.COLUMNS c
	where c.TABLE_CATALOG = T.TABLE_CATALOG
	and c.TABLE_SCHEMA = T.TABLE_SCHEMA
	and c.TABLE_NAME = T.TABLE_NAME
	order by c.ORDINAL_POSITION
	for xml path ('')),1,1,'') +
	' from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' s
	inner join ##sqlwatch_logger_snapshot_header_last th 
       on s.sql_instance = th.sql_instance COLLATE database_default 
       and s.snapshot_type_id = th.snapshot_type_id 
	where s.snapshot_time >= th.snapshot_time
      and s.[sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''
	  ' + case when 1=2 and T.TABLE_NAME = 'sqlwatch_logger_snapshot_header' then ' /* do not pull very recent snapshots as data collection may be in the flight */
	  and s.[snapshot_time] < dateadd(minute,-1,getdate())' else '' end + '
	order by ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'')

	, variable_name_keys='sql_get_' + T.TABLE_NAME + '_keys'
	, sql_expression_destination_keys_type_1 = '"exec (''/* SQLWATCH get repository keys ' + T.TABLE_SCHEMA + '.' + TABLE_NAME + ' */' + case when T.TABLE_NAME <> 'sqlwatch_logger_snapshot_header' then '
declare @snapshot_type_id tinyint, @snapshot_time datetime
select top 1 @snapshot_type_id = snapshot_type_id from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' (nolock)
select @snapshot_time = snapshot_time from ##sqlwatch_logger_snapshot_header_last
where snapshot_type_id = @snapshot_type_id
and [sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''' else '' end + '

select ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'') +
	' from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' s (nolock)
	  ' + case when T.TABLE_NAME = 'sqlwatch_logger_snapshot_header' then '
	  	inner join ##sqlwatch_logger_snapshot_header_last th 
       on s.sql_instance = th.sql_instance COLLATE database_default 
       and s.snapshot_type_id = th.snapshot_type_id 
	where s.snapshot_time >= th.snapshot_time
      and s.[sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''
	   /* do not pull very recent snapshots as data collection may be in the flight */
	  and s.[snapshot_time] < dateadd(minute,-1,getdate())' else '
	  where s.snapshot_time >= @snapshot_time
      and s.[sql_instance] = ''''"+@[User::internal_remote_instance_servername]+"''''' end + '	order by ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'') + ''') with result sets ((' + + stuff ((
	select ',['+CU.COLUMN_NAME + '] ' + C.DATA_TYPE + 
		+ case when C.DATA_TYPE like '%char%' then '(' + convert(varchar(100),C.CHARACTER_MAXIMUM_LENGTH) + ')' else '' end
		+ case when C.IS_NULLABLE = 'YES' then ' NULL' else ' NOT NULL' end
	from INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	inner join INFORMATION_SCHEMA.COLUMNS C
		on CU.COLUMN_NAME = C.COLUMN_NAME
		and CU.TABLE_NAME = C.TABLE_NAME
		and CU.TABLE_SCHEMA = C.TABLE_SCHEMA
		and CU.TABLE_CATALOG = C.TABLE_CATALOG 
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'') + '))"'


	, sql_expression_destination_keys_type_2 = 'select ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'') +
	' from ' + T.TABLE_SCHEMA + '.' + T.TABLE_NAME + ' s
	inner join ##sqlwatch_logger_snapshot_header_last th 
       on s.sql_instance = th.sql_instance COLLATE database_default 
       and s.snapshot_type_id = th.snapshot_type_id 
	where s.snapshot_time >= th.snapshot_time
      and s.[sql_instance] = ''"+@[User::internal_remote_instance_servername]+"''
	  ' + case when 1=2 and T.TABLE_NAME = 'sqlwatch_logger_snapshot_header' then ' /* do not pull very recent snapshots as data collection may be in the flight */
	  and s.[snapshot_time] < dateadd(minute,-1,getdate())' else '' end + '
	order by ' + stuff ((
	select ',s.['+CU.COLUMN_NAME + ']' FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
	where OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + QUOTENAME(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1
	and CU.TABLE_CATALOG = T.TABLE_CATALOG
	and CU.TABLE_NAME = T.TABLE_NAME
	and CU.TABLE_SCHEMA = T.TABLE_SCHEMA
	order by CU.ORDINAL_POSITION
	for xml path ('')),1,1,'')
from INFORMATION_SCHEMA.TABLES T
where T.TABLE_NAME like 'sqlwatch_logger%'
order by 1


