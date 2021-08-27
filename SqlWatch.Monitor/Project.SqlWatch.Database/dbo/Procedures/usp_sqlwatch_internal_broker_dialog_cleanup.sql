CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_dialog_cleanup]
as
begin
	set nocount on;

	declare @sql nvarchar(max) = '';

	--cleanup expired
	--normally the initiator or the target should close the conversation however
	--in our case, we keep the convo open for few hours and then create new conversation and let the old one expire according to its lifetime.
	--this is becuase we want to avoid BEGIN and END CONVERSATION for every message due to the ovehread

	select @sql+='end conversation ''' + convert(nvarchar(max),conversation_handle) + ''';' + char(10)
	from sys.conversation_endpoints 
	where state_desc = 'ERROR';

	exec sp_executesql @sql;

end;