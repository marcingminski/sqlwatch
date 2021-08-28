CREATE FUNCTION [dbo].[ufn_sqlwatch_get_sql_version]()
RETURNS smallint with schemabinding
AS
BEGIN
    declare @return smallint,
            --ProductMajorVersion is only availabl since 2012 but its quicker to parse as it returns simple number:
            @ProductMajorVersion tinyint = convert(tinyint,SERVERPROPERTY('ProductMajorVersion'))

    return (select case
        when @ProductMajorVersion is not null then 
            case 
                when @ProductMajorVersion = 11 then 2012
                when @ProductMajorVersion = 12 then 2014
                when @ProductMajorVersion = 13 then 2016
                when @ProductMajorVersion = 14 then 2017
                when @ProductMajorVersion = 15 then 2019
                else 0000 
            end
        else
            case
                when convert(varchar(128), SERVERPROPERTY ('ProductVersion')) like '8%' then 2000
                when convert(varchar(128), SERVERPROPERTY ('ProductVersion')) like '9%' then 2005
                when convert(varchar(128), SERVERPROPERTY ('ProductVersion')) like '10.0%' then 2008
                --the 10.5 is 2008R2 but for the sake of simplicity I am going to call it 2009 so I can simply use <, >, = in my queries.
                --for example, if version < 2017 then.... If we return '2008R2' as varchar the same will not be possible.
                when convert(varchar(128), SERVERPROPERTY ('ProductVersion')) like '10.5%' then 2009
                else 0000
            end
    end);
END;
