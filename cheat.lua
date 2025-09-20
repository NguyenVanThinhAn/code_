--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--// Player & Character
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Backpack = LocalPlayer:WaitForChild("Backpack")

--// Settings
local range = 10 -- Khoảng cách để click barrel
local isRunning = false -- Trạng thái auto Tool
local isPressing = false -- Trạng thái auto Barrel

--// Folders chứa Barrels và Crates
local barrelsMainFolder = workspace:WaitForChild("Barrels")
local foldersToCheck = {
    barrelsMainFolder:WaitForChild("Barrels"),
    barrelsMainFolder:WaitForChild("Crates")
}

---------------------------------------------------------------------
--// Hàm smart delay: thỉnh thoảng delay 1 giây
local function smartWait()
    if math.random(1, 10) == 1 then
        task.wait(1)
    else
        task.wait(math.random(10, 30) / 100)
    end
end

---------------------------------------------------------------------
--// Auto dùng toàn bộ Tool trong Backpack
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

---------------------------------------------------------------------
--// Auto click Barrel / Crate
local function getDistance(part)
    return (HumanoidRootPart.Position - part.Position).Magnitude
end

local function clickBarrel(barrel)
    local clickDetector = barrel:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        fireclickdetector(clickDetector)
    else
        warn("Không tìm thấy ClickDetector trong", barrel.Name)
    end
end

local function processBarrels()
    local barrelsInRange = {}

    -- Duyệt qua cả "Barrels" và "Crates"
    for _, folder in ipairs(foldersToCheck) do
        for _, barrel in ipairs(folder:GetChildren()) do
            if barrel:IsA("BasePart") or barrel:FindFirstChildWhichIsA("BasePart") then
                local part = barrel:IsA("BasePart") and barrel or barrel:FindFirstChildWhichIsA("BasePart")
                local distance = getDistance(part)
                if distance <= range then
                    table.insert(barrelsInRange, {part = barrel, dist = distance})
                end
            end
        end
    end

    -- Sắp xếp từ gần đến xa
    table.sort(barrelsInRange, function(a, b)
        return a.dist < b.dist
    end)

    -- Click lần lượt
    for _, data in ipairs(barrelsInRange) do
        if not isPressing then break end
        clickBarrel(data.part)
        task.wait(math.random(10, 30) / 100)
    end
end

---------------------------------------------------------------------
--// Xử lý phím bấm
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Phím L: auto dùng Tool
    if input.KeyCode == Enum.KeyCode.L then
        if not isRunning then
            isRunning = true
            processTools()
            isRunning = false
        else
            isRunning = false
        end
    end

    -- Phím P: auto click Barrel/Crate
    if input.KeyCode == Enum.KeyCode.P then
        if not isPressing then
            isPressing = true
            processBarrels()
            isPressing = false
        end
    end
end)
