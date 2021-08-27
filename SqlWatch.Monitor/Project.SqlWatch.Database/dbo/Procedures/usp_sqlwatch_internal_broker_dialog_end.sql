CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_broker_dialog_end]
	@cid uniqueidentifier
as
   --the best way to end the conversation is to send a message to tell the target (receiving end) to end it instead of issuing END CONVERSATION from the initiator
   --this way we can be 100% sure that we have sent all the messages in the batch and that they will be processed in a given order.
   SEND ON CONVERSATION @cid
        MESSAGE TYPE [mtype_sqlwatch_end];