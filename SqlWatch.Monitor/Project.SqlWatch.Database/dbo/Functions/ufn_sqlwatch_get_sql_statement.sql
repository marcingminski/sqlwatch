CREATE FUNCTION [dbo].[ufn_sqlwatch_get_sql_statement]
(
	@text nvarchar(max) ,
	@statement_start_offset int,
	@statement_end_offset int
)
RETURNS nvarchar(max) with schemabinding
AS
begin
	return (
		select 
			substring(
				@text,@statement_start_offset/2,
				(
				case when @statement_end_offset = -1 
					then LEN(CONVERT(nvarchar(max), @text)) * 2 
					else @statement_end_offset 
					end - @statement_start_offset
					)/2
				)
	);
end;
