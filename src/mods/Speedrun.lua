-- Speedrun.lua
local Speedrun = _G.offlineservice("Speedrun")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- UI Register
_G.state.settings.Speedrun = false
_G.UI.createButton("Speedrun", Color3.new(0.129411, 0, 0.490196), "AUTO")

_G.UI.addEventHandler("Speedrun", function(enabled)
    _G.state.settings.Speedrun = enabled
    Speedrun:toggle(enabled)
end)

_G.UI.addStopHandler(function()
    _G.state.settings.Speedrun = false
    Speedrun:toggle(false)
end)

-- Helper functions
local function getCharacter()
    local player = Players.LocalPlayer
    return player and player.Character
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findNearestNormalKeyCard()
    local root = getRootPart()
    if not root then return end
    -- Find in objectsByKind["Item"] those with Name containing "NormalKeyCard"
    local items = _G.state.objectsByKind["Item"] or {}
    local nearest, dist = nil, math.huge
    for _, item in ipairs(items) do
        if string.find(item.Name, "NormalKeyCard") then
            local d = (_G.Utils.getPrimaryPart(item).Position - _G.Utils.getPrimaryPart(root).Position).Magnitude
            if d < dist then
                nearest, dist = item, d
            end
        end
    end
    return nearest
end

local function openLock(door)
    local lock = door:FindFirstChild("Lock")
    if lock and lock:FindFirstChild("Main") and lock.Main:FindFirstChild("ProximityPrompt") then
        local pp = lock.Main.ProximityPrompt
        pp:InputHoldBegin()
        pp.HoldDuration = 0
        task.wait(0.1)
        pp:InputHoldEnd()
    end
end

function Speedrun:toggle(enabled)
    if enabled then
        self:startSpeedrunLoop()
    else
        self:stopSpeedrunLoop()
    end
end

function Speedrun:startSpeedrunLoop()
    self.running = true
    task.spawn(function()
        while self.running do
            self:processNextDoor()
            task.wait(1)  -- Wait 1s before next door
        end
    end)
end

function Speedrun:stopSpeedrunLoop()
    self.running = false
end

function Speedrun:processNextDoor()
    local door = _G.Watcher.latestDoors[1]
    local doorPosition = _G.Utils.getPrimaryPart(door).Position + Vector3.new(0, -3, 0)
    if not door then return end
    local hasLock = door:FindFirstChild("Lock") ~= nil

    if not hasLock then
        _G.Utils.teleportToPosition(doorPosition)
        task.wait(0.5)
        local upPos = doorPosition + Vector3.new(0, 100, 0)
        _G.Utils.teleportToPosition(upPos)
    else
        -- Find key, tele to key, tele to door, tele up 100 in 1s, tele back, open lock
        local key = findNearestNormalKeyCard()
        if key then
            _G.Utils.teleportToPosition(_G.Utils.getPrimaryPart(key).Position)
            task.wait(0.5)  -- Wait a bit
        end
        _G.Utils.teleportToPosition(doorPosition)
        task.wait(0.5)
        local upPos = doorPosition + Vector3.new(0, 100, 0)
        _G.Utils.teleportToPosition(upPos)
        task.wait(1)
        _G.Utils.teleportToPosition(doorPosition)
        task.wait(0.5)
        openLock(door)
    end
end

