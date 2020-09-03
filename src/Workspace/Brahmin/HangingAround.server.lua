print("Brahmin Randmoly Dancing in da house")

local human = script.Parent:WaitForChild("Humanoid")

local radius = script.Radius.Value

local period = script.Period.Value

local randomizationRatio = script.RandomizationRatio.Value

while true do
	
	local brahminDecisionsRandomizer = math.random(1,randomizationRatio)
	
	if (brahminDecisionsRandomizer % 2 == 0) then
	
		local humanPosition = script.Parent:WaitForChild("LowerTorso").Position
		
		local xMove = math.random(-radius,radius)
		
		local zMove = math.random(-radius,radius)
	
		local nextPosition = humanPosition + Vector3.new(0,xMove,zMove)
			human:MoveTo(nextPosition)wait(period)
	end
end
