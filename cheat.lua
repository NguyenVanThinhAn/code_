local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Backpack = LocalPlayer:WaitForChild("Backpack")

-- Folders
local cratesFolder = workspace:WaitForChild("Barrels"):WaitForChild("Crates")
local barrelsFolder = workspace:WaitForChild("Barrels"):WaitForChild("Barrels")

-- Variables
local range = 10
local autoEnabled = false
local toolProcessing = false
local originalWalkSpeed = Humanoid.WalkSpeed

-- Distance calculation
local function getDistance(part)
	return (HumanoidRootPart.Position - part.Position).Magnitude
end

-- Click function
local function clickBarrel(barrel)
	local clickDetector = barrel:FindFirstChildOfClass("ClickDetector")
	if clickDetector then
		fireclickdetector(clickDetector)
	else
		warn("Không tìm thấy ClickDetector trong", barrel.Name)
	end
end

-- Move to target function
local function moveToTarget(targetPosition)
	if not autoEnabled then return false end

	Humanoid:MoveTo(targetPosition)

	-- Wait until reached or timeout
	local startTime = tick()
	local connection
	local reached = false

	connection = RunService.Heartbeat:Connect(function()
		if not autoEnabled then
			connection:Disconnect()
			return
		end

		local distance = (HumanoidRootPart.Position - targetPosition).Magnitude
		if distance < 5 or tick() - startTime > 10 then -- Reached or timeout after 10 seconds
			reached = true
			connection:Disconnect()
		end
	end)

	-- Wait for movement to complete
	repeat
		task.wait(0.1)
	until reached or not autoEnabled

	return autoEnabled and reached
end

-- Get all targets (crates and barrels)
local function getAllTargets()
	local targets = {}

	-- Get crates
	for _, crate in ipairs(cratesFolder:GetChildren()) do
		if crate:IsA("BasePart") or crate:FindFirstChildWhichIsA("BasePart") then
			local part = crate:IsA("BasePart") and crate or crate:FindFirstChildWhichIsA("BasePart")
			local distance = getDistance(part)
			table.insert(targets, {part = crate, pos = part.Position, dist = distance})
		end
	end

	-- Get barrels
	for _, barrel in ipairs(barrelsFolder:GetChildren()) do
		if barrel:IsA("BasePart") or barrel:FindFirstChildWhichIsA("BasePart") then
			local part = barrel:IsA("BasePart") and barrel or barrel:FindFirstChildWhichIsA("BasePart")
			local distance = getDistance(part)
			table.insert(targets, {part = barrel, pos = part.Position, dist = distance})
		end
	end

	-- Sort by distance
	table.sort(targets, function(a, b)
		return a.dist < b.dist
	end)

	return targets
end

-- Process targets with auto movement
local function processTargetsWithMovement()
	while autoEnabled do
		local targets = getAllTargets()

		if #targets == 0 then
			task.wait(1)
			continue
		end

		for _, targetData in ipairs(targets) do
			if not autoEnabled then break end

			-- Move to target
			local success = moveToTarget(targetData.pos)
			if not success then break end

			-- Wait a bit after reaching
			task.wait(0.2)

			-- Click the target
			clickBarrel(targetData.part)

			-- Random delay
			task.wait(math.random(10, 30) / 100)
		end

		-- Wait before next scan
		task.wait(0.5)
	end
end

-- Smart wait function
local function smartWait()
	if math.random(1, 10) == 1 then
		task.wait(1)
	else
		task.wait(math.random(10, 30) / 100) 
	end
end

-- Process tools function
local function processTools()
	local tools = Backpack:GetChildren()
	if #tools == 0 then
		warn("Không có Tool nào trong Backpack!")
		return
	end

	for _, tool in ipairs(tools) do
		if not toolProcessing then break end
		if tool:IsA("Tool") then
			tool.Parent = Character
			task.wait(0.05)
			if tool.Activate then
				tool:Activate()
			end
			tool.Parent = Backpack
			smartWait()
		end
	end
end

-- Handle character respawn
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
	Humanoid = Character:WaitForChild("Humanoid")
	originalWalkSpeed = Humanoid.WalkSpeed
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- P key for auto collect with movement
	if input.KeyCode == Enum.KeyCode.P then
		autoEnabled = not autoEnabled

		if autoEnabled then
			print("Auto Collect ENABLED - Speed boosted to 50")
			Humanoid.WalkSpeed = 50
			spawn(processTargetsWithMovement)
		else
			print("Auto Collect DISABLED - Speed restored")
			Humanoid.WalkSpeed = originalWalkSpeed
		end
	end

	-- L key for tool processing
	if input.KeyCode == Enum.KeyCode.L then
		if not toolProcessing then
			toolProcessing = true
			print("Tool Processing ENABLED")
			spawn(function()
				processTools()
				toolProcessing = false
				print("Tool Processing COMPLETED")
			end)
		else
			toolProcessing = false
			print("Tool Processing DISABLED")
		end
	end
end)

print("Script loaded!")
print("P - Toggle Auto Collect (with auto movement)")
print("L - Process Tools in Backpack")