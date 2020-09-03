local Super = require(script.Parent)
local Utility = Super:Extend()

function Utility:GetDialoguePart(folder)
	local parent = folder.Parent
	local part = nil
	
	if parent:IsA("BasePart") then
		part = parent
	elseif parent:IsA("Model") then
		if parent:FindFirstChild("Humanoid") and parent:FindFirstChild("Head") then
			part = parent.Head
		else
			part = parent.PrimaryPart
		end
	end
	
	return part
end

function Utility:GetChatAdornee(partOrCharacter)
	if partOrCharacter:IsA("BasePart") then
		return partOrCharacter
	else
		local head = partOrCharacter:FindFirstChild("Head")
		if head then
			return head
		else
			error(string.format("Couldn't find an adornee for '%s' -- are you sure you passed in the right thing?", partOrCharacter:GetFullName()))
		end
	end
end

local Singleton = Utility:New()
return Singleton