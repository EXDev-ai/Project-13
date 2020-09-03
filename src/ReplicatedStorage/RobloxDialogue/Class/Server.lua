local Super = require(script.Parent)
local Server = Super:Extend()

local DataFolder = script.Parent.Parent
local ServerSettings = require(DataFolder.ServerSettings)

function Server:OnNew()
	self:InitRemotes()
end

--//-------------------//--
--//--class variables--//--
--//-------------------//--

--float DialogueTimeOutTime
--* the time after which a dialogue conversation times out with no response.
Server.DialogueTimeOutTime = ServerSettings.ServerTimeout

--float DialogueWalkAwayCheckFrequency
--* the number of times in one second that the system will check to see if a converser walked away.
Server.DialogueWalkAwayCheckFrequency = 4

--//----------------------//--
--//--method definitions--//--
--//----------------------//--

--InitRemotes
--* sets up all the connections for relevant remotes.
--* necessary for client-server communication.
function Server:InitRemotes()
	local function onDialogueRequested(...) self:OnDialogueRequested(...) end
	self.Remotes.DialogueRequested.OnServerEvent:connect(onDialogueRequested)
end

--Vector3 GetDialoguePosition(Roblox::BasePart, Graph)
--* returns the position of this conversation.
--* if TriggerDistance is greater than 0, we have to consider trigger offset.
function Server:GetDialoguePosition(part, graph)
	if graph.TriggerDistance > 0 then
		return part.Position + graph.TriggerOffset
	else
		return part.Position
	end
end

--OnDialogueRequested(Roblox::Player, Roblox::Folder)
--* attempts to start a dialogue for the requesting player.
--* sends back an warning if the player is out of range.
function Server:OnDialogueRequested(player, folder)
	--we require a humanoid root part
	if not player then return end
	if not player.Character then return end
	if not player.Character:FindFirstChild("HumanoidRootPart") then return end
	local root = player.Character.HumanoidRootPart
	
	--we require the part the dialogue is for
	local part = self:GetClass"Utility":GetDialoguePart(folder)
	if not part then return end
	
	--load the graph
	local graph = self:GetClass"Graph":New()
	graph:Load(folder)
	
	--are we close enough?
	local range = graph.ConversationDistance
	local distance = (self:GetDialoguePosition(part, graph) - root.Position).magnitude
	if distance > range then
		self.Remotes.DialogueRangeWarned:FireClient(player)
		return
	end
	
	--this graph needs to know who's conversing with it
	graph.ConversingPlayer = player
	
	--all tests pass, start the dialogue
	self:PromptPlayer(player, folder, graph, graph:GetInitialPrompt())
end

--string FormatDynamicText(string, Roblox::Player, Roblox::Folder, Node)
--* formats the given text to use its dynamic text contents
function Server:FormatDynamicText(text, player, folder, node)
	repeat
		local open, close = text:find("<.->")
		if open and close then
			local funcName = text:sub(open + 1, close - 1)
			local funcs = require(script.Parent.Parent.DynamicTextFunctions)
			local func = funcs[funcName]
			if func then
				text = text:sub(1, open - 1)..func(player, folder, node)..text:sub(close + 1)
			else
				text = text:sub(1, open - 1).."ERROR: NO DYNAMIC TEXT FUNCTION "..funcName..text:sub(close + 1)
				warn(string.format("RobloxDialogue failed to find a dynamic text function called '%s.'", funcName))
			end
		end
	until (open == nil) and (close == nil)
	
	return text
end

--ShowPrompt(Roblox::Player, Roblox::BasePart, Graph, Prompt)
--* communicates prompts and responses to the involved player.
--* recursively calls itself to keep up a single conversation.
function Server:PromptPlayer(player, folder, graph, prompt)
	--if we have no prompt, then the conversation is over!
	--notify the player and break out
	if not prompt then
		self.Remotes.DialogueFinished:FireClient(player, false)
		return
	end
	
	--perform the action for the prompt
	if prompt.Action then prompt.Action(player, graph.DialogueFolder) end
	
	--we have to wait until one of a few conditions comes true:
	--1. we get a response
	--2. we get a chain acknowledgement
	--3. we time out
	--4. the person walks away
	--5. the user manually ends it
	--so let's start listening before we tell the client about what we have
	
	local multiEvent = Instance.new("BindableEvent")
	local multiEventResult
	
	--listen for a response
	--we need to save the connection to disconnect it later
	local dialogueResponseChosenConnection
	local function onDialogueResponseChosen(respondingPlayer, responseIndex)
		if respondingPlayer == player then
			multiEvent:Fire{Type = "Response", ResponseIndex = responseIndex}
		end
	end
	dialogueResponseChosenConnection = self.Remotes.DialogueResponseChosen.OnServerEvent:connect(onDialogueResponseChosen)
	
	--listen for an acknowledgement of chaining
	local dialogueChainAcknowledgedConnection
	local function onDialogueChainAcknowledged(respondingPlayer)
		if respondingPlayer == player then
			multiEvent:Fire{Type = "ChainAcknowledged"}
		end
	end
	dialogueChainAcknowledgedConnection = self.Remotes.DialogueChainAcknowledged.OnServerEvent:connect(onDialogueChainAcknowledged)
	
	--listen for a manual end
	local dialogueUserEndedConnection
	local function onDialogueUserEnded(respondingPlayer)
		if respondingPlayer == player then
			multiEvent:Fire{Type = "UserEnded"}
		end
	end
	dialogueUserEndedConnection = self.Remotes.DialogueUserEnded.OnServerEvent:connect(onDialogueUserEnded)
	
	--listen for a time out
	if self.DialogueTimeOutTime > 0 then
		delay(self.DialogueTimeOutTime, function()
			multiEvent:Fire{Type = "TimeOut"}
		end)
	end
	
	--listen for a walk-away
	spawn(function()
		local part = self:GetClass"Utility":GetDialoguePart(folder)
		while (multiEventResult == nil) do
			local distance = player:DistanceFromCharacter(self:GetDialoguePosition(part, graph) + graph.TriggerOffset)
			if distance > graph.ConversationDistance then
				multiEvent:Fire{Type = "WalkAway"}
			end
			wait(1 / self.DialogueWalkAwayCheckFrequency)
		end
	end)
	
	--now that we're listening, let's send the information
	local promptLine = self:FormatDynamicText(prompt:GetLine(), player, graph.DialogueFolder, prompt)
	
	local chainedPrompt = prompt:GetValidPrompt()
	local responses = prompt:GetValidResponses()
	
	local function getData(node)
		local data = {}
		for key, val in pairs(graph.Data or {}) do
			data[key] = val
		end
		for key, val in pairs(node.Data or {}) do
			data[key] = val
		end
		return data
	end
	
	if chainedPrompt then
		--we send the prompt in a special function and wait for the client to acknowledge it
		--this puts the control in the hands of the developer, to make a continue button or just
		--do some kind of special timing based on the length, etc. etc.
		self.Remotes.DialoguePromptChained:FireClient(player, folder, {Line = promptLine, Data = getData(prompt)})
	else
		--collect the responses, sort them by order, and send them to the player
		table.sort(responses, function(a, b) return a.Order > b.Order end)
		local sentResponses = {}
		for _, response in pairs(responses) do
			local line = self:FormatDynamicText(response:GetLine(), player, graph.DialogueFolder, response)
			table.insert(sentResponses, {
				Line = line,
				Data = getData(response),
			})
		end
		
		self.Remotes.DialoguePromptShown:FireClient(player, folder, {Line = promptLine, Data = getData(prompt)}, sentResponses)
		
		--if we have no responses, then the conversation is over!
		--we still needed to send the prompt to the player, though
		--notify the player and break out
		if #responses == 0 then
			self.Remotes.DialogueFinished:FireClient(player, true)
			return
		end
	end
	
	--we've sent the information and we're listening for a response,
	--so now we wait for any of the previous conditions to come true
	multiEventResult = multiEvent.Event:wait()
	
	--we're done waiting, release the resources we used
	dialogueResponseChosenConnection:disconnect()
	dialogueChainAcknowledgedConnection:disconnect()
	dialogueUserEndedConnection:disconnect()
	
	--now perform an action based on the result type
	if multiEventResult.Type == "Response" then
		local response = responses[multiEventResult.ResponseIndex]
		
		--perform the action for this response
		if response.Action then response.Action(player, graph.DialogueFolder) end
		
		--recurse!
		self:PromptPlayer(player, folder, graph, response:GetValidPrompt())
	
	elseif multiEventResult.Type == "ChainAcknowledged" then
		self:PromptPlayer(player, folder, graph, chainedPrompt)
		
	elseif multiEventResult.Type == "TimeOut" then
		self.Remotes.DialogueTimedOut:FireClient(player)
		
	elseif multiEventResult.Type == "WalkAway" then
		self.Remotes.DialogueWalkedAway:FireClient(player)
	end
end

local Singleton = Server:New()
return Singleton