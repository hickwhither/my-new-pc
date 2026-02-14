-- ui.lua
local UI = {}

function UI.Init(services, state, config, utils, visuals, safe)
    local Players = services.Players
    local UIS = services.UIS
    local Lighting = services.Lighting

    local screenGui
    local warningLabel

    local function toggleFullbright(enable)
        if enable then
            if state.settings.fullbrightEnabled then return end
            state.originalLighting = {
                Ambient = Lighting.Ambient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                ColorShift_Top = Lighting.ColorShift_Top,
                ColorShift_Bottom = Lighting.ColorShift_Bottom
            }
            pcall(function()
                Lighting.Ambient = Color3.new(1,1,1)
                Lighting.Brightness = 2
                Lighting.ClockTime = 12
                Lighting.GlobalShadows = false
                Lighting.ColorShift_Top = Color3.new(1,1,1)
                Lighting.ColorShift_Bottom = Color3.new(1,1,1)
            end)
            state.settings.fullbrightEnabled = true
        else
            if not state.settings.fullbrightEnabled then return end
            if state.originalLighting then
                pcall(function()
                    Lighting.Ambient = state.originalLighting.Ambient
                    Lighting.Brightness = state.originalLighting.Brightness
                    Lighting.ClockTime = state.originalLighting.ClockTime
                    Lighting.GlobalShadows = state.originalLighting.GlobalShadows
                    Lighting.ColorShift_Top = state.originalLighting.ColorShift_Top
                    Lighting.ColorShift_Bottom = state.originalLighting.ColorShift_Bottom
                end)
                state.originalLighting = nil
            end
            state.settings.fullbrightEnabled = false
        end
    end

    function UI.createUI()
        local player = Players.LocalPlayer
        local pgui = player:WaitForChild("PlayerGui")

        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "Internal_Service_UI"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = pgui

        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 260, 0, 260)
        mainFrame.AnchorPoint = Vector2.new(1, 0.5)
        mainFrame.Position = UDim2.new(1, -20, 0.5, 0)
        mainFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Visible = false
        mainFrame.Parent = screenGui
        Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,10)

        local modalToggle = Instance.new("TextButton")
        modalToggle.Size = UDim2.new(0,0,0,0)
        modalToggle.Modal = false
        modalToggle.BackgroundTransparency = 1
        modalToggle.Text = ""
        modalToggle.Parent = mainFrame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1,0,0,45)
        title.Text = "INTERNAL CONTROL"
        title.TextColor3 = Color3.new(1,1,1)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.Parent = mainFrame

        warningLabel = Instance.new("TextLabel")
        warningLabel.Size = UDim2.new(0,500,0,80)
        warningLabel.AnchorPoint = Vector2.new(0.5,0)
        warningLabel.Position = UDim2.new(0.5,0,0.1,0)
        warningLabel.Text = "⚠️ CẢNH BÁO ⚠️"
        warningLabel.TextColor3 = Color3.fromRGB(255,30,30)
        warningLabel.BackgroundTransparency = 1
        warningLabel.Font = Enum.Font.GothamBlack
        warningLabel.TextSize = 24
        warningLabel.Visible = false
        warningLabel.Parent = screenGui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -20, 1, -120)
        container.Position = UDim2.new(0,10,0,50)
        container.BackgroundTransparency = 1
        container.Parent = mainFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0,8)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Parent = container

        local function makeButton(text, bg, callback)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0,220,0,36)
            b.BackgroundColor3 = bg
            b.Text = text
            b.TextColor3 = Color3.new(1,1,1)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 13
            Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
            b.Parent = container
            b.MouseButton1Click:Connect(callback)
            return b
        end

        for key, _ in state.settings do
            local btn
            btn = makeButton("", Color3.fromRGB(50,50,50), function()
                state.settings[key] = not state.settings[key]
                btn.Text = key .. ": " .. (state.settings[key] and "BẬT" or "TẮT")
                btn.BackgroundColor3 =
                    state.settings[key]
                    and Color3.fromRGB(37, 170, 61)
                    or Color3.fromRGB(50,50,50)
            end)
            btn.Text = key..": " .. (state.settings[key] and "BẬT" or "TẮT")
        end

        local tpBtn = makeButton("ĐẾN CỬA TIẾP THEO", Color3.fromRGB(0,120,215), function()
            pcall(function()
                if UI.teleportToNextDoor then UI.teleportToNextDoor() end
            end)
        end)

        -- NOTE: removed Password/KeyCard/Generator buttons from menu
        -- because teleport buttons are now on each BillboardGui

        local killBtn = makeButton("DỪNG SCRIPT", Color3.fromRGB(120,0,0), function()
            state.running = false
            safe.toggleSafeMode(false)
            for _, c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
            state.connections = {}
            for obj,_ in pairs(state.visualObjects) do visuals.removeVisual(obj) end
            if state.settings.fullbrightEnabled then toggleFullbright(false) end
            if screenGui then screenGui:Destroy() end
            print("✅ Script đã dừng (UI requested).")
        end)

        local function toggleUI()
            local isVisible = not mainFrame.Visible
            mainFrame.Visible = isVisible
            modalToggle.Modal = isVisible
            UIS.MouseIconEnabled = isVisible
            UIS.MouseBehavior = isVisible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
        end

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
        table.insert(state.connections, inputConn)

        local function setWarningText(txt)
            if not warningLabel then return end
            if txt then
                warningLabel.Visible = true
                warningLabel.Text = txt
            else
                warningLabel.Visible = false
            end
        end

        function UI.teleportToNextDoor()
            local player = Players.LocalPlayer
            local char = player and player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            local targetDoor, minRoomNum = nil, 9999
            for obj, visualsEntry in pairs(state.visualObjects) do
                if visualsEntry and visualsEntry.Billboard then
                    local lbl = visualsEntry.Billboard:FindFirstChildWhichIsA("Frame") and visualsEntry.Billboard:FindFirstChildWhichIsA("Frame"):FindFirstChildOfClass("TextLabel")
                    if lbl and string.find(lbl.Text, "Door") then
                        local num = tonumber(string.match(lbl.Text, "%[(%d+)%]"))
                        if num and num < minRoomNum then minRoomNum = num; targetDoor = obj end
                    end
                end
            end

            if targetDoor then
                local posPart = (targetDoor:IsA("Model") and (targetDoor.PrimaryPart and targetDoor.PrimaryPart.Position or (targetDoor:FindFirstChildWhichIsA("BasePart") and targetDoor:FindFirstChildWhichIsA("BasePart").Position))) or (targetDoor.Position)
                if posPart then
                    root.CFrame = CFrame.new(posPart + Vector3.new(0,3,0))
                    print("🚀 Đã dịch chuyển tới Cửa phòng: " .. minRoomNum)
                end
            else
                print("❌ Không tìm thấy cửa nào để dịch chuyển.")
            end
        end

        safe.StartHeartbeat(setWarningText)

        return screenGui
    end

    return UI
end

return UI
