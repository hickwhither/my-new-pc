-- main_loader.lua
local remoteBaseUrl = "https://raw.githubusercontent.com/hickwhither/my-new-pc/refs/heads/master/"
local bridgeBaseUrl = _G.BRIDGE_BASE_URL -- ví dụ: "http://127.0.0.1:8765"

-- Ưu tiên bridge nếu người dùng bật, fallback về GitHub raw
local baseUrl = bridgeBaseUrl and (bridgeBaseUrl .. "/src/") or remoteBaseUrl

local function http_get(url)
    return game:HttpGet(url)
end

local function safe_json_decode(raw)
    local ok, decoded = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if ok then
        return decoded
    end
    return nil
end

local function fetch(name)
    local ok, res = pcall(function()
        return loadstring(http_get(baseUrl .. name))()
    end)
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
    Lighting = game:GetService("Lighting"),
    HttpService = game:GetService("HttpService")
}

_G.state = {
    running = true,
    connections = {},        -- tất cả connections chung
    visualObjects = {},      -- map object -> visuals
    itemTracers = {},        -- map object -> tracer parts
    objectConnections = {},  -- map object -> list of per-object connections

    settings = {},

    -- safe mode physics
    safeModeActive = false,
    originalCFrame = nil,
    bodyVel = nil,
    bodyGyro = nil,

    originalLighting = nil,

    -- new: objects by kind
    objectsByKind = {},      -- map kind -> list of objects
    objectKinds = {},        -- map object -> kind

    -- bridge sync
    bridgeEnabled = bridgeBaseUrl ~= nil,
    bridgeLastChangeId = 0,
    bridgeChanges = {}
}

_G.config = {}
_G.config.DANGEROUS_ENTITY_NAMES = {
    ["Angler"]=true,["Froger"]=true,["Pinkie"]=true,["Blitz"]=true,["Chainsmoker"]=true,
    ["Pandemonium"]=true,
    ["Pipsqueak"]=true,["A60"]=true,["A200"]=true,

    ["Bleach"]=true,["Harbinger"]=true,["Mirage"]=true,

    ["Anglemonium"]=true,["Frogermonium"]=true,["Pinkimonium"]=true,
    ["Pandesmoker"]=true,["Blitzemonium"]=true,

    ["WitchingHour"] = true,
    ["Carnation"] = true,
}
_G.config.DANGEROUS_DELETEABLE = {
    ["Pandemonium"]=true,
    ["Pipsqueak"]=true,
    ["Harbinger"]=true,
    ["Anglemonium"]=true,["Frogermonium"]=true,["Pinkimonium"]=true,
    ["Pandesmoker"]=true,["Blitzemonium"]=true,

    ["WitchingHour"] = true,
}

local function apply_bridge_change(change)
    if type(change) ~= "table" then
        return
    end

    local actionId = change.action_id
    local payload = change.payload or {}

    if change.type == "action" then
        _G.state.settings[actionId] = payload.active
    elseif change.type == "keybind" then
        _G.state.settings[actionId .. "_keybind"] = payload.key
    end

    table.insert(_G.state.bridgeChanges, change)
end

local function start_bridge_polling()
    if not bridgeBaseUrl then
        return
    end

    task.spawn(function()
        while _G.state.running do
            local url = bridgeBaseUrl .. "/changes?since=" .. tostring(_G.state.bridgeLastChangeId)
            local ok, raw = pcall(function()
                return http_get(url)
            end)

            if ok and raw then
                local decoded = safe_json_decode(raw)
                if decoded and decoded.status == "ok" then
                    local changes = decoded.changes or {}
                    for _, change in ipairs(changes) do
                        apply_bridge_change(change)
                    end
                    _G.state.bridgeLastChangeId = decoded.latest or _G.state.bridgeLastChangeId
                end
            end

            task.wait(0.35)
        end
    end)
end

fetch("Utils.lua")
fetch("Visuals.lua")
fetch("UI.lua")
fetch("Watcher.lua")

fetch("mods/Fullbright.lua")
fetch("mods/Flight.lua")
fetch("mods/Speed.lua")
fetch("mods/Noclip.lua")
fetch("mods/Speedrun.lua")
fetch("mods/Safe.lua")
fetch("mods/Auto_Pickup.lua")
fetch("mods/GuiMonsterKiller.lua")

start_bridge_polling()

print("✅ Modules loaded from " .. baseUrl)
if bridgeBaseUrl then
    print("🔌 Bridge polling enabled at " .. bridgeBaseUrl)
end
