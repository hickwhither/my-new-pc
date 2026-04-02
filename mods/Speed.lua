local SpeedService = _G.offlineservice("Speed")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

-- Khởi tạo giá trị mặc định nếu chưa có
_G.WALK_SPEED = _G.WALK_SPEED or 50 
local speedEnabled = false

-- Hàm cập nhật tốc độ
local function updateSpeed()
    if speedEnabled and localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = _G.WALK_SPEED
        end
    end
end

-- Lắng nghe sự kiện bật/tắt từ UI
_G.UI.addEventHandler("setSpeedEnabled", function(enabled)
    speedEnabled = enabled
    
    -- Nếu tắt, trả tốc độ về mặc định (16)
    if not enabled and localPlayer.Character then
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end)

-- Sử dụng Heartbeat để duy trì tốc độ (chống lại các script khác của game tự set lại speed)
RunService.Heartbeat:Connect(function()
    updateSpeed()
end)

-- Đảm bảo khi nhân vật hồi sinh (respawn) vẫn áp dụng được tốc độ
localPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    if speedEnabled then
        humanoid.WalkSpeed = _G.WALK_SPEED
    end
end)