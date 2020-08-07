CREATE FUNCTION [dbo].[ufn_sqlwatch_format_bytes] 
(
	@bytes bigint
) 
RETURNS varchar(100) with schemabinding
AS
BEGIN
	RETURN (
		select case 
					--JESD21-C all unites are upper case wherease in SI standard kilo is lowercase, since this is computer science and not physics, we are sticking to the the JESD21 format
					when @bytes / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),@bytes / 1024.0 )) + ' KB' 
					when @bytes / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),@bytes / 1024.0 / 1024.0)) + ' MB'
					when @bytes / 1024.0 / 1024.0 / 1024.0 < 1000 then convert(varchar(100),convert(decimal(10,2),@bytes / 1024.0 / 1024.0 / 1024.0)) + ' GB' 
					else convert(varchar(100),convert(decimal(10,2),@bytes / 1024.0 / 1024.0 / 1024.0 / 1024.0)) + ' TB' 
					end
	)
END
