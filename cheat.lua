local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Character references (will be updated on respawn)
local Character
local HumanoidRootPart
local Humanoid
local Backpack

-- Folders
local cratesFolder = workspace:WaitForChild("Barrels"):WaitForChild("Crates")
local barrelsFolder = workspace:WaitForChild("Barrels"):WaitForChild("Barrels")

-- Settings table
local settings = {
    range = 10,
    autoEnabled = false,
    toolProcessing = false,
    originalWalkSpeed = 16,
    boostSpeed = 50,
    moveTimeout = 15,
    reachDistance = 4,
    retryAttempts = 3,
    safeDistance = 2,
    minClickDelay = 0.1,
    maxClickDelay = 0.3
}

-- State tracking
local currentConnection = nil
local isMoving = false
local lastPosition = Vector3.new(0, 0, 0)

-- Initialize character references
local function initializeCharacter(newCharacter)
    Character = newCharacter
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    Backpack = LocalPlayer:WaitForChild("Backpack")
    
    -- Store original walk speed
    settings.originalWalkSpeed = Humanoid.WalkSpeed
    
    -- Apply speed boost if auto is enabled
    if settings.autoEnabled then
        Humanoid.WalkSpeed = settings.boostSpeed
    end
    
    print("Character initialized successfully")
end

-- Safe character check
local function isCharacterValid()
    return Character and Character.Parent and HumanoidRootPart and HumanoidRootPart.Parent and Humanoid and Humanoid.Parent
end

-- Wait for valid character
local function waitForValidCharacter()
    local attempts = 0
    while not isCharacterValid() and attempts < 50 do
        attempts = attempts + 1
        task.wait(0.1)
        
        if LocalPlayer.Character then
            initializeCharacter(LocalPlayer.Character)
        end
    end
    
    return isCharacterValid()
end

-- Distance calculation with safety check
local function getDistance(part)
    if not isCharacterValid() or not part or not part.Position then
        return math.huge
    end
    return (HumanoidRootPart.Position - part.Position).Magnitude
end

-- Safe position check (avoid falling into void, lava, etc.)
local function isSafePosition(position)
    -- Basic safety checks
    if position.Y < -50 then -- Avoid void
        return false
    end
    
    -- You can add more safety checks here based on your game
    -- For example, check for lava, dangerous areas, etc.
    
    return true
end

-- Find safe path to target
local function findSafePosition(targetPosition)
    if isSafePosition(targetPosition) then
        return targetPosition
    end
    
    -- Try positions around the target
    local offsets = {
        Vector3.new(5, 0, 0),
        Vector3.new(-5, 0, 0),
        Vector3.new(0, 0, 5),
        Vector3.new(0, 0, -5),
        Vector3.new(3, 0, 3),
        Vector3.new(-3, 0, -3)
    }
    
    for _, offset in ipairs(offsets) do
        local testPos = targetPosition + offset
        if isSafePosition(testPos) then
            return testPos
        end
    end
    
    return targetPosition -- Return original if no safe position found
end

-- Click function with validation
local function clickBarrel(barrel)
    if not barrel or not barrel.Parent then
        return false
    end
    
    local clickDetector = barrel:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        local success, err = pcall(function()
            fireclickdetector(clickDetector)
        end)
        
        if success then
            return true
        else
            warn("Click failed:", err)
            return false
        end
    else
        warn("Không tìm thấy ClickDetector trong", barrel.Name)
        return false
    end
end

-- Enhanced move to target function
local function moveToTarget(targetPosition)
    if not settings.autoEnabled or not isCharacterValid() then 
        return false 
    end
    
    local safePosition = findSafePosition(targetPosition)
    local attempts = 0
    
    while attempts < settings.retryAttempts and settings.autoEnabled do
        attempts = attempts + 1
        
        -- Check if character is still valid
        if not waitForValidCharacter() then
            warn("Character not valid for movement attempt", attempts)
            task.wait(1)
            continue
        end
        
        isMoving = true
        Humanoid:MoveTo(safePosition)
        
        local startTime = tick()
        local reached = false
        local stuck = false
        lastPosition = HumanoidRootPart.Position
        
        -- Movement monitoring
        if currentConnection then
            currentConnection:Disconnect()
        end
        
        currentConnection = RunService.Heartbeat:Connect(function()
            if not settings.autoEnabled or not isCharacterValid() then
                reached = false
                return
            end
            
            local currentTime = tick()
            local distance = (HumanoidRootPart.Position - safePosition).Magnitude
            local timePassed = currentTime - startTime
            
            -- Check if reached target
            if distance < settings.reachDistance then
                reached = true
                return
            end
            
            -- Check for timeout
            if timePassed > settings.moveTimeout then
                warn("Movement timeout after", settings.moveTimeout, "seconds")
                reached = false
                return
            end
            
            -- Check if stuck (hasn't moved much in 3 seconds)
            if timePassed > 3 and (HumanoidRootPart.Position - lastPosition).Magnitude < 2 then
                warn("Player appears to be stuck, retrying...")
                stuck = true
                return
            end
            
            -- Update last position every 2 seconds
            if timePassed % 2 < 0.1 then
                lastPosition = HumanoidRootPart.Position
            end
        end)
        
        -- Wait for movement completion
        repeat
            task.wait(0.1)
        until reached or stuck or not settings.autoEnabled or not isCharacterValid()
        
        if currentConnection then
            currentConnection:Disconnect()
            currentConnection = nil
        end
        
        isMoving = false
        
        if reached then
            return true
        elseif stuck then
            -- Try to unstuck by jumping and moving to a slightly different position
            if isCharacterValid() then
                Humanoid.Jump = true
                task.wait(0.5)
                safePosition = safePosition + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
            end
        end
        
        task.wait(1) -- Wait before retry
    end
    
    warn("Failed to reach target after", settings.retryAttempts, "attempts")
    return false
end

-- Get all targets with improved validation
local function getAllTargets()
    if not isCharacterValid() then
        return {}
    end
    
    local targets = {}
    
    -- Get crates
    local success, crateChildren = pcall(function()
        return cratesFolder:GetChildren()
    end)
    
    if success then
        for _, crate in ipairs(crateChildren) do
            if crate and crate.Parent then
                local part = crate:IsA("BasePart") and crate or crate:FindFirstChildWhichIsA("BasePart")
                if part and part.Position then
                    local distance = getDistance(part)
                    if distance < math.huge then
                        table.insert(targets, {part = crate, pos = part.Position, dist = distance, type = "crate"})
                    end
                end
            end
        end
    end
    
    -- Get barrels
    success, crateChildren = pcall(function()
        return barrelsFolder:GetChildren()
    end)
    
    if success then
        for _, barrel in ipairs(crateChildren) do
            if barrel and barrel.Parent then
                local part = barrel:IsA("BasePart") and barrel or barrel:FindFirstChildWhichIsA("BasePart")
                if part and part.Position then
                    local distance = getDistance(part)
                    if distance < math.huge then
                        table.insert(targets, {part = barrel, pos = part.Position, dist = distance, type = "barrel"})
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(targets, function(a, b)
        return a.dist < b.dist
    end)
    
    return targets
end

-- Process targets with auto movement and respawn handling
local function processTargetsWithMovement()
    while settings.autoEnabled do
        -- Ensure character is valid
        if not waitForValidCharacter() then
            warn("Character not valid, waiting...")
            task.wait(2)
            continue
        end
        
        local targets = getAllTargets()
        
        if #targets == 0 then
            task.wait(1)
            continue
        end
        
        for _, targetData in ipairs(targets) do
            if not settings.autoEnabled then break end
            
            -- Re-check character validity
            if not waitForValidCharacter() then
                break
            end
            
            -- Skip if target is no longer valid
            if not targetData.part or not targetData.part.Parent then
                continue
            end
            
            -- Move to target
            local success = moveToTarget(targetData.pos)
            if not success then
                continue -- Try next target
            end
            
            -- Wait a bit after reaching
            task.wait(0.2)
            
            -- Click the target
            clickBarrel(targetData.part)
            
            -- Random delay
            task.wait(math.random(settings.minClickDelay * 100, settings.maxClickDelay * 100) / 100)
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

-- Process tools function with safety checks
local function processTools()
    if not waitForValidCharacter() then
        warn("Character not valid for tool processing!")
        return
    end
    
    local tools = Backpack:GetChildren()
    if #tools == 0 then
        warn("Không có Tool nào trong Backpack!")
        return
    end

    for _, tool in ipairs(tools) do
        if not settings.toolProcessing or not isCharacterValid() then break end
        
        if tool:IsA("Tool") then
            local success, err = pcall(function()
                tool.Parent = Character
                task.wait(0.05)
                if tool.Activate then
                    tool:Activate()
                end
                tool.Parent = Backpack
            end)
            
            if not success then
                warn("Tool processing error:", err)
            end
            
            smartWait()
        end
    end
end

-- Handle character respawn with improved initialization
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    print("Character respawned, reinitializing...")
    
    -- Clean up old connections
    if currentConnection then
        currentConnection:Disconnect()
        currentConnection = nil
    end
    
    -- Reset movement state
    isMoving = false
    
    -- Initialize new character
    initializeCharacter(newCharacter)
    
    -- Small delay to ensure everything is loaded
    task.wait(0.5)
    
    print("Character reinitialized after respawn")
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- P key for auto collect with movement
    if input.KeyCode == Enum.KeyCode.P then
        settings.autoEnabled = not settings.autoEnabled

        if settings.autoEnabled then
            print("Auto Collect ENABLED - Speed boosted to", settings.boostSpeed)
            if isCharacterValid() then
                Humanoid.WalkSpeed = settings.boostSpeed
            end
            spawn(processTargetsWithMovement)
        else
            print("Auto Collect DISABLED - Speed restored")
            if currentConnection then
                currentConnection:Disconnect()
                currentConnection = nil
            end
            if isCharacterValid() then
                Humanoid.WalkSpeed = settings.originalWalkSpeed
            end
        end
    end

    -- L key for tool processing
    if input.KeyCode == Enum.KeyCode.L then
        if not settings.toolProcessing then
            settings.toolProcessing = true
            print("Tool Processing ENABLED")
            spawn(function()
                processTools()
                settings.toolProcessing = false
                print("Tool Processing COMPLETED")
            end)
        else
            settings.toolProcessing = false
            print("Tool Processing DISABLED")
        end
    end
end)

-- Initialize on script load
if LocalPlayer.Character then
    initializeCharacter(LocalPlayer.Character)
end

print("Enhanced Script loaded!")
print("P - Toggle Auto Collect (with auto movement)")
print("L - Process Tools in Backpack")
print("Features: Death/respawn handling, stuck detection, safe pathfinding")
