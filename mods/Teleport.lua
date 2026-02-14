-- Teleport.lua
local Teleport = _G.offlineservice and _G.offlineservice("Teleport") or {}

local Players = _G.services.Players

-- UI Bind
_G.UI.createButton("teleportToNextDoor", Color3.fromRGB(0, 120, 215))
_G.UI.addEventHandler("teleportToNextDoor", function()
    Teleport.teleportToNextDoor()
end)

-- Method
function Teleport.teleportToNextDoor()
    local player = Players.LocalPlayer
    if not player then return end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Kill text
    task.spawn(function()
        task.wait(2)
        _G.UI.setWarningText("teleport")
    end)

    local targetDoor = _G.Watcher.latestDoor

    if not targetDoor or not targetDoor.Parent then
        warn("❌ Không tìm thấy latestDoor.")
        if _G.UI and _G.UI.setWarningText then
            _G.UI.setWarningText("teleport", "❌ Không có cửa để dịch chuyển")
        end
        return
    end

    -- find position
    local posPart
    if targetDoor:IsA("Model") then
        if targetDoor.PrimaryPart then
            posPart = targetDoor.PrimaryPart.Position
        else
            local bp = targetDoor:FindFirstChildWhichIsA("BasePart")
            if bp then posPart = bp.Position end
        end
    elseif targetDoor:IsA("BasePart") then
        posPart = targetDoor.Position
    end
    if not posPart then
        warn("Teleport: không tìm được vị trí cửa.")

        if _G.UI and _G.UI.setWarningText then
            _G.UI.setWarningText("teleport", "❌ Không xác định được vị trí cửa")
        end
        return
    end

    -- teleport
    root.CFrame = CFrame.new(posPart + Vector3.new(0, 3, 0))
    if _G.UI and _G.UI.setWarningText then
        _G.UI.setWarningText("teleport", nil)
    end
    print("🚀 Đã dịch chuyển tới cửa mới nhất.")
end

