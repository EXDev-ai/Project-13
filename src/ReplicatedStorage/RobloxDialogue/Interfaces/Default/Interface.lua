local Interface = {}

local Guis = script.Parent.Guis

local InteractBillboardsByDialogue = {}

local CurrentInteractBillboard = nil

local Gui = nil
local Connections = {}
local BaseGui = script.Parent.Guis.ScreenGui

local Player = game.Players.LocalPlayer

local Settings = require(script.Parent.Settings)

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local SoftEndTimer

local DebugTestTenFoot = false
local IsTenFoot = false

local InputMode = "Desktop"
local InputModeByInputType = {
	[Enum.UserInputType.Keyboard] = "Desktop",
	[Enum.UserInputType.MouseButton1] = "Desktop",
	[Enum.UserInputType.MouseButton2] = "Desktop",
	[Enum.UserInputType.MouseMovement] = "Desktop",
	
	[Enum.UserInputType.Touch] = "Mobile",
}

do --gamepad input types
	UIS.GamepadConnected:connect(function(userInputType)
		InputModeByInputType[userInputType] = "Console"
	end)
	for _, userInputType in pairs(UIS:GetConnectedGamepads()) do
		InputModeByInputType[userInputType] = "Console"
	end
end

function onLastInputTypeChanged(input)
	local inputType = input.UserInputType
	local newMode = InputModeByInputType[inputType]
	if newMode and InputMode ~= newMode then
		onInputModeChanged(InputMode, newMode)
		InputMode = newMode
	end
end
UIS.InputBegan:connect(onLastInputTypeChanged)
UIS.InputChanged:connect(onLastInputTypeChanged)
UIS.InputEnded:connect(onLastInputTypeChanged)

function onInputModeChanged(oldMode, newMode)
	if newMode == "Console" then
		if not Gui then return end
		
		--if there's a next button, select it and get out
		local nextButton = Gui.MainFrame.PromptImage.NextButton
		if nextButton.Visible then
			GuiService.SelectedObject = nextButton
			return
		end
		
		--no next button, select a response (maybe)
		local responsesFrame = Gui.MainFrame.ResponsesImage.ResponsesFrame
		local response
		local bestLayoutOrder = math.huge
		for _, child in pairs(responsesFrame:GetChildren()) do
			if child.Name == "ResponseButton" then
				if child.LayoutOrder < bestLayoutOrder then
					response = child
					bestLayoutOrder = child.LayoutOrder
				end
			end
		end
		
		GuiService.SelectedObject = response
	end
	
	if oldMode == "Console" then
		GuiService.SelectedObject = nil
	end
end

function setGuiTenFoot()
	if not Gui then return end
	
	local factor = 1.8
	
	local scale = Gui.UIScale
	scale.Scale = factor
	
	Gui.UIPadding.PaddingBottom = UDim.new(0.15, 0)
	Gui.MainFrame.Size = UDim2.new(1, 0, 0.55, 0)
	
	Gui.MainFrame.CloseButtonImage.Visible = true
	Gui.MainFrame.CloseButtonText.Visible = true
	
	Gui.MainFrame.TitleImage.CloseButton.Visible = false
	
	Gui.MainFrame.UISizeConstraint.MaxSize = Vector2.new(920, math.huge)
	
	IsTenFoot = true
end

function setGuiDesktopTablet()
	if not Gui then return end
	
	local factor = 1.3
	
	local scale = Gui.UIScale
	scale.Scale = factor
	
	Gui.MainFrame.UISizeConstraint.MaxSize = Vector2.new(628, math.huge)
	Gui.MainFrame.Position = UDim2.new(0.5, 0, 0.85, 0)
end

function createTimer(duration, callback)
	local timer = {}
	
	timer.Time = duration
	timer.MaxTime = duration
	
	function timer:Stop()
		self.HeartbeatConnection:disconnect()
	end
	
	function timer:Update(dt)
		self.Time = self.Time - dt
		if self.Time <= 0 then
			callback()
			self:Stop()
		end
	end
	
	function timer:Start()
		local function onHeartbeat(...) self:Update(...) end
		self.HeartbeatConnection = game:GetService("RunService").Heartbeat:connect(onHeartbeat)
	end
	
	return timer
end

function guiResets()
	return game:GetService("StarterGui").ResetPlayerGuiOnSpawn
end

function onCharacterDied()
	if not guiResets() then return end
	
	for dialogue, billboard in pairs(InteractBillboardsByDialogue) do
		billboard.Parent = nil
	end
end

function onCharacterAdded(character)
	if not guiResets() then return end
	
	for dialogue, billboard in pairs(InteractBillboardsByDialogue) do
		billboard.Parent = Player.PlayerGui
	end
	
	Player.CharacterRemoving:connect(onCharacterDied)
end
Player.CharacterAdded:connect(onCharacterAdded)

function inConversation()
	return CurrentInteractBillboard ~= nil
end

function getBillboardAdornee(dialogue)
	if not dialogue then return end
	
	local adornee = dialogue.Parent
	if adornee:IsA("Model") then
		local model = adornee
		adornee = adornee:FindFirstChild("Head")
		if not adornee then
			adornee = model.PrimaryPart
			if not adornee then
				adornee = model:FindFirstChildOfClass("BasePart")
			end
		end
	end
	
	return adornee
end

function clearResponses()
	if not Gui then return end
	
	local responsesFrame = Gui.MainFrame.ResponsesImage.ResponsesFrame
	for _, child in pairs(responsesFrame:GetChildren()) do
		if child.Name == "ResponseButton" then
			local ts = game:GetService("TweenService")
			local info = TweenInfo.new(Settings.ResponsesFadeTime, Enum.EasingStyle.Linear)
			
			ts:Create(child, info, {ImageTransparency = 1}):Play()
			ts:Create(child.Text, info, {TextTransparency = 1}):Play()
			
			delay(Settings.ResponsesFadeTime, function()
				child:Destroy()
			end)
			
			resizeResponses(false)
		end
	end
end

function getTrueSize(element)
	local size
	local parent = element.Parent
	if parent:IsA("ScreenGui") then
		size = Gui.AbsoluteSize
	else
		size = getTrueSize(parent)
	end
	
	return Vector2.new(
		size.X * element.Size.X.Scale + element.Size.X.Offset,
		size.Y * element.Size.Y.Scale + element.Size.Y.Offset
	)
end

function setResponsesGridCellSize()
	if not Gui then return end
	
	local responsesFrame = Gui.MainFrame.ResponsesImage.ResponsesFrame
	local grid = responsesFrame.UIGridLayout
	local padding = responsesFrame.UIPadding
	
	local cellHeight = 0.4
	if isPortrait() then
		cellHeight = 0.5
	elseif IsTenFoot then
		cellHeight = 0.3
	end
	cellHeight = Gui.MainFrame.AbsoluteSize.Y * BaseGui.MainFrame.ResponsesImage.Size.Y.Scale * cellHeight
	
	if isPortrait() then
		grid.CellSize = UDim2.new(.99, 0, 0, cellHeight)
		grid.CellPadding = UDim2.new(0.01, 0, 0.01, 0)
		padding.PaddingRight = UDim.new(0.03, 0)
		padding.PaddingLeft = UDim.new(0.03, 0)
	elseif isLandscape() then
		grid.CellSize = UDim2.new(.49, 0, 0, cellHeight)
		grid.CellPadding = UDim2.new(0.01, 0, 0.03, 0)
		padding.PaddingRight = UDim.new(0.005, 0)
		padding.PaddingLeft = UDim.new(0.015, 0)
	end
end

function getScaleFactor()
	if not Gui then return 1 end
	
	local scale = Gui.UIScale
	return scale.Scale
end

function resizeScrollingFrame(scrollingFrame)
	local scaleFactor = getScaleFactor()
	
	scrollingFrame.CanvasPosition = Vector2.new(0, 0)
	local max = Vector2.new(0, 0)
	
	for _, child in pairs(scrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			local bottomLeft = child.AbsolutePosition + child.AbsoluteSize
			local relative = Vector2.new(
				bottomLeft.X - scrollingFrame.AbsolutePosition.X,
				bottomLeft.Y - scrollingFrame.AbsolutePosition.Y
			)
			
			max = Vector2.new(
				0,
				math.max(max.Y, relative.Y)
			)
		end
	end
	
	max = max / scaleFactor
	scrollingFrame.CanvasSize = UDim2.new(0, max.X, 0, max.Y)
end

function ensureGui()
	if not Gui then
		wait()
		
		Gui = BaseGui:Clone()
		Gui.Name = "RobloxDialogueScreenGui"
		Gui.Parent = Player.PlayerGui
		
		--landscape mobile needs more space
		if Gui.AbsoluteSize.Y < 512 then
			Gui.MainFrame.UISizeConstraint.MinSize = Vector2.new(0, (Gui.AbsoluteSize.Y + 36) * 0.75)
		end
		
		--portrait requires different ratios
		if isPortrait() then
			Gui.MainFrame.UIAspectRatioConstraint:Destroy()
			
			local prompt = Gui.MainFrame.PromptImage
			prompt.NextButton.Size = UDim2.new(0.1, 0, 0.275, 0)
			prompt.PortraitImage.Size = UDim2.new(0.34, 0, 0.8, 0)
			
			prompt.PromptText.Size = UDim2.new(0.56, 0, 1, 0)
			prompt.PromptText.Position = UDim2.new(0.34, 0, 0, 0)
		end
		
		--ten foot?
		if GuiService:IsTenFootInterface() or DebugTestTenFoot then
			setGuiTenFoot()
		
		--desktop or tablet?
		elseif Gui.AbsoluteSize.X > 900 then
			setGuiDesktopTablet()
		end
		
		--make the scrolling frame responsive
		local responsesFrame = Gui.MainFrame.ResponsesImage.ResponsesFrame
		responsesFrame:GetPropertyChangedSignal("AbsoluteSize"):connect(function()
			resizeScrollingFrame(responsesFrame)
		end)
		responsesFrame.ChildAdded:connect(function(child)
			local function getRelativePosition()
				return child.AbsolutePosition - (responsesFrame.AbsolutePosition - responsesFrame.CanvasPosition)
			end
			local relativePosition = getRelativePosition()
			
			local epsilon = 4
			local sqEpsilon = epsilon ^ 2
			local function different(a, b)
				local delta = a - b
				local sqDist = delta.X ^ 2 + delta.Y ^ 2
				return sqDist > sqEpsilon
			end
			
			if child:IsA("GuiObject") then
				child:GetPropertyChangedSignal("AbsolutePosition"):connect(function()
					local newRelativePosition = getRelativePosition()
					if different(newRelativePosition, relativePosition) then
						relativePosition = newRelativePosition
						resizeScrollingFrame(responsesFrame)
					end
				end)
			end
			resizeScrollingFrame(responsesFrame)
		end)
		
		--make pressing the x button end the dialogue
		local function userEnded()
			Interface.ClientFunctions.UserEnded()
			endDialogue()
		end
		local closeButton = Gui.MainFrame.TitleImage.CloseButton
		closeButton.MouseButton1Click:connect(userEnded)
		
		--make clicking out end the dialogue
		if Settings.CanClickOut then
			local function inGui(position)
				local topLeft = Gui.MainFrame.AbsolutePosition
				local botRight = topLeft + Gui.MainFrame.AbsoluteSize
				
				local inX = (position.X > topLeft.X) and (position.X < botRight.X)
				local inY = (position.Y > topLeft.Y) and (position.Y < botRight.Y)
				
				return (inX and inY)
			end
			
			local function onInputBegan(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if not inGui(input.Position) then
						userEnded()
					end
				
				elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
					if input.KeyCode == Settings.GamepadClickOutButton then
						userEnded()
					end
				end
			end
			table.insert(Connections, UIS.InputBegan:connect(onInputBegan))
			
			--detect taps
			local touch = {
				Active = false,
				StartTime = 0,
				Position = Vector2.new(0, 0),
			}
			local tapTime = 0.1
			
			local function onTapped()
				if not inGui(touch.Position) then
					userEnded()
				end
			end
			
			local function onTouchStarted(input)
				if touch.Active then return end
				
				touch.Active = true
				touch.StartTime = tick()
				touch.Position = input.Position
			end
			table.insert(Connections, UIS.TouchStarted:connect(onTouchStarted))
			
			local function onTouchEnded(input)
				if not touch.Active then return end
				
				touch.Active = false
				
				local since = tick() - touch.StartTime
				if since <= tapTime then
					onTapped()
				end
			end
			table.insert(Connections, UIS.TouchEnded:connect(onTouchEnded))
		end
		
		--tween in
		local frame = Gui.MainFrame
		local destination = frame.Position
		frame.Position = frame.Position + UDim2.new(0, 0, 0, frame.AbsoluteSize.Y + 32)
		
		game:GetService("TweenService"):Create(
			frame,
			TweenInfo.new(Settings.GuiTweenTime, Enum.EasingStyle.Quint),
			{Position = destination}
		):Play()
	end
end

function startDialogue(dialogue, callback)
	if inConversation() then return end
	
	local billboard = InteractBillboardsByDialogue[dialogue]
	CurrentInteractBillboard = billboard
	billboard.Enabled = false
	
	callback()
end

function endDialogue()
	if not inConversation() then return end
	
	if SoftEndTimer then
		SoftEndTimer:Stop()
		SoftEndTimer = nil
	end
	
	local billboard = CurrentInteractBillboard
	CurrentInteractBillboard = nil
	billboard.Enabled = true
	
	if Gui then
		--tween out
		local frame = Gui.MainFrame
		local destination = frame.Position + UDim2.new(0, 0, 0, frame.AbsoluteSize.Y * 2)
		
		game:GetService("TweenService"):Create(
			frame,
			TweenInfo.new(Settings.GuiTweenTime, Enum.EasingStyle.Quint),
			{Position = destination}
		):Play()
		
		delay(Settings.GuiTweenTime, function()
			Gui:Destroy()
			Gui = nil
		end)
		
		--disconnect all connections
		for _, connection in pairs(Connections) do
			connection:disconnect()
		end
		Connections = {}
	end
	
	GuiService.SelectedObject = nil
end

function softEndDialogue()
	if not inConversation() then return end
	
	resizeResponses(false)
	
	SoftEndTimer = createTimer(Settings.SoftEndTime, function()
		endDialogue()
	end)
	SoftEndTimer:Start()
end

function getResponseButtons()
	local responseButtons = {}
	for _, child in pairs(Gui.MainFrame.ResponsesImage.ResponsesFrame:GetChildren()) do
		if child.Name == "ResponseButton" then
			table.insert(responseButtons, child)
		end
	end
	return responseButtons
end

function getSize(guiElement)
	return guiElement.AbsoluteSize / Gui.UIScale.Scale
end

function getPosition(guiElement)
	return guiElement.AbsolutePosition / Gui.UIScale.Scale
end

function getScreenOrientation()
	return Player.PlayerGui.CurrentScreenOrientation
end

function isLandscape()
	if game:GetService("RunService"):IsStudio() then
		return not isPortrait()
	end
	
	local orientation = getScreenOrientation()
	return (orientation == Enum.ScreenOrientation.LandscapeLeft) or (orientation == Enum.ScreenOrientation.LandscapeRight)
end

function isPortrait()
	if game:GetService("RunService"):IsStudio() then
		return Gui.AbsoluteSize.X < 512
	end
	
	return getScreenOrientation() == Enum.ScreenOrientation.Portrait
end

function resizeResponses(isLarge)
	local responsesImage = Gui.MainFrame.ResponsesImage
	local ts = game:GetService("TweenService")
	local info = TweenInfo.new(Settings.ResponsesFadeTime)
	local baseSize = BaseGui.MainFrame.ResponsesImage.Size
	
	if isLarge then
		wait()
		
		local paddingY =
			responsesImage.UIPadding.PaddingBottom.Offset +
			responsesImage.UIPadding.PaddingTop.Offset +
			responsesImage.ResponsesFrame.UIPadding.PaddingBottom.Offset +
			responsesImage.ResponsesFrame.UIPadding.PaddingTop.Offset
		
		local maxHeight = (Gui.MainFrame.AbsolutePosition.Y + Gui.MainFrame.AbsoluteSize.Y - responsesImage.AbsolutePosition.Y) / getScaleFactor()
		
		local height = responsesImage.ResponsesFrame.UIGridLayout.AbsoluteContentSize.Y
		height = height + paddingY
		height = height + 4
		height = height / getScaleFactor()
		height = math.min(height, maxHeight)
		
		local size = UDim2.new(
			baseSize.X.Scale,
			baseSize.X.Offset,
			0,
			height
		)
		
		size = UDim2.new(1, 0, 0.475, 0)
		
		ts:Create(responsesImage, info, {Size = size}):Play()
	else
		responsesImage.ResponsesFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		
		local size = UDim2.new(
			baseSize.X.Scale,
			baseSize.X.Offset,
			0,
			6
		)
		ts:Create(responsesImage, info, {Size = size}):Play()
	end
end

function displayPrompt(promptTable, chained)
	local promptImage = Gui.MainFrame.PromptImage
	local promptText = promptImage.PromptText
	
	promptText.Text = promptTable.Line
	
	--address the chain button
	local button = promptImage.NextButton
	local buttonDelta = UDim2.new(0, getSize(button).X, 0, 0)
	if chained then
		if not button.Visible then
			button.Visible = true
			promptText.Size = promptText.Size - buttonDelta
		end
	else
		if button.Visible then
			button.Visible = false
			promptText.Size = promptText.Size + buttonDelta
		end
	end
	
	--get the data
	local data = promptTable.Data
	
	--addresses the portrait
	local portrait = promptImage.PortraitImage
	local portraitDelta = UDim2.new(0, getSize(portrait).X, 0, 0)
	if (data.PortraitImage) and (data.PortraitImage ~= "") then
		portrait.Image = data.PortraitImage
		
		if not portrait.Visible then
			portrait.Visible = true
			promptText.Size = UDim2.new(0.56, 0, 1, 0)
			promptText.Position = UDim2.new(0.34, 0, 0, 0)
		end
	else
		if portrait.Visible then
			portrait.Visible = false
			promptText.Size = UDim2.new(0.56 + 0.34, 0, 1, 0)
			promptText.Position = UDim2.new(0, 0, 0, 0)
		end
	end
	
	--addresses the title
	local titleText = Gui.MainFrame.TitleImage.TitleText
	if data.Title then
		titleText.Text = data.Title
	else
		titleText.Text = ""
	end
end

------------------------------------------------------------------------------
--this is the final interface, the functions that the client will call on us--
------------------------------------------------------------------------------

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
	if InteractBillboardsByDialogue[dialogue] then return end
	
	local adornee = getBillboardAdornee(dialogue)
	if not adornee then return end
	
	local billboard = Guis.InteractBillboard:Clone()
	billboard.Parent = Player:WaitForChild("PlayerGui")
	billboard.Adornee = adornee
	
	billboard.MainFrame.InteractButton.MouseButton1Click:connect(function()
		startDialogue(dialogue, startDialogueCallback)
	end)
	
	InteractBillboardsByDialogue[dialogue] = billboard
end

--UnregisterDialogue
--* called when the client discovers that a dialogue has been
--* removed from the game. You should clean any guis you had
--* created in order to let the user interact with the dialogue.
function Interface.UnregisterDialogue(dialogue)
	local billboard = InteractBillboardsByDialogue[dialogue]
	if billboard then
		billboard:Destroy()
	end
end

--Triggered
--* called when the dialogue has a TriggerDistance and the player
--* walks in range of it. Here so you can manage your interaction
--* buttons, etc. Call the callback to start the dialogue.
function Interface.Triggered(dialogue, startDialogueCallback)
	startDialogue(dialogue, startDialogueCallback)
end

--RangeWarned
--* called when the server notifies that the client attempted
--* to start a dialogue that was too far away (ConversationDistance).
function Interface.RangeWarned()
	endDialogue()
end

--TimedOut
--* called when the player took too long to choose an option.
function Interface.TimedOut()
	endDialogue()
end

--WalkedAway
--* called when the player gets too far away from the dialogue
--* that they are currently speaking with.
function Interface.WalkedAway()
	endDialogue()
end

--Finished
--* called when the conversation finishes under normal circumstances
--* with prompt is whether or not the dialogue finished with a prompt
--* as opposed to a response. useful if you want to show the prompt
--* for some time but want to end immediately conversations that
--* end with a response
function Interface.Finished(withPrompt)
	if withPrompt then
		softEndDialogue()
	else
		endDialogue()
	end
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
	ReceivedPrompt = true
	
	--ensure we have the gui
	ensureGui()
	
	local frame = Gui.MainFrame
	
	--display the prompt
	displayPrompt(promptTable, false)
	
	--clear the responses
	clearResponses()
	setResponsesGridCellSize()
	
	wait(Settings.ChatTime)
	
	--add new responses
	local function onResponseChosen(responseTable)
		if InputMode == "Console" then
			GuiService.SelectedObject = nil
		end
		
		ReceivedPrompt = false
		clearResponses()
		responseTable.Callback()
	end
	
	local function onResponseButtonSelected(button)
		button.ImageColor3 = Color3.fromRGB(0, 162, 255)
	end
	
	local function onResponseButtonDeselected(button)
		button.ImageColor3 = Color3.new(1, 1, 1)
	end
	
	local responseButton = BaseGui.MainFrame.ResponsesImage.ResponsesFrame.ResponseButton:Clone()
	local responsesFrame = frame.ResponsesImage.ResponsesFrame
	for index, responseTable in pairs(responseTables) do
		local button = responseButton:Clone()
		button.LayoutOrder = index
		button.Text.Text = responseTable.Line
		button.MouseButton1Click:connect(function() onResponseChosen(responseTable) end)
		button.SelectionGained:connect(function() onResponseButtonSelected(button) end)
		button.SelectionLost:connect(function() onResponseButtonDeselected(button) end)
		button.Parent = responsesFrame
		
		--tween in
		button.ImageTransparency = 1
		button.Text.TextTransparency = 1
		
		local ts = game:GetService("TweenService")
		local info = TweenInfo.new(Settings.ResponsesFadeTime, Enum.EasingStyle.Linear)
		
		ts:Create(button, info, {ImageTransparency = 0}):Play()
		ts:Create(button.Text, info, {TextTransparency = 0}):Play()
		
		delay(Settings.ResponsesFadeTime, function()
			if (InputMode == "Console") and (GuiService.SelectedObject == nil) then
				GuiService.SelectedObject = button
			end
		end)
	end
	
	--size the responses frame to nothing if we have no responses
	resizeResponses(#responseTables > 0)
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
	--ensure we have the gui
	ensureGui()
	
	local frame = Gui.MainFrame
	
	--display the prompt
	displayPrompt(promptTable, true)
	
	--resize the responses frame
	resizeResponses(false)

	--wait on the next button to get pressed
	local onNextClickConnection
	local function onNextClick()
		if (GuiService.SelectedObject) then
			GuiService.SelectedObject = nil
		end
		
		onNextClickConnection:disconnect()
		callback()
	end
	onNextClickConnection = frame.PromptImage.NextButton.MouseButton1Click:connect(onNextClick)
	
	--gamepad?
	delay(Settings.ResponsesFadeTime, function()
		if (InputMode == "Console") and (GuiService.SelectedObject == nil) then
			GuiService.SelectedObject = frame.PromptImage.NextButton
		end
	end)
end

return Interface