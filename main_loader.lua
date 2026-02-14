-- main_loader.lua
local baseUrl = "https://raw.githubusercontent.com/hickwhither/my-new-pc/refs/heads/master/"
-- baseUrl = "http://localhost:8000/" -- debug

local function fetch(name)
    local ok, res = pcall(function() return loadstring(game:HttpGet(baseUrl .. name))() end)
    if not ok then
        warn("Lỗi tải module " .. name .. ": " .. tostring(res))
    end
    return res
end

_G.class = fetch("pack/class.lua")
_G.offlineservice = fetch("pack/offlineservice.lua")

_G.services = {
    Workspace = game:GetService("Workspace"),
    Players = game:GetService("Players"),
    UIS = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    Lighting = game:GetService("Lighting")
}


_G.state = {
    running = true,
    connections = {},        -- tất cả connections chung
    visualObjects = {},      -- map object -> visuals
    itemTracers = {},        -- map object -> tracer parts
    objectConnections = {},  -- map object -> list of per-object connections
    dangerousParts = setmetatable({}, { __mode = "k" }),

    settings = {},

    -- safe mode physics
    safeModeActive = false,
    originalCFrame = nil,
    bodyVel = nil,
    bodyGyro = nil,

    originalLighting = nil
}

_G.config = {}
_G.config.DANGEROUS_ENTITY_NAMES = {
    ["Angler"] = true,
    ["Froger"] = true,
    ["Pinkie"] = true,
    ["Blitz"] = true,
    ["Chainsmoker"] = true,
    ["Pandemonium"] = true,
}

fetch("Utils.lua")
fetch("Visuals.lua")
fetch("UI.lua")
fetch("Watcher.lua")

fetch("mods/Safe.lua")
fetch("mods/Fullbright.lua")
fetch("mods/Teleport.lua")

print("✅ Modules loaded from " .. baseUrl)
