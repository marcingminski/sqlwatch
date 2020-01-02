CREATE FUNCTION [dbo].[ufn_sqlwatch_get_version]()
RETURNS @returntable TABLE
(
	major int,
	minor int,
	patch int,
	build int
)

AS
BEGIN	
	insert into @returntable
	  select top 1 parsename([value],4), parsename([value],3), parsename([value],2), parsename([value],1) 
	  from (
		select [value] = ltrim(rtrim(replace(replace(convert(varchar(max),[value]),char(10),''),char(13),'')))
		from sys.extended_properties
		where name = 'SQLWATCH Version'

		union 

		/* failsave if we have no extended property */
		select [sqlwatch_version]
		from (
				select top 1 [sqlwatch_version]
				from [dbo].[sqlwatch_app_version]
				order by [install_sequence] desc	
			) v
		) t


	RETURN
END
