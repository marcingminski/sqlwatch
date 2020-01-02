CREATE FUNCTION [dbo].[ufn_sqlwatch_split_string]
(
	@input_string nvarchar(max),
	@delimiter nvarchar(max) = ','
)
RETURNS @output TABLE
(
	[value] nvarchar(max)
)
as
begin

      declare @string nvarchar(max)
      declare @cnt Int 

      if(@input_string is not null) 

      begin
            set @cnt = charindex(@delimiter,@input_string) 
            while @cnt > 0 
            begin 
                  set @string = substring(@input_string,1,@cnt-1) 
                  set @input_string = substring(@input_string,@cnt+1,len(@input_string)-@cnt) 

                  insert into @output values (@string) 
                  set @cnt = charindex(@delimiter,@input_string) 
            end 


            set @string = @input_string 

            insert into @output values (@string) 
      end
      return
end
