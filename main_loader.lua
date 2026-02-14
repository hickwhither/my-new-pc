-- main_loader.lua
-- Loader file: fetch các module từ http://localhost:8000/<file>
local baseUrl = "http://localhost:8000/"

local function fetch(name)
    local ok, res = pcall(function() return loadstring(game:HttpGet(baseUrl .. name))() end)
    if not ok then
        error("Lỗi tải module " .. name .. ": " .. tostring(res))
    end
    return res
end

-- Tải state + config trước
local state = fetch("state.lua")
local config = fetch("config.lua")

-- Dịch vụ
local services = {
    Workspace = game:GetService("Workspace"),
    Players = game:GetService("Players"),
    UIS = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    Lighting = game:GetService("Lighting")
}

-- Tải module khác
local utilsMod = fetch("utils.lua")
local visualsMod = fetch("visuals.lua")
local safeMod = fetch("safe_mode.lua")
local uiMod = fetch("ui.lua")
local watchersMod = fetch("watchers.lua")

-- Init module (truyền dependencies)
local utils = utilsMod.Init(services, state, config)
local visuals = visualsMod.Init(services, state, config, utils)
local safe = safeMod.Init(services, state, config, utils)
local ui = uiMod.Init(services, state, config, utils, visuals, safe)
local watchers = watchersMod.Init(services, state, config, utils, visuals, safe, ui)

-- Start UI + watchers
pcall(function()
    ui.createUI()
    watchers.Start()
end)

print("✅ Modules loaded from " .. baseUrl)
