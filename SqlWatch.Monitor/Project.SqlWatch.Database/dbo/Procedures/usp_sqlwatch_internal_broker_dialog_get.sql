CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_dialog_get]
	@cid uniqueidentifier output

AS
begin
	select top 1 @cid = i.conversation_handle
	from sys.conversation_endpoints i with (nolock)
	where i.is_initiator = 1
	and state_desc = 'CONVERSING'
	order by i.lifetime desc
end;