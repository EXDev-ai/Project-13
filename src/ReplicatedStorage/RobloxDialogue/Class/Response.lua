local Super = require(script.Parent)
local Response = Super:Extend()

function Response:OnNew()
	self:InitPrompts()
end

--//-------------------//--
--//--class variables--//--
--//-------------------//--

--dictionary<string, Variant> Data
--* custom data attached to this node
Response.Data = {}

--string Type
--* is this node a Prompt or Response?
Response.Type = "Response"

--Prompt[] Prompts
--* the prompts which this response could possibly evaluate to.
--* the prompts are ordered by their priority and examined.
--* the first valid prompt is used.
Response.Prompts = {}
function Response:InitPrompts()
	self.Prompts = {}
end
function Response:GetPrompts()
	return self.Prompts
end
function Response:AddPrompt(prompt)
	if not prompt:IsA(self:GetClass"Prompt") then
		error("Attempted to add a non-Prompt to a Response.")
	end
	
	table.insert(self.Prompts, prompt)
end
function Response:RemovePrompt(promptIn)
	for index, prompt in pairs(self.Prompts) do
		if prompt == promptIn then
			table.remove(self.Prompts, index)
			break
		end
	end
end
function Response:ClearPrompts()
	self.Prompts = {}
end

--string Line
--* the string which the player responds to the interactable with.
--* essentially, what the player says in response to a prompt.
Response.Line = ""
function Response:GetLine()
	return self.Line
end
function Response:SetLine(line)
	self.Line = line
end

--integer Order
--* responses are sorted by this number in order to determine in which order they appear.
Response.Order = 1
function Response:GetOrder()
	return self.Order
end
function Response:SetOrder(order)
	self.Order = order
end

--//----------------------//--
--//--method definitions--//--
--//----------------------//--

--Prompt GetValidPrompt
--* returns the first valid prompt for this response.
function Response:GetValidPrompt()
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
--* returns whether this response is available.
--* if we have a condition set, we use it.
function Response:IsValid()
	if self.Condition then
		return self.Condition(self.Graph.ConversingPlayer, self.Graph.DialogueFolder)
	end
	return true
end

return Response
