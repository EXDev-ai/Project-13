local Super = require(script.Parent)
local Client = Super:Extend()

function Client:OnNew()
	self.Interface = require(script.Parent.Parent:WaitForChild("ClientInterface").Value:WaitForChild("Interface"))
	self.Player = game.Players.LocalPlayer
	
	self:InitRemotes()
	self:InitDialogues()
	self:DiscoverDialogues()
	self:TriggerDialoguesLoop()
	
	self.Interface.Initialize{
		UserEnded = function()
			self:DialogueUserEnded()
		end,
	}
end

--//-------------------//--
--//--class variables--//--
--//-------------------//--

--float TriggerDialoguesFrequency
--* the number of times per second where the client scans all known dialogues to see if it should be triggering them.
Client.TriggerDialoguesFrequency = 8

--float MaxReplicationTime
--* the maximum amount of time the client will wait for an expected object in a dialogue structure.
--* it errors if it doesn't find it in this amount of time.
Client.MaxReplicationTime = 15

--Roblox::Folder[] Dialogues
Client.Dialogues = {}
function Client:InitDialogues()
	self.Dialogues = {}
end

--//----------------------//--
--//--method definitions--//--
--//----------------------//--

--InitRemotes
--* sets up remotes for client-server communication.
function Client:InitRemotes()
	local function onDialogueRangeWarned(...) self:OnDialogueRangeWarned() end
	self.Remotes:WaitForChild("DialogueRangeWarned").OnClientEvent:connect(onDialogueRangeWarned)
	
	local function onDialoguePromptShown(...) self:OnDialoguePromptShown(...) end
	self.Remotes:WaitForChild("DialoguePromptShown").OnClientEvent:connect(onDialoguePromptShown)
	
	local function onDialoguePromptChained(...) self:OnDialoguePromptChained(...) end
	self.Remotes:WaitForChild("DialoguePromptChained").OnClientEvent:connect(onDialoguePromptChained)
	
	local function onDialogueTimedOut() self:OnDialogueTimedOut() end
	self.Remotes:WaitForChild("DialogueTimedOut").OnClientEvent:connect(onDialogueTimedOut)
	
	local function onDialogueWalkedAway() self:OnDialogueWalkedAway() end
	self.Remotes:WaitForChild("DialogueWalkedAway").OnClientEvent:connect(onDialogueWalkedAway)
	
	local function onDialogueFinished(...) self:OnDialogueFinished(...) end
	self.Remotes:WaitForChild("DialogueFinished").OnClientEvent:connect(onDialogueFinished)
end

--DialogueUserEnded
--* tells the server that the user ended
--* the dialogue manually.
function Client:DialogueUserEnded()
	local remote = self.Remotes:FindFirstChild("DialogueUserEnded")
	if not remote then return end
	
	remote:FireServer()
end

--CheckIsDialogue(Roblox::Instance)
--* checks to see if this is a dialogue.
--* pretty loose and easy to break.
--* should explore better solutions.
function Client:CheckIsDialogue(object)
	local isDialogue = object:IsA("Folder") and object.Name == "RobloxDialogue"
	if not isDialogue then return end
	if self:TableHasValue(self.Dialogues, object) then return end
	
	--wait for the correct objects. error if we don't find them in a reasonable amount of time.
	local neededChildren = {
		"ConversationDistance",
		"TriggerDistance",
		"TriggerOffset",
	}
	for _, neededChild in pairs(neededChildren) do
		self:WaitThenError(
			object,
			neededChild,
			string.format(
				"Found what appears to be a dialogue: '%s'\nExpected child '%s' but it didn't show up after %d seconds. Did you forget it?",
				object:GetFullName(),neededChild, self.MaxReplicationTime
			)
		)
	end
	
	--add and talk to the interface
	table.insert(self.Dialogues, object)
	self.Interface.RegisterDialogue(object, function() self:StartDialogue(object) end)
end

--WaitThenError(Roblox::Instance, string, string)
--* waits for the named child in the instance for a time.
--* if it doesn't find it, it errors.
--* this is used since this is a client script, and replication of objects is not instant.
--* if the object we expect never shows up, we should freak out about it and warn the user.
--* e.g. don't mess up the data structure!
function Client:WaitThenError(object, childName, message)
	local child = object:WaitForChild(childName, self.MaxReplicationTime)
	if not child then
		error(message)
	end
	return child
end

--DiscoverDialogues
--* checks every object in the game to see if it is a dialogue.
--* also checks every object added to the game after this initial check.
function Client:DiscoverDialogues()
	local function recurse(object)
		self:CheckIsDialogue(object)
		
		for _, child in pairs(object:GetChildren()) do
			recurse(child)
		end
	end
	
	local function onDescendantAdded(object)
		self:CheckIsDialogue(object)
	end
	workspace.DescendantAdded:connect(onDescendantAdded)
	
	recurse(workspace)
end

--StartDialogue(Roblox::Folder)
--* calls up to the server saying that it wants to dialogue with this dialogue
function Client:StartDialogue(dialogue)
	script.Parent.Parent.Remotes.DialogueRequested:FireServer(dialogue)
end

--OnDialogueRangeWarned
--* shows a warning to the player that they are not currently in range of the dialogue they attempted to click.
--* guaranteed based on server calculations, not client.
function Client:OnDialogueRangeWarned()
	self.Interface.RangeWarned()
end

--OnDialogueTimedOut
--* shows a warning to the player that they waited too long to choose a response.
function Client:OnDialogueTimedOut()
	self.Interface.TimedOut()
end

--OnDialogueWalkedAway
--* shows a warning to the player that they walked away from an active dialogue conversation.
function Client:OnDialogueWalkedAway()
	self.Interface.WalkedAway()
end

--OnDialogueFinished(bool)
--* performs dialogue cleanup.
--* this is called when the dialogue finished under normal circumstances.
--* the 'withPrompt' is whether or not the dialogue finished with a prompt
--* from the NPC. Useful if you want to show the prompt for some time
--* but immediately end conversations that ended with a response
function Client:OnDialogueFinished(withPrompt)
	self.Interface.Finished(withPrompt)
end

--OnDialoguePromptShown(Roblox::Folder, PromptTable prompt, ResponseTable[] responses)
--* gives proper information to the interface to show the prompt and responses
function Client:OnDialoguePromptShown(dialogue, prompt, responses)
	local responseTables = {}
	for index, response in pairs(responses) do
		table.insert(responseTables, {
			Line = response.Line,
			Callback = function()
				self.Remotes.DialogueResponseChosen:FireServer(index)
			end,
			Data = response.Data,
		})
	end
	
	self.Interface.PromptShown(dialogue, {Line = prompt.Line, Data = prompt.Data}, responseTables)
end

--OnDialoguePromptChained(Roblox::Folder, PromptTable prompt)
function Client:OnDialoguePromptChained(dialogue, prompt)
	local function callback()
		self.Remotes.DialogueChainAcknowledged:FireServer()
	end
	
	self.Interface.PromptChained(dialogue, {Line = prompt.Line, Data = prompt.Data}, callback)
end

--TriggerDialoguesLoop
--* loops regularly and checks to see if there's a dialogue we should be triggering.
--* not very expensive at all, unless you have like 10,000 dialogues in your place.
--* in addition to this, it will clean billboards from the PlayerGui for dialogues that no longer exist.
function Client:TriggerDialoguesLoop()
	spawn(function() while true do
		wait(1 / self.TriggerDialoguesFrequency)
		self:TriggerDialogues()
	end end)
end
function Client:TriggerDialogues()
	local index = 1
	local count = #self.Dialogues
	while index <= count do
		wait()
		local dialogue = self.Dialogues[index]
		if (not dialogue) or (not dialogue.Parent) then
			count = count - 1
			
			table.remove(self.Dialogues, index)
			self.Interface.UnregisterDialogue(dialogue)
		else
			index = index + 1
			
			local triggers = dialogue.TriggerDistance.Value > 0
			if triggers then
				local part = self:GetClass"Utility":GetDialoguePart(dialogue)
				local distance = self.Player:DistanceFromCharacter(part.Position + dialogue.TriggerOffset.Value)
				local inRange = distance < dialogue.ConversationDistance.Value
				local triggering = distance < dialogue.TriggerDistance.Value
				if inRange and triggers and triggering then
					self.Interface.Triggered(dialogue, function() self:StartDialogue(dialogue) end)
				end
			end
		end
	end
end

local Singleton = Client:New()
return Singleton