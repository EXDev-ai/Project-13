local Super = require(script.Parent)
local Prompt = Super:Extend()

function Prompt:OnNew()
	self:InitResponses()
	self:InitPrompts()
end

--//-------------------//--
--//--class variables--//--
--//-------------------//--

--dictionary<string, Variant> Data
--* custom data attached to this node
Prompt.Data = {}

--string Type
--* is this node a Prompt or Response?
Prompt.Type = "Prompt"

--Response[] Responses
--* the responses for this prompt that will be considered when this prompt is displayed.
--* only responses whose condition evaluates to true will be shown.
Prompt.Responses = {}
function Prompt:InitResponses()
	self.Responses = {}
end
function Prompt:GetResponses()
	return self.Responses
end
function Prompt:AddResponse(response)
	if not response:IsA(self:GetClass"Response") then
		error("Attempted to add a non-Response to Prompt.")
	end
	
	table.insert(self.Responses, response)
end
function Prompt:RemoveResponse(responseIn)
	for index, response in pairs(self.Responses) do
		if response == responseIn then
			table.remove(self.Responses, index)
			break
		end
	end
end
function Prompt:ClearResponses()
	self.Responses = {}
end

--Prompt[] Prompts
--* the prompts for this prompt to "chain into."
--* considered in the same way that prompts are considered from responses.
--* if a prompt has any prompts, they will be used instead of responses.
--* it is unintended behavior for prompts to have both prompts and responses.
Prompt.Prompts = {}
function Prompt:InitPrompts()
	self.Prompts = {}
end
function Prompt:GetPrompts()
	return self.Prompts
end
function Prompt:AddPrompt(prompt)
	if not prompt:IsA(self:GetClass"Prompt") then
		error("Attempted to add a non-Prompt to Prompt.")
	end
	
	table.insert(self.Prompts, prompt)
end
function Prompt:RemovePrompt(promptIn)
	for index = #self.Prompts, 1, -1 do
		local prompt = self.Prompts[index]
		if prompt == promptIn then
			table.remove(self.Prompts, index)
		end
	end
end
function Prompt:ClearPrompts()
	self.Prompts = {}
end
function Prompt:HasPrompts()
	return #self.Prompts > 0
end

--integer Priority
--* an integer which orders the prompts to be considered for a response.
--* the first valid prompt when examined in order is chosen.
Prompt.Priority = 0
function Prompt:GetPriority()
	return self.Priority
end
function Prompt:SetPriority(priority)
	self.Priority = priority
end

--string Line
--* the actual line of dialogue that would be shown to the interacting player.
Prompt.Line = ""
function Prompt:GetLine()
	return self.Line
end
function Prompt:SetLine(line)
	self.Line = line
end

--//----------------------//--
--//--method definitions--//--
--//----------------------//--

--Response[] GetValidResponses
--* evaluates the valid responses and returns them in a list.
function Prompt:GetValidResponses()
	local validResponses = {}
	for _, response in pairs(self:GetResponses()) do
		if response:IsValid() then
			table.insert(validResponses, response)
		end
	end
	
	return validResponses
end

--Prompt GetValidPrompt
--* returns the first valid prompt for this response.
function Prompt:GetValidPrompt()
	local validPrompts = {}
	for _, prompt in pairs(self:GetPrompts()) do
		if prompt:IsValid() then
			table.insert(validPrompts, prompt)
		end
	end
	table.sort(validPrompts, function(a, b) return a.Priority > b.Priority end)
	
	return validPrompts[1]
end

--boolean IsValid
--* if this Prompt has a condition, it returns the condition function's result.
--* otherwise, just return true.
function Prompt:IsValid()
	if self.Condition then
		return self.Condition(self.Graph.ConversingPlayer, self.Graph.DialogueFolder)
	end
	return true
end

return Prompt