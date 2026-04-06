-- Auto_Pickup.lua
local Auto_Pickup = _G.offlineservice("Auto_Pickup")

local connections = {}

--------------------------------------------------
-- UI REGISTER (giữ nguyên style của bạn)
--------------------------------------------------
_G.state.settings.AutoPickup = false
_G.UI.createButton("AutoPickup", Color3.fromRGB(255, 215, 0), "AUTO")  -- Màu vàng cho item pickup
_G.UI.addEventHandler("AutoPickup", function(state)
    Auto_Pickup.toggle(state)
end)
_G.UI.addStopHandler(function()
    if _G.state.settings.AutoPickup then
        pcall(function()
            Auto_Pickup.toggle(false)
        end)
    end
end)

--------------------------------------------------
-- Helper functions
--------------------------------------------------
local function findProximityPrompt(obj)
    -- Tìm ProximityPrompt sâu trong descendants, ưu tiên trong ProxyPart nếu có
    local proxy = obj:FindFirstChild("ProxyPart", true)
    if proxy then
        for _, child in ipairs(proxy:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                return child
            end
        end
    end
    -- Nếu không có ProxyPart hoặc không tìm thấy, tìm trong toàn bộ obj
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("ProximityPrompt") then
            return child
        end
    end
    return nil
end

local function autoPickup()
    while _G.state.settings.AutoPickup and _G.state.running do
        local player = _G.services.Players.LocalPlayer
        local character = player and player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            for _, obj in ipairs(_G.state.objectsByKind["Item"] or {}) do
                if obj and obj:IsDescendantOf(_G.services.Workspace) then
                    local objName = obj.Name or ""
                    if not (string.find(objName, "Currency") or objName == "NormalKeyCard" or objName == "PasswordPaper" or objName == "BluePrint") then continue end
                    local primarypart = _G.Utils.getPrimaryPart(obj)
                    local prompt = findProximityPrompt(obj)
                    if primarypart == nil then continue end
                    if prompt == nil then continue end
                    if prompt.Enabled == false then continue end
                    local distance = (hrp.Position - primarypart.Position).Magnitude
                    if distance > prompt.MaxActivationDistance then continue end
                    
                    prompt.RequiresLineOfSight = false  -- Xuyên tường
                    if prompt.HoldDuration > 0 then
                        prompt.Exclusivity = "AlwaysShow"
                        prompt:InputHoldBegin()
                        prompt.HoldDuration = 0
                        task.wait(0.1)
                        prompt:InputHoldEnd()
                    else
                        prompt:InputHoldBegin()
                    end
                end
            end
        end
        task.wait(0.1)  -- Độ trễ loop để không lag
    end
end

--------------------------------------------------
-- TOGGLE
--------------------------------------------------
function Auto_Pickup.toggle(enable)
    _G.state.settings.AutoPickup = enable
    if enable then
        task.spawn(autoPickup)
    end
end
