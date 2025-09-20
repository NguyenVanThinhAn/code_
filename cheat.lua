local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Backpack = LocalPlayer:WaitForChild("Backpack")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Variables cho tool processing
local isRunning = false

-- Variables cho barrel processing
local cratesFolder = workspace:WaitForChild("Barrels"):WaitForChild("Crates")
local barrelsFolder = workspace:WaitForChild("Barrels"):WaitForChild("Barrels")
local range = 10
local isPressing = false

-- Hàm delay với thỉnh thoảng delay 1 giây
local function smartWait()
	if math.random(1, 10) == 1 then
		task.wait(1)
	else
		task.wait(math.random(10, 30) / 100) 
	end
end

-- Hàm xử lý tools
local function processTools()
	local tools = Backpack:GetChildren()
	if #tools == 0 then
		warn("Không có Tool nào trong Backpack!")
		return
	end
	for _, tool in ipairs(tools) do
		if not isRunning then break end
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

-- Hàm tính khoảng cách
local function getDistance(part)
	return (HumanoidRootPart.Position - part.Position).Magnitude
end

-- Hàm nhấn 1 barrel
local function clickBarrel(barrel)
	local clickDetector = barrel:FindFirstChildOfClass("ClickDetector")
	if clickDetector then
		fireclickdetector(clickDetector)
	else
		warn("Không tìm thấy ClickDetector trong", barrel.Name)
	end
end

-- Hàm xử lý barrels (chung cho cả Crates và Barrels)
local function processBarrels(folder)
	local barrelsInRange = {}
	for _, barrel in ipairs(folder:GetChildren()) do
		if barrel:IsA("BasePart") or barrel:FindFirstChildWhichIsA("BasePart") then
			local part = barrel:IsA("BasePart") and barrel or barrel:FindFirstChildWhichIsA("BasePart")
			local distance = getDistance(part)
			if distance <= range then
				table.insert(barrelsInRange, {part = barrel, dist = distance})
			end
		end
	end
	
	table.sort(barrelsInRange, function(a, b)
		return a.dist < b.dist
	end)
	
	for _, data in ipairs(barrelsInRange) do
		if not isPressing then break end
		clickBarrel(data.part)
		task.wait(math.random(10, 30) / 100)
	end
end

-- Event handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Phím L: Xử lý tools
	if input.KeyCode == Enum.KeyCode.L then
		if not isRunning then
			isRunning = true
			processTools()
			isRunning = false
		else
			isRunning = false
		end
	end
	
	-- Phím P: Xử lý barrels (cả Crates và Barrels)
	if input.KeyCode == Enum.KeyCode.P then
		if not isPressing then
			isPressing = true
			-- Xử lý cả hai loại barrels
			processBarrels(cratesFolder)
			if isPressing then -- Kiểm tra lại nếu vẫn đang nhấn
				processBarrels(barrelsFolder)
			end
			isPressing = false
		end
	end
end)
