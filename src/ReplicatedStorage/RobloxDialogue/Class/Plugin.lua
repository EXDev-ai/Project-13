local Super = require(script.Parent)
local Plugin = Super:Extend()

function Plugin:OnNew()
	self:InitToolbar()
	self:InitContextHints()
	self:InitGui()
	
	self.Selections = {}
end

function Plugin:IsSelected(gui)
	return self:TableHasValue(self.Selections, gui)
end

function Plugin:Select(gui)
	if self:IsSelected(gui) then return end
	
	table.insert(self.Selections, gui)
	
	local bSize = Instance.new("IntValue")
	bSize.Name = "OrigBorderSize"
	bSize.Value = gui.BorderSizePixel
	bSize.Parent = gui
	
	local bColor = Instance.new("Color3Value")
	bColor.Name = "OrigBorderColor"
	bColor.Value = gui.BorderColor3
	bColor.Parent = gui
	
	gui.BorderSizePixel = 6
	gui.BorderColor3 = Color3.fromRGB(18, 238, 212) --teal
end

function Plugin:OnGuiDeselected(gui)
	if gui:FindFirstChild("OrigBorderSize") then
		gui.BorderSizePixel = gui.OrigBorderSize.Value
		gui.OrigBorderSize:Destroy()
	end
	
	if gui:FindFirstChild("OrigBorderColor") then
		gui.BorderColor3 = gui.OrigBorderColor.Value
		gui.OrigBorderColor:Destroy()
	end
end

function Plugin:Deselect(gui)
	for index = #self.Selections, 1, -1 do
		local obj = self.Selections[index]
		if obj == gui then
			table.remove(self.Selections, index)
			self:OnGuiDeselected(gui)
		end
	end
end

function Plugin:ClearSelections()
	for index = #self.Selections, 1, -1 do
		self:OnGuiDeselected(self.Selections[index])
		table.remove(self.Selections, index)
	end
end

function Plugin:InitToolbar()
	self.Toolbar = self.Plugin:CreateToolbar("Roblox Dialogue II")
	
	self.EditButton = self.Toolbar:CreateButton("Dialogue Editor", "Edit dialogues.", "http://www.roblox.com/asset/?id=145360615")
	local function onClick() self:EditDialogue() end
	self.EditButton.Click:connect(onClick)
	
	self.AddButton = self.Toolbar:CreateButton("Create Dialogue", "Create a dialogue in the selected object.", "rbxassetid://17426453")
	local function onAddClick() self:AddDialogue() end
	self.AddButton.Click:connect(onAddClick)
	
	self.InstallButton = self.Toolbar:CreateButton("Reinstall Scripts", "Refresh all the scripts related to dialogue.", "rbxassetid://145360580")
	local function onInstallClick() self:Install() end
	self.InstallButton.Click:connect(onInstallClick)
end

function Plugin:InitGui()
	self.ScreenGui = Instance.new("ScreenGui")
	self.ScreenGui.Name = "DialogueEditorScreenGui"
	self.ScreenGui.Parent = game:GetService("CoreGui")
	
	local function onDescendantAdded(object)
		if object.Name == "ContextHint" then
			self:AddContextHint(object)
		end
	end
	self.ScreenGui.DescendantAdded:connect(onDescendantAdded)
end

function Plugin:InitContextHints()
	local context = {}
	context.LastMouseMove = tick()
	context.CurrentHint = nil
	context.HintGui = nil
	context.HoverTime = 0.75
	context.HoveredGui = nil
	
	self.ContextHints = context
	
	local function update()
		if not self.EditingDialogue then
			return
		end
		
		if not context.CurrentHint then
			if context.HintGui then
				context.HintGui:Destroy()
				context.HintGui = nil
			end
		else
			local timeSince = tick() - context.LastMouseMove
			if timeSince >= context.HoverTime then
				self:ShowContextHint(context.CurrentHint)
			end
		end
	end
	game:GetService("RunService").Heartbeat:connect(update)
	
	local uis = game:GetService("UserInputService")
	local function onMouseMoved()
		local gui = context.HoveredGui
		if not gui then return end
		
		local topLeft = gui.AbsolutePosition
		local botRight = topLeft + gui.AbsoluteSize
		
		local position = uis:GetMouseLocation()
		
		local inX = (position.X > topLeft.X) and (position.X < botRight.X)
		local inY = (position.Y > topLeft.Y) and (position.Y < botRight.Y)
		
		if (not inX) or (not inY) then
			context.CurrentHint = nil
		end
	end
	
	local function onInputChanged(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			onMouseMoved()
		end
	end
	uis.InputChanged:connect(onInputChanged)
end

function Plugin:ShowContextHint(hint)
	local context = self.ContextHints
	if context.HintGui then return end
	
	local gui = self.DataFolder.Guis.Plugin.ContextHintGui:Clone()
	
	local guiSize = Vector2.new(gui.Size.X.Offset, gui.Size.Y.Offset)
	local size = game:GetService("TextService"):GetTextSize(hint, gui.TextSize, gui.Font, guiSize)
	gui.Size = UDim2.new(0, size.X, 0, size.Y)
	
	local mousePosition = game:GetService("UserInputService"):GetMouseLocation()
	gui.Position = UDim2.new(0, mousePosition.X, 0, mousePosition.Y)
	
	gui.Text = hint
	gui.Parent = self.ScreenGui
	
	if gui.AbsolutePosition.X + gui.AbsoluteSize.X > self.ScreenGui.AbsoluteSize.X then
		gui.AnchorPoint = Vector2.new(1, gui.AnchorPoint.Y)
	end
	
	if gui.AbsolutePosition.Y - gui.AbsoluteSize.Y < 0 then
		gui.AnchorPoint = Vector2.new(gui.AnchorPoint.X, 0)
	end
	
	context.HintGui = gui
end

function Plugin:AddContextHint(contextHint)
	local gui = contextHint.Parent
	if not gui:IsA("GuiObject") then return end
	
	local context = self.ContextHints
	
	local function onMouseMoved()
		context.HoveredGui = gui
		context.LastMouseMove = tick()
		context.CurrentHint = contextHint.Value
	end
	gui.MouseMoved:connect(onMouseMoved)
	
	local function onMouseLeave()
		context.HoveredGui = nil
		context.LastMouseMove = tick()
		context.CurrentHint = nil
	end
	gui.MouseLeave:connect(onMouseLeave)
end

function Plugin:IsDialogue(object)
	if not object then return false end
	return (object:IsA("Folder") and object.Name == "RobloxDialogue")
end

function Plugin:Prompt(message)
	if self.Prompting then return false end
	self.Prompting = true
	
	local gui = self.Guis.Plugin.PromptFrame:Clone()
	gui.TitleText.Text = message
	gui.Parent = self.ScreenGui
	
	local event = Instance.new("BindableEvent")
	
	local function onYesClick()
		event:Fire(true)
	end
	gui.YesButton.MouseButton1Click:connect(onYesClick)
	
	local function onNoClick()
		event:Fire(false)
	end
	gui.NoButton.MouseButton1Click:connect(onNoClick)
	
	local result = event.Event:wait()
	
	gui:Destroy()
	self.Prompting = false
	
	return result
end

function Plugin:NodeGuiStyleInitialPrompt(gui)
	gui.TypeLabel.Text = "InitialPrompt"
	gui.MoveButton.BackgroundColor3 = Color3.new(239/255, 184/255, 56/255) --gold
	gui.BorderSizePixel = 3
end

function Plugin:NodeGuiStyleNormal(gui)
	gui.TypeLabel.Text = "Prompt"
	gui.MoveButton.BackgroundColor3 = Color3.fromRGB(204, 203, 172)
	gui.BorderSizePixel = 1
end

function Plugin:GetInitialConditionSource()
	return self.DataFolder.Scripts.InitialCondition.Source
end

function Plugin:GetInitialActionSource()
	return self.DataFolder.Scripts.InitialAction.Source
end

function Plugin:SetPromptInitial(prompt, isInitial)
	if isInitial then
		if self.Graph:IsInitialPrompt(prompt) then return end
		self.Graph:AddInitialPrompt(prompt)
		self:NodeGuiStyleInitialPrompt(prompt.PluginGui)
	else
		if not self.Graph:IsInitialPrompt(prompt) then return end
		self.Graph:RemoveInitialPrompt(prompt)
		self:NodeGuiStyleNormal(prompt.PluginGui)
	end
end

function Plugin:MakeNodeGui(node, index)
	local nodeType = node.Type
	
	--create the gui
	local gui = self.Guis.Plugin.NodeFrame:Clone()
	
	if nodeType == "Prompt" then
		gui.MoveButton.BackgroundColor3 = Color3.fromRGB(204, 203, 172)
	else
		gui.MoveButton.BackgroundColor3 = Color3.fromRGB(152, 190, 204)
	end
	
	--some variables for the node to remember
	node.PluginGui = gui
	node.PluginColor = self:GetUniqueColor()
	
	--display the type and line
	gui.TypeLabel.Text = nodeType
	gui.TextBoxFrame.TextBox.Text = node.Line
	
	--do we have their location already?
	if node.PluginGuiPosition then
		gui.Position = UDim2.new(0, node.PluginGuiPosition.X, 0, node.PluginGuiPosition.Y)
	
	--if not, throw it somewhere random
	else
		local t = index - 1
		local rows = 5
		local columns = 5
		local x = (1 / columns) * (math.floor(t / rows) + 1)
		local y = (1 / rows) * (t % columns)
		gui.Position = UDim2.new(x, 32 + t, y, 32 + t)
		
		if index == -1 then
			gui.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
	end
	
	--if the user clicks and drags on the move button, we move
	local moveConnection
	local mouseUpConnection
	local onMoveMouseUp
	local function onMoveMouseDown(mouseX, mouseY)
		local uis = game:GetService("UserInputService")
		
		if (not self:IsSelected(gui)) and (not uis:IsKeyDown(Enum.KeyCode.LeftControl)) then
			self:ClearSelections()
		end
		if self:IsSelected(gui) and uis:IsKeyDown(Enum.KeyCode.LeftControl) then
			self:Deselect(gui)
		else
			self:Select(gui)
		end
		
		local mousePos = Vector2.new(mouseX, mouseY)
		local offset = mousePos - gui.AbsolutePosition
		
		local function onInputChanged(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local position = input.Position
				local here = gui.Position
				local there = UDim2.new(0, input.Position.X - offset.X, 0, input.Position.Y - offset.Y)
				local delta = there - here
				
				--move our selected guis
				for _, selection in pairs(self.Selections) do
					selection.Position = selection.Position + delta
				end
			end
		end
		moveConnection = uis.InputChanged:connect(onInputChanged)
		
		local function onInputEnded(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onMoveMouseUp()
			end
		end
		mouseUpConnection = uis.InputEnded:connect(onInputEnded)
	end
	onMoveMouseUp = function()
		if moveConnection then moveConnection:disconnect() end
		if mouseUpConnection then mouseUpConnection:disconnect() end
	end
	gui.MoveButton.MouseButton1Down:connect(onMoveMouseDown)
	gui.MoveButton.MouseButton1Up:connect(onMoveMouseUp)
	
	--clicking on the text box expands our _minds_, or maybe just our text box. yeah.
	local function shiftZIndex(object, zIndexDelta)
		if object:IsA("GuiObject") then
			object.ZIndex = object.ZIndex + zIndexDelta
		end
		for _, child in pairs(object:GetChildren()) do
			shiftZIndex(child, zIndexDelta)
		end
	end
	local textBox = gui.TextBoxFrame.TextBox
	local focusZIndexDelta = 3
	local focusSizeDelta = UDim2.new(0, 256, 0, textBox.TextSize * 6)
	local focused = false
	local function onFocused()
		if focused then return end
		focused = true
		
		shiftZIndex(gui, focusZIndexDelta)
		gui.Size = gui.Size + focusSizeDelta
	end
	local function onFocusLost()
		if not focused then return end
		focused = false
		
		shiftZIndex(gui, -focusZIndexDelta)
		gui.Size = gui.Size - focusSizeDelta
		
		node.Line = textBox.Text
	end
	textBox.Focused:connect(onFocused)
	textBox.FocusLost:connect(onFocusLost)
	
	--clicking on the add connection button drags a bezier curve to the mouse, and when we release on another node, we connect them
	local uis = game:GetService("UserInputService")
	
	local addConnectionButton = gui.AddConnectionButton
	local function onAddConnectionMouseButton1Down()
		local inputChangedC
		local inputEndedC
		
		local curve = Instance.new("Folder")
		curve.Parent = self.ScreenGui
		
		local otherGuiTables = {}
		for _, otherNode in pairs(self.Nodes) do
			if otherNode ~= node then
				local otherNodeType = otherNode.Type
				
				local function isChild(child)
					if nodeType == "Response" then
						return self:TableHasValue(node.Prompts, child)
					else
						return self:TableHasValue(node.Responses, child)
					end
				end
				
				local function canDropOn()
					if isChild(otherNode) then
						return false
					end
					
					if nodeType == "Prompt" then
						return (otherNode ~= node)
					else
						return otherNodeType == "Prompt"
					end
				end
				
				if canDropOn() then
					local otherGui = otherNode.PluginGui
					otherGui.AddConnectionButton.Visible = false
					otherGui.DropConnectionButton.Visible = true
					
					local connection
					local function onDropConnectionMouseUp()
						--we don't do this if we're holding control
						if uis:IsKeyDown(Enum.KeyCode.LeftControl) then return end
						
						if nodeType == "Prompt" then
							if otherNodeType == "Prompt" then
								node:AddPrompt(otherNode)
							else
								node:AddResponse(otherNode)
							end
						else
							node:AddPrompt(otherNode)
						end
						self:ConnectNodeGuis(node, otherNode)
					end
					connection = otherGui.DropConnectionButton.MouseButton1Up:connect(onDropConnectionMouseUp)
					
					table.insert(otherGuiTables, {Gui = otherGui, Connection = connection})
				end
			end
		end
		
		local function onInputChanged(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			
			local position = addConnectionButton.AbsolutePosition + addConnectionButton.AbsoluteSize / 2
			self:DrawBezier(3, position, self:ToVector2(input.Position), Color3.new(0, 0, 0), curve)
		end
		
		local function onInputEnded(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			
			curve:Destroy()
			inputChangedC:disconnect()
			inputEndedC:disconnect()
			
			for _, otherGuiTable in pairs(otherGuiTables) do
				otherGuiTable.Connection:disconnect()
				
				local otherGui = otherGuiTable.Gui
				otherGui.AddConnectionButton.Visible = true
				otherGui.DropConnectionButton.Visible = false
			end
			
			--if we're holding control, we create a new node at that location and connect it
			if uis:IsKeyDown(Enum.KeyCode.LeftControl) then
				local newNode
				
				if nodeType == "Prompt" then
					newNode = self:GetClass"Response":New()
					node:AddResponse(newNode)
				else
					newNode = self:GetClass"Prompt":New()
					node:AddPrompt(newNode)
				end
				
				local gui = self:MakeNodeGui(newNode, -1)
				local offset = gui.DropConnectionButton.AbsolutePosition + (gui.DropConnectionButton.AbsoluteSize / 2) - gui.AbsolutePosition
				local mousePosition = uis:GetMouseLocation()
				gui.Position = UDim2.new(0, mousePosition.X - offset.X, 0, mousePosition.Y - offset.Y)
				
				table.insert(self.Nodes, newNode)
				
				self:ConnectNodeGuis(node, newNode)
			end
		end
		
		inputChangedC = uis.InputChanged:connect(onInputChanged)
		inputEndedC = uis.InputEnded:connect(onInputEnded)
	end
	addConnectionButton.MouseButton1Down:connect(onAddConnectionMouseButton1Down)
	
	--clicking on the break connections buttons breaks connection
	local function onBreakConnectionsChildrenMouseClick()
		if nodeType == "Response" then
			for _, prompt in pairs(node:GetPrompts()) do
				self:RemoveNodeConnection(node, prompt)
			end
			node:ClearPrompts()
		else
			for _, response in pairs(node:GetResponses()) do
				self:RemoveNodeConnection(node, response)
			end
			node:ClearResponses()
			
			for _, prompt in pairs(node:GetPrompts()) do
				self:RemoveNodeConnection(node, prompt)
			end
			node:ClearPrompts()
		end
	end
	gui.BreakConnectionsChildrenButton.MouseButton1Click:connect(onBreakConnectionsChildrenMouseClick)
	
	local function onBreakConnectionsParentMouseClick()
		for _, otherNode in pairs(self.Nodes) do
			local otherNodeType = otherNode.Type
			
			if (nodeType == "Response") and (otherNodeType == "Prompt") and self:TableHasValue(otherNode:GetResponses(), node) then
				self:RemoveNodeConnection(otherNode, node)
				otherNode:RemoveResponse(node)
			end
			
			if (nodeType == "Prompt") and self:TableHasValue(otherNode:GetPrompts(), node) then
				self:RemoveNodeConnection(otherNode, node)
				otherNode:RemovePrompt(node)
			end
		end
	end
	gui.BreakConnectionsParentButton.MouseButton1Click:connect(onBreakConnectionsParentMouseClick)
	
	--clicking the delete button *gasp* deletes the node
	local function onDeleteMouseClick()
		--make sure they want to
		if not self:Prompt("Are you sure you want to delete this?") then return end
		
		--break all connections
		onBreakConnectionsChildrenMouseClick()
		onBreakConnectionsParentMouseClick()
		
		--delete the gui
		node.PluginGui:Destroy()
		
		--remove it from our personal list
		local index = 1
		local count = #self.Nodes
		while index <= count do
			local n = self.Nodes[index]
			if n == node then
				table.remove(self.Nodes, index)
				count = count - 1
			else
				index = index + 1
			end
			wait()
		end
	end
	gui.DeleteButton.MouseButton1Click:connect(onDeleteMouseClick)
	
	--if we're a prompt, we have to know if we're initial or not (and switch)
	if nodeType == "Prompt" then
		local function onInitialMouseClick()
			--we first deselect it when we change the style
			local wasSelected = self:IsSelected(gui)
			if wasSelected then
				self:Deselect(gui)
			end
			
			self:SetPromptInitial(node, not self.Graph:IsInitialPrompt(node))
			
			--now we reselect it afterwards
			if wasSelected then
				self:Select(gui)
			end
		end
		gui.InitialPromptButton.Visible = true
		gui.InitialPromptButton.MouseButton1Click:connect(onInitialMouseClick)
		
		if self.Graph:IsInitialPrompt(node) then
			self:NodeGuiStyleInitialPrompt(gui)
		end
	end
	
	--if we click the condition button, let's edit our condition
	local function updateConditionButton()
		if node.ConditionScript ~= nil then
			gui.ConditionButton.BorderColor3 = Color3.new(1, 0, 0)
		else
			gui.ConditionButton.BorderColor3 = Color3.new(0, 0, 0)
		end
	end
	updateConditionButton()
	
	local function onConditionClick()
		if not node.ConditionScript then
			node.ConditionScript = Instance.new("ModuleScript")
			node.ConditionScript.Name = "Condition"
			node.ConditionScript.Source = self:GetInitialConditionSource()
			node.ConditionScript.Parent = self.DataFolder
			gui.ConditionButton.BorderColor3 = Color3.new(1, 0, 0)
			updateConditionButton()
		end
		self.Plugin:OpenScript(node.ConditionScript)
	end
	gui.ConditionButton.MouseButton1Click:connect(onConditionClick)
	
	--if we click on the delete condition button, let's delete our condition
	local function onDeleteConditionClick()
		if node.ConditionScript then
			node.ConditionScript:Destroy()
			node.ConditionScript = nil
			updateConditionButton()
			gui.DeleteConditionButton.Visible = false
		end
	end
	gui.DeleteConditionButton.MouseButton1Click:connect(onDeleteConditionClick)
	
	--if we click on the action button, let's edit our action
	local function updateActionButton()
		if node.ActionScript ~= nil then
			gui.ActionButton.BorderColor3 = Color3.new(1, 0, 0)
		else
			gui.ActionButton.BorderColor3 = Color3.new(0, 0, 0)
		end
	end
	updateActionButton()
	
	local function onActionClick()
		if not node.ActionScript then
			node.ActionScript = Instance.new("ModuleScript")
			node.ActionScript.Name = "Action"
			node.ActionScript.Source = self:GetInitialActionSource()
			node.ActionScript.Parent = self.DataFolder
			updateActionButton()
		end
		self.Plugin:OpenScript(node.ActionScript)
	end
	gui.ActionButton.MouseButton1Click:connect(onActionClick)
	
	--if we click on the delete action button, let's delete our action
	local function onDeleteActionClick()
		if node.ActionScript then
			node.ActionScript:Destroy()
			node.ActionScript = nil
			updateActionButton()
			gui.DeleteActionButton.Visible = false
		end
	end
	gui.DeleteActionButton.MouseButton1Click:connect(onDeleteActionClick)
	
	--the priority/order box
	local function updatePriority()
		--this acts exactly like the condition ? valueIfTrue : valueIfFalse statement from C++
		gui.PriorityFrame.TypeText.Text = (nodeType == "Response") and "Order" or "Priority"
		gui.PriorityFrame.NumberBox.Text = (nodeType == "Response") and node.Order or node.Priority
	end
	updatePriority()
	
	local function onPriorityFocusLost()
		local number = tonumber(gui.PriorityFrame.NumberBox.Text)
		if not number then
			gui.PriorityFrame.NumberBox.Text = "0"
			number = 0
		end
		number = math.floor(number)
		
		if nodeType == "Response" then
			node:SetOrder(number)
		else
			node:SetPriority(number)
		end
		updatePriority()
	end
	gui.PriorityFrame.NumberBox.FocusLost:connect(onPriorityFocusLost)
	
	--edit data button allows to edit meta data for the node
	local function onDataClick()
		if node.DataScript then
			self.Plugin:OpenScript(node.DataScript)
		else
			local ms = self.DataFolder.Scripts.InitialDataScript:Clone()
			ms.Name = "DataScript"
			ms.Parent = self.DataFolder
			
			node.DataScript = ms
			
			self.Plugin:OpenScript(ms)
		end
	end
	gui.DataButton.MouseButton1Click:connect(onDataClick)
	
	--parent and set up everything
	gui.Parent = self.ScreenGui
	
	return gui
end

function Plugin:RemoveNodeConnection(parent, child)
	local index = 1
	local count = #self.NodeConnections
	while index <= count do
		local nodeConnection = self.NodeConnections[index]
		
		if (nodeConnection.Parent == parent) and (nodeConnection.Child == child) then
			table.remove(self.NodeConnections, index)
			
			nodeConnection.GuiFolder:Destroy()
			nodeConnection.ParentConnection:disconnect()
			nodeConnection.ChildConnection:disconnect()
			
			count = count - 1
		else
			index = index + 1
		end
	end
end

function Plugin:GetNodeFromGui(gui)
	for _, node in pairs(self.Nodes) do
		if node.PluginGui == gui then
			return node
		end
	end
end

function Plugin:ToVector2(vector3)
	return Vector2.new(vector3.X, vector3.Y)
end

function Plugin:GenerateUniqueColors()
	if self.UniqueColors then return end
	
	self.UniqueColors = {}
	
	--generate
	for r = 0.3, 0.7, 0.1 do
		for g = 0.3, 0.7, 0.1 do
			for b = 0.3, 0.7, 0.1 do
				table.insert(self.UniqueColors, Color3.new(r, g, b))
			end
		end
	end
	
	--shuffle
	local colorCount = #self.UniqueColors
	for index = 1, colorCount do
		local random = math.random(1, colorCount)
		local temp = self.UniqueColors[index]
		self.UniqueColors[index] = self.UniqueColors[random]
		self.UniqueColors[random] = temp
	end
	
	self.UniqueColorIndex = 0
end

function Plugin:GetUniqueColor()
	self:GenerateUniqueColors()
	
	self.UniqueColorIndex = self.UniqueColorIndex + 1
	if self.UniqueColorIndex > #self.UniqueColors then
		self.UniqueColorIndex = 1
	end
	return self.UniqueColors[self.UniqueColorIndex]
end

function Plugin:DrawBezier(thickness, a, d, color, parent)
	local function createLine()
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.Size = UDim2.new(0, 0, 0, 0)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = color
		line.ZIndex = 2
		return line
	end
	
	local function drawStraight(here, there, thickness)
		local delta = there - here
		local mid = (here + there) / 2
		
		local line = createLine()
		line.Position = UDim2.new(0, mid.X, 0, mid.Y)
		line.Size = UDim2.new(0, math.ceil(delta.magnitude + thickness / 2), 0, thickness)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		line.Parent = parent
	end
	
	local function drawCurve()
		parent:ClearAllChildren()
		
		local offset = Vector2.new(16, 0)
		local delta = (d - a)
		if delta.X < 0 then
			offset = offset + Vector2.new(-delta.X, 0)
			
			local dy = math.abs(delta.Y)
			local dyThreshold = 128
			if dy < dyThreshold then
				offset = offset + Vector2.new(0, dyThreshold - dy) * 2
			end
		end
		
		local b = a + offset
		local c = d - offset
		
		local points = {}
		
		local segments = 32
		for segment = 0, segments do
			local weight = segment / segments
			local ab = self:Lerp(a, b, weight)
			local bc = self:Lerp(b, c, weight)
			local cd = self:Lerp(c, d, weight)
			local abbc = self:Lerp(ab, bc, weight)
			local bccd = self:Lerp(bc, cd, weight)
			local point = self:Lerp(abbc, bccd, weight)
			table.insert(points, point)
		end
		
		local count = #points
		for index = 2, count do
			if index == count then
				local function getAverage(number)
					local point = Vector2.new(0, 0)
					for index = 1, number do
						point = point + points[count - index]
					end
					return point / number
				end
				
				local tip = points[index]
				local delta = tip - getAverage(6)
				local rotation = math.atan2(delta.Y, delta.X) + (math.pi)
				local size = 16
				local point = tip + (Vector2.new(math.cos(rotation), math.sin(rotation)) * (size / 2))
				
				local head = self.Guis.Plugin.ArrowHead:Clone()
				head.Size = UDim2.new(0, size, 0, size)
				head.Position = UDim2.new(0, point.X, 0, point.Y)
				head.ImageColor3 = color
				head.Rotation = math.deg(rotation) - 90
				head.Parent = parent
				
				drawStraight(points[index - 1], point, thickness)
			else
				drawStraight(points[index], points[index - 1], thickness)
			end
		end
	end
	
	drawCurve()
end

function Plugin:ConnectNodeGuis(parent, child, nodes)
	local parentGui = parent.PluginGui
	local childGui = child.PluginGui
	
	local connection = Instance.new("Folder")
	connection.Name = "Connection"
	connection.Parent = self.ScreenGui
	
	local function debugText(t, p)
		local label = Instance.new("TextLabel")
		label.TextScaled = true
		label.Position = UDim2.new(0, p.X, 0, p.Y)
		label.Text = t
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.new(0, 8, 0, 8)
		label.Parent = connection
	end
	
	local function onChanged()
		if self.Panning then return end
		self:DrawBezier(
			3,
			parentGui.AbsolutePosition + Vector2.new(parentGui.AbsoluteSize.X, parentGui.AbsoluteSize.Y / 2),
			childGui.AbsolutePosition + Vector2.new(0, childGui.AbsoluteSize.Y / 2),
			child.PluginColor,
			connection
		)
	end
	
	local parentConnection = parentGui.Changed:connect(onChanged)
	local childConnection = childGui.Changed:connect(onChanged)
	onChanged()
	
	table.insert(self.NodeConnections, {
		Parent = parent,
		ParentGui = parentGui,
		ParentConnection = parentConnection,
		
		Child = child,
		ChildGui = childGui,
		ChildConnection = childConnection,
		
		GuiFolder = connection,
	})
end

function Plugin:MakeBackground(nodes)
	--insert the background
	local background = self.Guis.Plugin.Background:Clone()
	background.Parent = self.ScreenGui
	
	local buttons = background.ButtonsFrame
	
	local function moveGui(gui, delta)
		gui.Position = gui.Position + UDim2.new(0, delta.X, 0, delta.Y)
	end
	wait()
	local function moveGuis(delta)	
		for _, node in pairs(nodes) do
			moveGui(node.PluginGui, delta)
		end
		
		for _, child in pairs(self.ScreenGui:GetChildren()) do
			if child.Name == "Connection" then
				for __, frame in pairs(child:GetChildren()) do
					moveGui(frame, delta)
				end
			end
		end
	end
	local function onRecenter()
		self.Panning = true
		
		local center = nodes[1].PluginGui.AbsolutePosition
		moveGuis(-center + Vector2.new(256, 64))
		
		self.Panning = false
	end
	buttons.RecenterButton.MouseButton1Click:Connect(onRecenter)
	--move the nodes when we drag on the background
	local function onPanBegin()
		self.Panning = true
		
		local uis = game:GetService("UserInputService")
		local mousePos = uis:GetMouseLocation()
		
		--when we move the mouse, we move the whole gui
		local changedConnection
		local function onInputChanged(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local newMousePos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = newMousePos - mousePos
				moveGuis(delta)
				mousePos = newMousePos
			end
		end
		changedConnection = uis.InputChanged:connect(onInputChanged)
		
		--when we release, disconnect those events
		local endedConnection
		local function onInputEnded(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
			
			changedConnection:disconnect()
			endedConnection:disconnect()
			self.Panning = false
		end
		endedConnection = uis.InputEnded:Connect(onInputEnded)
	end
	--if we left click and drag, we can select things
	local function onSelectBegin()
		--print("onSelectBegin 972")
		self:ClearSelections()
		
		local selectionBox = self.Guis.Plugin.SelectionFrame:Clone()
		selectionBox.Parent = self.ScreenGui
		
		local uis = game:GetService("UserInputService")
		local cornerA = uis:GetMouseLocation()
		local cornerB = cornerA
		
		local topLeft, botRight
		
		local function updateSelectionBox()
			topLeft = Vector2.new(
				math.min(cornerA.X, cornerB.X),
				math.min(cornerA.Y, cornerB.Y)
			)
			
			botRight = Vector2.new(
				math.max(cornerA.X, cornerB.X),
				math.max(cornerA.Y, cornerB.Y)
			)
			
			local size = botRight - topLeft
			
			selectionBox.Position = UDim2.new(0, topLeft.X, 0, topLeft.Y)
			selectionBox.Size = UDim2.new(0, size.X, 0, size.Y)
		end
		updateSelectionBox()
		
		local changedConnection
		local function onInputChanged(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			
			cornerB = uis:GetMouseLocation()
			updateSelectionBox()
		end
		changedConnection = uis.InputChanged:connect(onInputChanged)
		
		local endedConnection
		local function onInputEnded(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			
			endedConnection:disconnect()
			changedConnection:disconnect()
			
			--select these
			for _, node in pairs(self.Nodes) do
				local nodeGui = node.PluginGui
				local center = nodeGui.AbsolutePosition + (nodeGui.AbsoluteSize / 2)
				local inX = (center.X > topLeft.X) and (center.X < botRight.X)
				local inY = (center.Y > topLeft.Y) and (center.Y < botRight.Y)
				if inX and inY then
					self:Select(nodeGui)
				end
			end
			
			selectionBox:Destroy()
		end
		endedConnection = uis.InputEnded:connect(onInputEnded)
	end
	local function onInputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			onPanBegin()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			onSelectBegin()
		end
	end
	--when we click on the background, move stuff
	background.InputBegan:connect(onInputBegan)
	self.Background = background
end

function Plugin:AddDialogue()
	--don't do this while editing
	if self.EditingDialogue then return end
	
	--install too
	self:Install()
	
	--now find an object
	local object = game.Selection:Get()[1]
	if not object then
		warn("Can't create a dialogue. No object selected.")
		return
	end
	
	if object:FindFirstChild("RobloxDialogue") then
		if self:Prompt("Object already has a dialogue.\nWould you like to edit it now?") then
			self:EditDialogue()
		end
		return
	end
	
	local graph = self:GetClass"Graph":New()
	
	local prompt = self:GetClass"Prompt":New()
	prompt:SetLine("Hello, world!")
	graph:AddInitialPrompt(prompt)
	
	local response = self:GetClass"Response":New()
	response:SetLine("And hello to you, too!")
	prompt:AddResponse(response)
	
	local dataFolder = graph:Save()
	dataFolder.Parent = object
	game.Selection:Set{dataFolder}
	
	if self:Prompt("Created new dialogue!\nWould you like to edit it now?") then
		self:EditDialogue()
	end
end

function Plugin:EditDialogue()
	if self.EditingDialogue then return end
	
	--we install if we edit too
	self:Install()
	--ensure what we're selecting is a dialogue
	local object = game.Selection:Get()[1]
	if not object then
		warn("Please select an object with a RobloxDialogue.")
		return
	end
	if not self:IsDialogue(object) then
		object = object:FindFirstChild("RobloxDialogue", true)
		if not self:IsDialogue(object) then
			warn("Please select an object with a RobloxDialogue.")
			return
		end
	end
	local dialogue = object
	
	--flag that we're editing
	self.EditingDialogue = true
	--now stuff
	local graph = self:GetClass"Graph":New()
	graph:Load(dialogue)
	self.Graph = graph
	
	--pass #1: draw all guis
	local nodes = graph:GetNodes()
	for index, node in pairs(nodes) do
		wait()
		self:MakeNodeGui(node, index)
	end
	--draw the background
	self:MakeBackground(nodes)
	--pass #2: connect the nodes
	self.NodeConnections = {}
	for _, node in pairs(nodes) do
		wait()
		local function append(a, b)
			for _, v in pairs(a) do
				table.insert(b, v)
			end
		end
		local children = {}
		if node.Type == "Prompt" then
			append(node.Prompts, children)
			append(node.Responses, children)
		else
			append(node.Prompts, children)
		end
		
		for __, child in pairs(children) do
			self:ConnectNodeGuis(node, child, nodes)
		end
	end
	self.Dialogue = dialogue
	self.Nodes = nodes
	self.EventConnections = {}
	
	--when we hold down the shift key, display the connection boxes on all the nodes
	local uis = game:GetService("UserInputService")
	
	local function onInputBegan(input)
		if uis:GetFocusedTextBox() then return end
		if input.KeyCode ~= Enum.KeyCode.LeftShift then return end
		for _, node in pairs(nodes) do
			local gui = node.PluginGui
			gui.AddConnectionButton.Visible = false
			gui.BreakConnectionsChildrenButton.Visible = true
			gui.BreakConnectionsParentButton.Visible = true
			gui.DeleteActionButton.Visible = (node.ActionScript ~= nil)
			gui.DeleteConditionButton.Visible = (node.ConditionScript ~= nil)
		end
	end
	table.insert(self.EventConnections, uis.InputBegan:connect(onInputBegan))
	
	local function onInputEnded(input)
		if input.KeyCode ~= Enum.KeyCode.LeftShift then return end
		for _, node in pairs(nodes) do
			local gui = node.PluginGui
			gui.AddConnectionButton.Visible = true
			gui.BreakConnectionsChildrenButton.Visible = false
			gui.BreakConnectionsParentButton.Visible = false
			gui.DeleteActionButton.Visible = false
			gui.DeleteConditionButton.Visible = false
		end
	end
	table.insert(self.EventConnections, uis.InputEnded:connect(onInputEnded))
	
	--when we click exit, save and exit, duh
	local function onSaveExit()
		self:SaveAndExit()
	end
	self.Background.ButtonsFrame.SaveExitButton.MouseButton1Click:connect(onSaveExit)
	
	--when we click add prompt we add a prompt
	local function onAddPrompt()
		local prompt = self:GetClass"Prompt":New()
		self:MakeNodeGui(prompt, -1)
		table.insert(self.Nodes, prompt)
	end
	self.Background.ButtonsFrame.AddPromptButton.MouseButton1Click:connect(onAddPrompt)
	
	--when we click add response we add a response
	local function onAddResponse()
		local response = self:GetClass"Response":New()
		self:MakeNodeGui(response, -1)
		table.insert(self.Nodes, response)
	end
	self.Background.ButtonsFrame.AddResponseButton.MouseButton1Click:connect(onAddResponse)
	
	--when we click dynamic text functions we edit the dynamic text functions
	local function onEditDynamicTextFunctions()
		self.Plugin:OpenScript(game.ReplicatedStorage.RobloxDialogue.DynamicTextFunctions)
	end
	self.Background.ButtonsFrame.EditDynamicTextFunctionsButton.MouseButton1Click:connect(onEditDynamicTextFunctions)
	
	--when we click edit conversation data, we should edit the conversation data
	local function onConversationDataClick()
		if self.Graph.DataScript then
			self.Plugin:OpenScript(self.Graph.DataScript)
		else
			local ms = self.DataFolder.Scripts.InitialDataScript:Clone()
			ms.Name = "DataScript"
			ms.Parent = self.DataFolder
			
			self.Graph.DataScript = ms
			
			self.Plugin:OpenScript(ms)
		end
	end
	self.Background.ButtonsFrame.ConversationDataButton.MouseButton1Click:connect(onConversationDataClick)
	
	--changing the text in our conversation distance should change the conversation distance
	local conversationDistanceBox = self.Background.SettingsFrame.ConversationDistanceFrame.ValueBox
	local function updateConversationDistance(val)
		val = tonumber(val) or 16
		val = math.floor(val)
		
		conversationDistanceBox.Text = val
		graph:SetConversationDistance(val)
	end
	local function onConversationDistanceFocusLost()
		updateConversationDistance(conversationDistanceBox.Text)
	end
	conversationDistanceBox.FocusLost:connect(onConversationDistanceFocusLost)
	updateConversationDistance(graph:GetConversationDistance())
	
	--changing the text in our trigger distance should change the trigger distance
	local triggerDistanceBox = self.Background.SettingsFrame.TriggerDistanceFrame.ValueBox
	local function updateTriggerDistance(val)
		val = tonumber(val) or 0
		val = math.floor(val)
		
		triggerDistanceBox.Text = val
		graph:SetTriggerDistance(val)
	end
	local function onTriggerDistanceFocusLost()
		updateTriggerDistance(triggerDistanceBox.Text)
	end
	triggerDistanceBox.FocusLost:connect(onTriggerDistanceFocusLost)
	updateTriggerDistance(graph:GetTriggerDistance())
	
	--unselect the dialogue so that we don't accidentally delete it
	game.Selection:Set{}
end

function Plugin:Install()
	--first the replicated storage stuff
	local folder = game.ReplicatedStorage:FindFirstChild("RobloxDialogue")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RobloxDialogue"
		folder.Parent = game.ReplicatedStorage
	end

	--class and subscripts are purely controlled by the plugin, user changes are overwritten
	local class = folder:FindFirstChild("Class")
	if class then class:Destroy() end
	self.DataFolder.Class:Clone().Parent = folder
	
	--remotes are controlled by plugin, user changes are overwritten
	local remotes = folder:FindFirstChild("Remotes")
	if remotes then remotes:Destroy() end
	self.DataFolder.Remotes:Clone().Parent = folder
	
	--gui changes must be preserved, only install them if they aren't there
	local guis = folder:FindFirstChild("Guis")
	if not guis then
		guis = self.DataFolder.Guis:Clone()
		guis.Parent = folder
		guis.Plugin:Destroy()
	end
	
	--server settings must be preserved
	local serverSettings = folder:FindFirstChild("ServerSettings")
	if not serverSettings then
		serverSettings = self.DataFolder.ServerSettings:Clone()
		serverSettings.Parent = folder
	end
	
	--dynamic text functions must be preserved, only install them if they aren't there
	local dynamicTextFunctions = folder:FindFirstChild("DynamicTextFunctions")
	if not dynamicTextFunctions then
		dynamicTextFunctions = self.DataFolder.DynamicTextFunctions:Clone()
		dynamicTextFunctions.Parent = folder
	end
	
	--interfaces must be preserved, install the default ones
	local interfaces = folder:FindFirstChild("Interfaces")
	if not interfaces then
		interfaces = self.DataFolder.Interfaces:Clone()
		interfaces.Parent = folder
	end
	
	local clientInterface = folder:FindFirstChild("ClientInterface")
	if not clientInterface then
		clientInterface = Instance.new("ObjectValue")
		clientInterface.Name = "ClientInterface"
		clientInterface.Value = interfaces.Default
		clientInterface.Parent = folder
	end
	
	local function tryDestroyAt(name, location)
		local object = location:FindFirstChild(name)
		if object then object:Destroy() end
	end
	
	--overwrite the initializers
	tryDestroyAt("RobloxDialogueServerScript", game.ServerScriptService)
	local server = self.DataFolder.RobloxDialogueServerScript:Clone()
	server.Disabled = false
	server.Parent = game.ServerScriptService
	
	tryDestroyAt("RobloxDialogueClientScript", game.StarterPlayer.StarterPlayerScripts)
	local client = self.DataFolder.RobloxDialogueClientScript:Clone()
	client.Disabled = false
	client.Parent = game.StarterPlayer.StarterPlayerScripts
end

function Plugin:SaveAndExit()
	self.EditingDialogue = false
	
	for _, node in pairs(self.Nodes) do
		node.PluginGuiPosition = node.PluginGui.AbsolutePosition
	end
	
	local parent = self.Dialogue.Parent
	self.Dialogue:Destroy()
	
	self.Graph:Save().Parent = parent
	
	self.ScreenGui:ClearAllChildren()
	
	for _, connection in pairs(self.EventConnections) do
		connection:disconnect()
	end
end

return Plugin