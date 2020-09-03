local Class = {}

Class.Guis = script.Parent:WaitForChild("Guis")
Class.Remotes = script.Parent:WaitForChild("Remotes")

function Class:Extend(object)
	object = object or {}
	setmetatable(object, self)
	self.__index = self
	return object
end

function Class:New(object)
	object = self:Extend(object)
	if object.OnNew then
		object:OnNew()
	end
	return object
end

function Class:GetClass(className)
	return require(script:FindFirstChild(className, true))
end

function Class:IsA(class)
	local super = self
	while super do
		super = getmetatable(super)
		if super == class then
			return true
		end
		wait()
	end
	return false
end

function Class:TableHasValue(t, v)
	for _, val in pairs(t) do
		if val == v then
			return true
		end
	end
	return false
end

function Class:Lerp(a, b, w)
	return a + (b - a) * w
end

return Class
