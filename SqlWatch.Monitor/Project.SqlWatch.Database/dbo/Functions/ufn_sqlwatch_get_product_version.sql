CREATE FUNCTION [dbo].[ufn_sqlwatch_get_product_version]
(
	@type varchar(50)
)
returns decimal(10,2) as
begin
	return (select case 
		when upper(@type) = 'MAJOR' then substring(product_version, 1,charindex('.', product_version) + 1 )
		when upper(@type) = 'MINOR' then parsename(convert(varchar(32), product_version), 2)
		end
	from (select product_version=convert(nvarchar(128),serverproperty('productversion'))) t
	)
end
