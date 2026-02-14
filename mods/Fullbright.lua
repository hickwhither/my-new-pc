-- Fullbright.lua
local Fullbright = _G.offlineservice("Fullbright")

local Lighting = _G.services.Lighting
local RunService = _G.services.RunService

local fbConnection

_G.state.settings.fullbrightEnabled = false
_G.UI.createButton("fullbrightEnabled", Color3.fromRGB(0, 170, 255))
_G.UI.addEventHandler("fullbrightEnabled", function(state) Fullbright.toggle(state) end)
_G.UI.addStopHandler(function() Fullbright.cleanup() end)

local function applyFullbright()
    pcall(function()
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = false
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
    end)
end

function Fullbright.toggle(enable)
    if enable then
        if _G.state.settings.fullbrightEnabled then return end

        -- save original once
        if not _G.state.originalLighting then
            _G.state.originalLighting = {
                Ambient = Lighting.Ambient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                ColorShift_Top = Lighting.ColorShift_Top,
                ColorShift_Bottom = Lighting.ColorShift_Bottom
            }
        end

        applyFullbright()

        if fbConnection then fbConnection:Disconnect() end
        fbConnection = RunService.Heartbeat:Connect(function()
            if _G.state.settings.fullbrightEnabled then
                applyFullbright()
            end
        end)

        table.insert(_G.state.connections, fbConnection)
        _G.state.settings.fullbrightEnabled = true

    else
        if not _G.state.settings.fullbrightEnabled then return end

        -- restore lighting
        if _G.state.originalLighting then
            pcall(function()
                Lighting.Ambient = _G.state.originalLighting.Ambient
                Lighting.Brightness = _G.state.originalLighting.Brightness
                Lighting.ClockTime = _G.state.originalLighting.ClockTime
                Lighting.GlobalShadows = _G.state.originalLighting.GlobalShadows
                Lighting.ColorShift_Top = _G.state.originalLighting.ColorShift_Top
                Lighting.ColorShift_Bottom = _G.state.originalLighting.ColorShift_Bottom
            end)
            _G.state.originalLighting = nil
        end

        if fbConnection then
            fbConnection:Disconnect()
            fbConnection = nil
        end

        _G.state.settings.fullbrightEnabled = false
    end
end

function Fullbright.cleanup()
    if fbConnection then
        fbConnection:Disconnect()
        fbConnection = nil
    end
    -- nếu vẫn bật, tắt nó để restore lighting
    local stillOn = _G.state and _G.state.settings and _G.state.settings.fullbrightEnabled
    if stillOn then
        -- gọi toggle(false) để restore; pcall để an toàn
        pcall(function() Fullbright.toggle(false) end)
    end
end

