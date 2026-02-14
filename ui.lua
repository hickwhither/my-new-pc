-- UI.lua

-- UI.createButton(name, color)
-- UI.addEventHandler(name, fn)
-- UI.addStopHandler(fn)

-- UI.setWarningText(name, text)

local UI = _G.offlineservice("UI")

local Players = _G.services.Players
local UIS = _G.services.UIS
local Lighting = _G.services.Lighting

local screenGui
local warningLabel
local mainFrame
local container

-- internal state
UI.buttons = {}         -- name -> button instance
UI.handlers = {}        -- name -> {fn1, fn2, ...}
UI.stopHandlers = {}    -- extra handlers when stop pressed
UI.warnings = {}        -- name -> text
UI.warningsOrder = {}   -- ordered list of names (preserve insertion order)

-- helper: rebuild warningLabel text from warningsOrder
local function rebuildWarnings()
    if not warningLabel then return end

    -- remove names that no longer exist in warnings map
    local cleaned = {}
    for _, name in ipairs(UI.warningsOrder) do
        if UI.warnings[name] then table.insert(cleaned, name) end
    end
    UI.warningsOrder = cleaned

    if #UI.warningsOrder == 0 then
        warningLabel.Visible = false
        return
    end

    local lines = {}
    for _, name in ipairs(UI.warningsOrder) do
        local txt = UI.warnings[name]
        if txt and txt ~= "" then
            table.insert(lines, txt)
        end
    end

    if #lines == 0 then
        warningLabel.Visible = false
    else
        warningLabel.Text = "⚠️ CẢNH BÁO ⚠️\n" .. table.concat(lines, "\n")
        warningLabel.Visible = true
    end
end

-- public: set or clear a named warning
function UI.setWarningText(name, text)
    if not name then return end
    if text == nil then
        if UI.warnings[name] then
            UI.warnings[name] = nil
            for i, n in ipairs(UI.warningsOrder) do
                if n == name then
                    table.remove(UI.warningsOrder, i)
                    break
                end
            end
        end
    else
        if not UI.warnings[name] then
            table.insert(UI.warningsOrder, name)
        end
        UI.warnings[name] = tostring(text)
    end
    rebuildWarnings()
end

-- public: add event handler for button (multiple allowed)
function UI.addEventHandler(name, fn)
    if type(name) ~= "string" then return end
    if type(fn) ~= "function" then return end

    UI.handlers[name] = UI.handlers[name] or {}
    table.insert(UI.handlers[name], fn)
end

-- public: add extra stop handler
function UI.addStopHandler(fn)
    if type(fn) ~= "function" then return end
    table.insert(UI.stopHandlers, fn)
end

-- internal: small button factory used by UI.createButton
local function makeButtonInstance(btnText, bgColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 220, 0, 36)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(50, 50, 50)
    b.Text = btnText or ""
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = b
    b.Parent = container
    return b
end

-- public: create a named button (color optional). Returns the button instance.
-- Name should be unique; if exists, returns existing button.
function UI.createButton(name, color)
    if type(name) ~= "string" then
        error("UI.createButton: name must be string")
    end

    if UI.buttons[name] then
        return UI.buttons[name]
    end

    local isToggle = _G.state
        and _G.state.settings
        and _G.state.settings[name] ~= nil

    local function getDisplayText()
        if isToggle then
            return name .. ": " ..
                (_G.state.settings[name] and "BẬT" or "TẮT")
        else
            return name
        end
    end

    local function getColor()
        if isToggle then
            return _G.state.settings[name]
                and Color3.fromRGB(37, 170, 61)
                or Color3.fromRGB(50, 50, 50)
        else
            return color or Color3.fromRGB(50, 50, 50)
        end
    end

    local btn = makeButtonInstance(getDisplayText(), getColor())

    btn.MouseButton1Click:Connect(function()
        -- toggle
        if isToggle then
            _G.state.settings[name] = not _G.state.settings[name]
            btn.Text = getDisplayText()
            btn.BackgroundColor3 = getColor()
        end

        -- handlers
        local list = UI.handlers[name]
        if list then
            for _, fn in ipairs(list) do
                pcall(fn, _G.state.settings[name]) -- pass new state
            end
        end
    end)

    UI.buttons[name] = btn
    return btn
end


local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

screenGui = Instance.new("ScreenGui")
screenGui.Name = "Internal_Service_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = pgui

mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 260)
mainFrame.AnchorPoint = Vector2.new(1, 0.5)
mainFrame.Position = UDim2.new(1, -20, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local modalToggle = Instance.new("TextButton")
modalToggle.Size = UDim2.new(0, 0, 0, 0)
modalToggle.Modal = false
modalToggle.BackgroundTransparency = 1
modalToggle.Text = ""
modalToggle.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.Text = "INTERNAL CONTROL"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(0, 500, 0, 80)
warningLabel.AnchorPoint = Vector2.new(0.5, 0)
warningLabel.Position = UDim2.new(0.5, 0, 0.1, 0)
warningLabel.Text = "⚠️ CẢNH BÁO ⚠️"
warningLabel.TextColor3 = Color3.fromRGB(255, 30, 30)
warningLabel.BackgroundTransparency = 1
warningLabel.Font = Enum.Font.GothamBlack
warningLabel.TextSize = 24
warningLabel.Visible = false
warningLabel.TextWrapped = true
warningLabel.Parent = screenGui

container = Instance.new("Frame")
container.Size = UDim2.new(1, -20, 1, -120)
container.Position = UDim2.new(0, 10, 0, 50)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = container

-- Pre-built helpful buttons (kept for convenience)
local function makeDefaultButton(text, color, cb)
    local b = makeButtonInstance(text, color)
    b.MouseButton1Click:Connect(function()
        pcall(cb)
    end)
    return b
end

-- toggleUI
local function toggleUI()
    local isVisible = not mainFrame.Visible
    mainFrame.Visible = isVisible
    modalToggle.Modal = isVisible
    UIS.MouseIconEnabled = isVisible
    UIS.MouseBehavior = isVisible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
end

-- Stop script button (kept)
local killBtn = makeDefaultButton("DỪNG SCRIPT", Color3.fromRGB(120, 0, 0), function()
    _G.state.running = false
    if _G.Safe and _G.Safe.toggleSafeMode then
        pcall(function() _G.Safe.toggleSafeMode(false) end)
    end
    for _, c in ipairs(_G.state.connections) do
        pcall(function() c:Disconnect() end)
    end
    _G.state.connections = {}
    for obj, _ in pairs(_G.state.visualObjects) do
        if _G.Visuals and _G.Visuals.removeVisual then
            pcall(function() _G.Visuals.removeVisual(obj) end)
        end
    end

    -- fire extra stop handlers
    for _, fn in ipairs(UI.stopHandlers) do
        pcall(fn)
    end
    
    toggleUI()
    screenGui:Destroy()
    print("✅ Script đã dừng (UI requested).")
end)

-- backquote; Ctrl+backquote => kill
local inputConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Backquote then
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            killBtn:Activate()
        else
            toggleUI()
        end
    end
end)
table.insert(_G.state.connections, inputConn)


