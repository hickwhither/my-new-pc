-- UI.lua

-- UI.createButton(name, color, category)
-- UI.addEventHandler(name, fn)
-- UI.addStopHandler(fn)
-- UI.setWarningText(name, text)

local UI = _G.offlineservice("UI")

local Players = _G.services.Players
local UIS = _G.services.UIS

local screenGui
local warningsContainer
local mainFrame
local container

-- internal state
UI.buttons = {}            -- name -> action button instance
UI.buttonRows = {}         -- name -> row frame
UI.bindButtons = {}        -- name -> bind button instance
UI.handlers = {}           -- name -> {fn1, fn2, ...}
UI.stopHandlers = {}       -- extra handlers when stop pressed
UI.warnings = {}           -- name -> text
UI.warningsOrder = {}      -- ordered list of names (preserve insertion order)
UI.categories = {}         -- category -> {row1, row2, ...}
UI.categoryFrames = {}     -- category -> section frame
UI.keybinds = {}           -- name -> Enum.KeyCode
UI.captureBindFor = nil    -- current button waiting for keybind
UI.actions = {}            -- name -> action function

local DEFAULT_CATEGORY_ORDER = {
    "SYSTEM",
    "BASIC",
    "VISUAL",
    "AUTO",
}

local CATEGORY_RULES = {
    { category = "BASIC", patterns = { "speed", "noclip", "flight", "jump", "run" } },
    { category = "WORLD", patterns = { "pickup", "node", "safe", "farm", "monster", "kill" } },
    { category = "VISUAL", patterns = { "bright", "visual", "esp", "shader" } },
}

local function normalizeCategory(category)
    if type(category) ~= "string" then return nil end
    category = category:upper()
    if category == "" then return nil end
    return category
end

local function resolveCategory(name, preferred)
    local explicit = normalizeCategory(preferred)
    if explicit then
        return explicit
    end

    local lowerName = string.lower(name)
    for _, rule in ipairs(CATEGORY_RULES) do
        for _, pattern in ipairs(rule.patterns) do
            if string.find(lowerName, pattern, 1, true) then
                return rule.category
            end
        end
    end

    return "MISC"
end

local function formatKeyCode(keyCode)
    if not keyCode then
        return "NONE"
    end
    return tostring(keyCode):gsub("Enum.KeyCode.", "")
end

-- helper: rebuild warning labels from warningsOrder
local function rebuildWarnings()
    if not warningsContainer then return end

    for _, child in ipairs(warningsContainer:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for _, name in ipairs(UI.warningsOrder) do
        local warn = UI.warnings[name]
        if warn and warn.text and warn.text ~= "" then
            local label = Instance.new("TextLabel")
            label.Name = name
            label.Size = UDim2.new(1, 0, 0, 30)
            label.Text = warn.text
            label.TextColor3 = warn.color
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBlack
            label.TextSize = 24
            label.TextWrapped = true
            label.Parent = warningsContainer
        end
    end
end

-- public: set or clear a named warning
function UI.setWarningText(name, text, color)
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
        UI.warnings[name] = {text = tostring(text), color = color or Color3.fromRGB(255, 30, 30)}
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

local function makeSection(category)
    if UI.categoryFrames[category] then
        return UI.categoryFrames[category]
    end

    local section = Instance.new("Frame")
    section.Name = category .. "_Section"
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    section.BorderSizePixel = 0
    section.Parent = container

    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = section

    local sectionStroke = Instance.new("UIStroke")
    sectionStroke.Color = Color3.fromRGB(45, 45, 45)
    sectionStroke.Thickness = 1
    sectionStroke.Parent = section

    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Name = "CategoryTitle"
    sectionTitle.Size = UDim2.new(1, -14, 0, 24)
    sectionTitle.Position = UDim2.new(0, 7, 0, 6)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextSize = 12
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.TextColor3 = Color3.fromRGB(190, 190, 190)
    sectionTitle.Text = category
    sectionTitle.Parent = section

    local rows = Instance.new("Frame")
    rows.Name = "Rows"
    rows.Size = UDim2.new(1, -14, 0, 0)
    rows.Position = UDim2.new(0, 7, 0, 34)
    rows.BackgroundTransparency = 1
    rows.AutomaticSize = Enum.AutomaticSize.Y
    rows.Parent = section

    local rowsLayout = Instance.new("UIListLayout")
    rowsLayout.Padding = UDim.new(0, 6)
    rowsLayout.FillDirection = Enum.FillDirection.Vertical
    rowsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    rowsLayout.Parent = rows

    local rowsPadding = Instance.new("UIPadding")
    rowsPadding.PaddingBottom = UDim.new(0, 8)
    rowsPadding.Parent = rows

    UI.categoryFrames[category] = section
    UI.categories[category] = UI.categories[category] or {}
    return section
end

local function sortSections()
    if not container then return end

    local orderMap = {}
    for i, cat in ipairs(DEFAULT_CATEGORY_ORDER) do
        orderMap[cat] = i
    end

    local sections = {}
    for category, section in pairs(UI.categoryFrames) do
        table.insert(sections, { category = category, section = section })
    end

    table.sort(sections, function(a, b)
        local ai = orderMap[a.category] or 999
        local bi = orderMap[b.category] or 999
        if ai == bi then
            return a.category < b.category
        end
        return ai < bi
    end)

    for idx, item in ipairs(sections) do
        item.section.LayoutOrder = idx
    end
end

-- internal: create row with action button + keybind button
local function makeButtonRow(btnText, bgColor, category)
    local section = makeSection(category)
    local rows = section:FindFirstChild("Rows")

    local row = Instance.new("Frame")
    row.Name = btnText .. "_Row"
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = rows

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 6)
    rowLayout.Parent = row

    local action = Instance.new("TextButton")
    action.Name = "Action"
    action.Size = UDim2.new(1, -90, 1, 0)
    action.BackgroundColor3 = bgColor or Color3.fromRGB(50, 50, 50)
    action.Text = btnText or ""
    action.TextColor3 = Color3.new(1, 1, 1)
    action.Font = Enum.Font.GothamBold
    action.TextSize = 13
    action.AutoButtonColor = true
    action.Parent = row

    local actionCorner = Instance.new("UICorner")
    actionCorner.CornerRadius = UDim.new(0, 6)
    actionCorner.Parent = action

    local bind = Instance.new("TextButton")
    bind.Name = "Bind"
    bind.Size = UDim2.new(0, 84, 1, 0)
    bind.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    bind.Text = "[NONE]"
    bind.TextColor3 = Color3.fromRGB(200, 200, 200)
    bind.Font = Enum.Font.GothamSemibold
    bind.TextSize = 11
    bind.AutoButtonColor = true
    bind.Parent = row

    local bindCorner = Instance.new("UICorner")
    bindCorner.CornerRadius = UDim.new(0, 6)
    bindCorner.Parent = bind

    return row, action, bind
end

-- public: create a named button (color optional). Returns the action button instance.
-- Name should be unique; if exists, returns existing action button.
function UI.createButton(name, color, category)
    if type(name) ~= "string" then
        error("UI.createButton: name must be string")
    end

    if UI.buttons[name] then
        return UI.buttons[name]
    end

    local isToggle = _G.state.settings[name] ~= nil
    local resolvedCategory = resolveCategory(name, category)

    local function getDisplayText()
        if isToggle then
            return name .. "  [" .. (_G.state.settings[name] and "ON" or "OFF") .. "]"
        else
            return name
        end
    end

    color = color or Color3.fromRGB(40, 170, 70)
    local function getColor()
        if isToggle then
            return _G.state.settings[name]
                and color
                or Color3.fromRGB(50, 50, 50)
        else
            return color or Color3.fromRGB(50, 50, 50)
        end
    end

    local row, btn, bindBtn = makeButtonRow(getDisplayText(), getColor(), resolvedCategory)

    btn.Name = name

    local function runButtonAction()
        if isToggle then
            _G.state.settings[name] = not _G.state.settings[name]
            btn.Text = getDisplayText()
            btn.BackgroundColor3 = getColor()
        end

        local list = UI.handlers[name]
        if list then
            for _, fn in ipairs(list) do
                task.spawn(function()
                    pcall(fn, _G.state.settings[name])
                end)
            end
        end
    end

    UI.actions[name] = runButtonAction
    btn.MouseButton1Click:Connect(runButtonAction)

    bindBtn.MouseButton1Click:Connect(function()
        UI.captureBindFor = name
        bindBtn.Text = "[PRESS...]"
        bindBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
    end)

    UI.buttons[name] = btn
    UI.bindButtons[name] = bindBtn
    UI.buttonRows[name] = row
    UI.categories[resolvedCategory] = UI.categories[resolvedCategory] or {}
    table.insert(UI.categories[resolvedCategory], row)
    sortSections()

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
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 420, 0, 520)
mainFrame.AnchorPoint = Vector2.new(1, 0.5)
mainFrame.Position = UDim2.new(1, -20, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainFrameCorner = Instance.new("UICorner")
mainFrameCorner.Name = "MainFrameCorner"
mainFrameCorner.CornerRadius = UDim.new(0, 10)
mainFrameCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 1
mainStroke.Color = Color3.fromRGB(52, 52, 52)
mainStroke.Parent = mainFrame

local modalToggle = Instance.new("TextButton")
modalToggle.Name = "ModalToggle"
modalToggle.Size = UDim2.new(0, 0, 0, 0)
modalToggle.Modal = false
modalToggle.BackgroundTransparency = 1
modalToggle.Text = ""
modalToggle.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.new(0, 10, 0, 8)
title.Text = "INTERNAL CLIENT"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -20, 0, 18)
hint.Position = UDim2.new(0, 10, 0, 34)
hint.Text = "RightShift: Open/Close | Ctrl + RightShift: Stop"
hint.TextColor3 = Color3.fromRGB(145, 145, 145)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 10
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = mainFrame

warningsContainer = Instance.new("Frame")
warningsContainer.Name = "WarningsContainer"
warningsContainer.Size = UDim2.new(1, 0, 0, 0)
warningsContainer.AnchorPoint = Vector2.new(0.5, 0)
warningsContainer.Position = UDim2.new(0.5, 0, 0.2, 0)
warningsContainer.BackgroundTransparency = 1
warningsContainer.Visible = true
warningsContainer.AutomaticSize = Enum.AutomaticSize.Y
warningsContainer.Parent = screenGui

local warningsLayout = Instance.new("UIListLayout")
warningsLayout.Name = "WarningsLayout"
warningsLayout.Padding = UDim.new(0, 5)
warningsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
warningsLayout.Parent = warningsContainer

container = Instance.new("ScrollingFrame")
container.Name = "ButtonsContainer"
container.Size = UDim2.new(1, -20, 1, -70)
container.Position = UDim2.new(0, 10, 0, 58)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ScrollBarThickness = 4
container.CanvasSize = UDim2.new(0, 0, 0, 0)
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Name = "ButtonsLayout"
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = container

-- toggleUI
local function toggleUI()
    local isVisible = not mainFrame.Visible
    mainFrame.Visible = isVisible
    modalToggle.Modal = isVisible
    UIS.MouseIconEnabled = isVisible
    UIS.MouseBehavior = isVisible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
end

-- Stop script button
local function killBtnEvent()
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

    for _, fn in ipairs(UI.stopHandlers) do
        pcall(fn)
    end

    toggleUI()
    screenGui:Destroy()
    print("✅ Script đã dừng (UI requested).")
end

UI.createButton("DỪNG SCRIPT", Color3.fromRGB(120, 0, 0), "SYSTEM")
UI.addEventHandler("DỪNG SCRIPT", killBtnEvent)

local function refreshBindLabel(name)
    local bindBtn = UI.bindButtons[name]
    if not bindBtn then return end

    bindBtn.Text = "[" .. formatKeyCode(UI.keybinds[name]) .. "]"
    bindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
end

local function triggerByKeybind(input)
    for name, keyCode in pairs(UI.keybinds) do
        if keyCode == input.KeyCode then
            local action = UI.actions[name]
            if action then
                action()
            end
            break
        end
    end
end

-- RightShift; Ctrl+RightShift => kill, and custom module keybinds
local inputConn = UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if UI.captureBindFor then
        local targetName = UI.captureBindFor
        UI.captureBindFor = nil

        if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
            UI.keybinds[targetName] = nil
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
            if UI.keybinds[targetName] == input.KeyCode then
                UI.keybinds[targetName] = nil
            else
                UI.keybinds[targetName] = input.KeyCode
            end
        end

        refreshBindLabel(targetName)
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            killBtnEvent()
        else
            toggleUI()
        end
        return
    end

    triggerByKeybind(input)
end)
table.insert(_G.state.connections, inputConn)
