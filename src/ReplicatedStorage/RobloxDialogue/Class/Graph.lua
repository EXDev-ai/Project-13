local Super = require(script.Parent)
local Graph = Super:Extend()

function Graph:OnNew()
	self:InitInitialPrompts()
end

--//-------------------//--
--//--class variables--//--
--//-------------------//--

--Prompt[] InitialPrompts
--* list of the possible initial prompts for this entire tree.
--* they are ordered by priority and the first valid one is chosen.
Graph.InitialPrompts = {}
function Graph:InitInitialPrompts()
	self.InitialPrompts = {}
end
function Graph:GetInitialPrompts()
	return self.InitialPrompts
end
function Graph:AddInitialPrompt(initialPrompt)
	if not initialPrompt:IsA(self:GetClass"Prompt") then
		error("Attempted to add a non-Prompt to Graph.")
	end
	
	table.insert(self.InitialPrompts, initialPrompt)
end
function Graph:RemoveInitialPrompt(initialPromptIn)
	for index, initialPrompt in pairs(self.InitialPrompts) do
		if initialPrompt == initialPromptIn then
			table.remove(self.InitialPrompts, index)
			break
		end
	end
end
function Graph:IsInitialPrompt(prompt)
	return self:TableHasValue(self.InitialPrompts, prompt)
end
function Graph:ClearInitialPrompts()
	self.InitialPrompts = {}
end

--float ConversationDistance
--* number representing the maximum distance at which a conversation with this character can be had.
Graph.ConversationDistance = 25
function Graph:GetConversationDistance()
	return self.ConversationDistance
end
function Graph:SetConversationDistance(conversationDistance)
	self.ConversationDistance = conversationDistance
end

--float TriggerDistance
--* distance at which this dialogue will automatically engage with any given player.
Graph.TriggerDistance = 0
function Graph:GetTriggerDistance()
	return self.TriggerDistance
end
function Graph:SetTriggerDistance(triggerDistance)
	self.TriggerDistance = triggerDistance
end

--Vector3 TriggerOffset
--* the offset at which TriggerDistance is considered.
--* in world space.
Graph.TriggerOffset = Vector3.new(0, 0, 0)
function Graph:GetTriggerOffset()
	return self.TriggerOffset
end
function Graph:SetTriggerOffset(triggerOffset)
	self.TriggerOffset = triggerOffset
end

--Roblox::Player ConversingPlayer
--* the player actively conversing with this graph.
Graph.ConversingPlayer = nil

--Roblox::Folder DialogueFolder
--* the folder that this graph loaded from.
Graph.DialogueFolder = nil

--//----------------------//--
--//--method definitions--//--
--//----------------------//--

--Prompt GetInitialPrompt
--* returns the first prompt for this graph
function Graph:GetInitialPrompt()
	local validPrompts = {}
	for _, prompt in pairs(self:GetInitialPrompts()) do
		if prompt:IsValid() then
			table.insert(validPrompts, prompt)
		end
	end
	table.sort(validPrompts, function(a, b) return a.Priority > b.Priority end)
	
	return validPrompts[1]
end

--string NameFromLine(string)
--* takes a Response/Prompt Line and makes a name.
--* for somewhat saner folder structures.
function Graph:NameFromLine(line)
	line = line:gsub("%p", "")
	
	local name = ""
	for word in line:gmatch(".- ") do
		local capitalized = word:sub(1, 1):upper()..word:sub(2)
		capitalized = capitalized:gsub("%s", "")
		
		name = name..capitalized
		
		if #name > 16 then
			break
		end
	end
	
	return name
end

--Roblox::Folder Save
--* compiles the nodegraph into ROBLOX objects and returns it
function Graph:Save()
	--some classes we'll need
	local Response = self:GetClass"Response"
	local Prompt = self:GetClass"Prompt"
	
	--this table will hold each node in the graph
	local nodes = self:GetNodes()
	
	--create a folder
	local folder = Instance.new("Folder")
	folder.Name = "RobloxDialogue"
	
	--create a folder for each node
	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "Nodes"
	nodesFolder.Parent = folder
	
	--pass #1: create unlinked nodes
	for _, node in pairs(nodes) do
		local nodeFolder = Instance.new("Folder")
		
		local line = Instance.new("StringValue")
		line.Name = "Line"
		line.Value = node:GetLine()
		line.Parent = nodeFolder
		
		if node.PluginGuiPosition then
			local pluginGuiPosition = Instance.new("Vector3Value")
			pluginGuiPosition.Name = "PluginGuiPosition"
			pluginGuiPosition.Value = Vector3.new(node.PluginGuiPosition.X, node.PluginGuiPosition.Y)
			pluginGuiPosition.Parent = nodeFolder
		end
		
		if node.DataScript then
			node.DataScript = node.DataScript:Clone()
			node.DataScript.Parent = nodeFolder
		end
		
		if node:IsA(Prompt) then
			nodeFolder.Name = "Prompt"..self:NameFromLine(node:GetLine())
			
			local priority = Instance.new("IntValue")
			priority.Name = "Priority"
			priority.Value = node:GetPriority()
			priority.Parent = nodeFolder
			
			local responses = Instance.new("Folder")
			responses.Name = "Responses"
			responses.Parent = nodeFolder
			
			if node:HasPrompts() then
				local prompts = Instance.new("Folder")
				prompts.Name = "Prompts"
				prompts.Parent = nodeFolder
			end
		
		elseif node:IsA(Response) then
			nodeFolder.Name = "Response"..self:NameFromLine(node:GetLine())
			
			local order = Instance.new("IntValue")
			order.Name = "Order"
			order.Value = node:GetOrder()
			order.Parent = nodeFolder
			
			local prompts = Instance.new("Folder")
			prompts.Name = "Prompts"
			prompts.Parent = nodeFolder
		end
		
		if node.ActionScript then
			node.ActionScript.Parent = nodeFolder
		end
		if node.ConditionScript then
			node.ConditionScript.Parent = nodeFolder
		end
		
		nodeFolder.Parent = nodesFolder
		node.SaveFolder = nodeFolder
	end
	
	--pass #2: link the nodes
	for _, node in pairs(nodes) do
		if node:IsA(Prompt) then
			for _, response in pairs(node:GetResponses()) do
				local reference = Instance.new("ObjectValue")
				reference.Name = "Reference"
				reference.Value = response.SaveFolder
				reference.Parent = node.SaveFolder.Responses
			end
			
			if node:HasPrompts() then
				for _, prompt in pairs(node:GetPrompts()) do
					local reference = Instance.new("ObjectValue")
					reference.Name = "Reference"
					reference.Value = prompt.SaveFolder
					reference.Parent = node.SaveFolder.Prompts
				end
			end
			
		elseif node:IsA(Response) then
			for _, prompt in pairs(node:GetPrompts()) do
				local reference = Instance.new("ObjectValue")
				reference.Name = "Reference"
				reference.Value = prompt.SaveFolder
				reference.Parent = node.SaveFolder.Prompts
			end
		end
	end
	
	--create references to each initial prompt
	local initialPromptsFolder = Instance.new("Folder")
	initialPromptsFolder.Name = "InitialPrompts"
	initialPromptsFolder.Parent = folder
	
	for _, initialPrompt in pairs(self:GetInitialPrompts()) do
		local reference = Instance.new("ObjectValue")
		reference.Name = "Reference"
		reference.Value = initialPrompt.SaveFolder
		reference.Parent = initialPromptsFolder
	end
	
	--save our conversation distance
	local conversationDistance = Instance.new("NumberValue")
	conversationDistance.Name = "ConversationDistance"
	conversationDistance.Value = self:GetConversationDistance()
	conversationDistance.Parent = folder
	
	--save our trigger distance
	local triggerDistance = Instance.new("NumberValue")
	triggerDistance.Name = "TriggerDistance"
	triggerDistance.Value = self:GetTriggerDistance()
	triggerDistance.Parent = folder
	
	--save our trigger offset
	local triggerOffset = Instance.new("Vector3Value")
	triggerOffset.Name = "TriggerOffset"
	triggerOffset.Value = self:GetTriggerOffset()
	triggerOffset.Parent = folder
	
	--save our data script
	if self.DataScript then
		self.DataScript = self.DataScript:Clone()
		self.DataScript.Parent = folder
	end
	
	--all done, return the folder
	return folder
end

--Load(Roblox::Folder)
--* takes a saved graph and loads it into lua data.
--* overwrites this current graph.
function Graph:Load(folder)
	self.DialogueFolder = folder
	
	--some classes we'll need for later
	local Response = self:GetClass"Response"
	local Prompt = self:GetClass"Prompt"
	
	--define a dictionary
	--key: Roblox::Folder
	--val: DialogueNode (Response or Prompt)
	local nodesByFolder = {}
	
	--helper function, gets dialogue node type of folder
	local function getNodeType(nodeFolder)
		if nodeFolder.Name:sub(1, 8) == "Response" then
			return "Response"
		else
			return "Prompt"
		end
	end
	
	--pass #1: define each node
	local nodeFolders = folder.Nodes:GetChildren()
	
	for _, nodeFolder in pairs(nodeFolders) do
		local node
		
		if getNodeType(nodeFolder) == "Response" then
			local response = Response:New()
			response:SetLine(nodeFolder.Line.Value)
			response:SetOrder(nodeFolder.Order.Value)
			nodesByFolder[nodeFolder] = response
			node = response
			
		else
			local prompt = Prompt:New()
			prompt:SetLine(nodeFolder.Line.Value)
			prompt:SetPriority(nodeFolder.Priority.Value)
			nodesByFolder[nodeFolder] = prompt
			node = prompt
		end
		
		if nodeFolder:FindFirstChild("DataScript") then
			node.DataScript = nodeFolder.DataScript
			node.Data = require(nodeFolder.DataScript) 
		end
		
		--whether it's a response or prompt, it needs to know a few things:
		node.Graph = self
		if nodeFolder:FindFirstChild("Condition") then
			local read, condition = pcall(function() return require(nodeFolder.Condition) end)
			if read then
				node.Condition = condition
			else
				warn(string.format("%s with line starting '%s...' failed to load Condition, please fix errors.", node.Type, node.Line:sub(1, 16)))
			end
			node.ConditionScript = nodeFolder.Condition:Clone()
		end
		if nodeFolder:FindFirstChild("Action") then
			local read, action = pcall(function() return require(nodeFolder.Action) end)
			if read then
				node.Action = action
			else
				warn(string.format("%s with line starting '%s...' failed to load Action, please fix errors.", node.Type, node.Line:sub(1, 16)))
			end
			node.ActionScript = nodeFolder.Action:Clone()
		end
		if nodeFolder:FindFirstChild("PluginGuiPosition") then
			local position = nodeFolder.PluginGuiPosition.Value
			node.PluginGuiPosition = Vector2.new(position.X, position.Y)
		end
	end
	
	--pass #2: link the nodes
	for _, nodeFolder in pairs(nodeFolders) do
		local node = nodesByFolder[nodeFolder]
		
		if node:IsA(Response) then
			for __, promptReference in pairs(nodeFolder.Prompts:GetChildren()) do
				local prompt = nodesByFolder[promptReference.Value]
				node:AddPrompt(prompt)
			end
		else
			for __, responseReference in pairs(nodeFolder.Responses:GetChildren()) do
				local response = nodesByFolder[responseReference.Value]
				node:AddResponse(response)
			end
			
			if nodeFolder:FindFirstChild("Prompts") then
				for __, promptReference in pairs(nodeFolder.Prompts:GetChildren()) do
					local prompt = nodesByFolder[promptReference.Value]
					node:AddPrompt(prompt)
				end
			end
		end
	end
	
	--set up initial prompts
	self:ClearInitialPrompts()
	
	for _, initialPromptReference in pairs(folder.InitialPrompts:GetChildren()) do
		local initialPrompt = nodesByFolder[initialPromptReference.Value]
		self:AddInitialPrompt(initialPrompt)
	end
	
	--load in conversation distance
	self:SetConversationDistance(folder.ConversationDistance.Value)
	
	--load in trigger distance
	self:SetTriggerDistance(folder.TriggerDistance.Value)
	
	--load in trigger offset
	self:SetTriggerOffset(folder.TriggerOffset.Value)
	
	if folder:FindFirstChild("DataScript") then
		self.DataScript = folder.DataScript
		self.Data = require(folder.DataScript)
	end
end

--Node[] GetNodes()
--* returns every node linked to this graph
function Graph:GetNodes()
	local nodes = {}
	local function recurse(node)
		if self:TableHasValue(nodes, node) then return end
		table.insert(nodes, node)
		
		local function append(a, b)
			for _, v in pairs(a) do
				table.insert(b, v)
				wait()
			end
		end
		
		local children = {}
		if node.Type == "Prompt" then
			append(node.Prompts, children)
			wait()
			append(node.Responses, children)
		else
			append(node.Prompts, children)
		end
		
		for _, child in pairs(children) do
			recurse(child)
		end
	end
	for _, initialPrompt in pairs(self.InitialPrompts) do
		recurse(initialPrompt)
	end
	return nodes
end

return Graph