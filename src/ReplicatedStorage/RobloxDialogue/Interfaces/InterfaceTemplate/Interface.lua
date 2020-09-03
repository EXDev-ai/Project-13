local Interface = {}

--Initialize
--* called by the client immediately after it is initialized.
--* used to pass communication functions into the interface.
--* the current list of functions is as follows:
--********************************************************--
--*--UserEnded
--*--* Call this function when the user manually ends
--*--* any dialogue, so that the server can respond
--*--* accordingly and not send false timeout signals
--********************************************************--
function Interface.Initialize(clientFunctions)
	Interface.ClientFunctions = clientFunctions
end

--RegisterDialogue
--* called when the client discovers a Dialogue. The Interface
--* should provide some way for the user to interact with the
--* dialogue in question. When they interact with it, call the
--* callback and the client will initialize the dialogue
function Interface.RegisterDialogue(dialogue, startDialogueCallback)
	
end

--UnregisterDialogue
--* called when the client discovers that a dialogue has been
--* removed from the game. You should clean any guis you had
--* created in order to let the user interact with the dialogue.
function Interface.UnregisterDialogue(dialogue)
	
end

--Triggered
--* called when the dialogue has a TriggerDistance and the player
--* walks in range of it. Here so you can manage your interaction
--* buttons, etc. Call the callback to start the dialogue.
function Interface.Triggered(dialogue, startDialogueCallback)
	
end

--RangeWarned
--* called when the server notifies that the client attempted
--* to start a dialogue that was too far away (ConversationDistance).
function Interface.RangeWarned()
	
end

--TimedOut
--* called when the player took too long to choose an option.
function Interface.TimedOut()
	
end

--WalkedAway
--* called when the player gets too far away from the dialogue
--* that they are currently speaking with.
function Interface.WalkedAway()
	
end

--Finished
--* called when the conversation finishes under normal circumstances
--* with prompt is whether or not the dialogue finished with a prompt
--* as opposed to a response. useful if you want to show the prompt
--* for some time but want to end immediately conversations that
--* end with a response
function Interface.Finished(withPrompt)
	
end

--PromptShown
--* the bread and butter of the interface, the interface should present
--* the player with the prompt and responses. The dialogueFolder is the
--* folder representing the dialogue, the prompTable is a table in the
--* following format:
--* {
--* 	Line = "The prompt string.",
--* 	Data = [the data from the prompt node],
--* }
--* and the responseTables is a list of tables in the following format:
--* {
--* 	Line = "Some string to show.",
--* 	Callback = [function to call if the player chooses this response],
--*		Data = [the data from the response node],
--* }
--* if a player chooses the response, call the callback.
function Interface.PromptShown(dialogueFolder, promptTable, responseTables)
	
end

--PromptChained
--* very similar to PromptShown, except there are no responses.
--* that means there's a prompt following this prompt. the only
--* responsibility of this function is to call the clalback in
--* order to acknowledge that the chain should proceed. this
--* allows you to use your own timing scheme for how the chain
--* should proceed, with a continue button, arbitrary timing, etc.
--* promptTable is in the following format:
--* {
--* 	Line = "The prompt string.",
--* 	Data = [the data from the prompt node],
--* }
function Interface.PromptChained(dialogueFolder, promptTable, callback)
	
end

return Interface