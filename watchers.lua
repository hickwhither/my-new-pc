-- watchers.lua
local Watchers = {}

function Watchers.Init(services, state, config, utils, visuals, safe, ui)
    local Workspace = services.Workspace

    local function processObject(obj, roomNumber)
        if not obj:IsDescendantOf(Workspace) then return end
        if not state.running or not obj then return end
        if state.visualObjects[obj] then return end
        if obj:IsA("Attachment") then return end
        if obj:IsA("Beam") then return end

        local objName = obj.Name or "Unknown"
        local roomSuffix = roomNumber and (" [P." .. roomNumber .. "]") or ""

        if objName == "Pandemonium" and state.pandemoniumIgnore then
            obj:Destroy()
            return
        end
        if objName == "Abomination" and state.abominationIgnore then
            obj:Destroy()
            return
        end

        local breakTarget
        if config.DANGEROUS_ENTITY_NAMES[objName] then
            state.dangerousParts[obj] = true
            visuals.addVisuals(obj, "Enemy", objName)
            breakTarget = obj
        end

        if objName == "Locker" then
            visuals.addVisuals(obj, "Item", "Locker")
            breakTarget = obj
        end

        if objName == "Generator" then
            visuals.addVisuals(obj, "Item", "Generator" .. roomSuffix)
            breakTarget = obj
        end

        if objName == "PasswordPaper" then
            local codePart = obj:WaitForChild("Code")
            local codeText = "????"
            if codePart and codePart:WaitForChild("SurfaceGui") and codePart.SurfaceGui:WaitForChild("TextLabel") then
                codeText = codePart.SurfaceGui.TextLabel.Text
            end
            visuals.addTracer(obj, Color3.fromRGB(255,100,255))
            visuals.addVisuals(obj, "Item", "Pass: " .. codeText .. roomSuffix)
            breakTarget = obj
        end

        if string.find(objName, "KeyCard") then
            if obj:FindFirstChild("ProxyPart") then
                task.spawn(function() visuals.addTracer(obj, Color3.fromRGB(0,255,255)) end)
                visuals.addVisuals(obj, "Item", objName .. roomSuffix)
                breakTarget = obj
            end
        end

        if objName == "ProxyPart" then
            local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt and prompt.Enabled then
                local target = (obj.Parent and obj.Parent:IsA("Model")) and obj.Parent or obj
                if not string.find(target.Name, "KeyCard") then
                    visuals.addVisuals(target, "Item", target.Name)
                    breakTarget = target
                end
            end
        end

        if breakTarget then

            local proxy = obj:FindFirstChild("ProxyPart", true)
            if not proxy then return end

            local prompt = proxy:FindFirstChildWhichIsA("ProximityPrompt", true)
            if not prompt then return end

            if not prompt.Enabled then return end

            visuals.addVisuals(obj, "Item", objName .. roomSuffix)

            --------------------------------------------------
            -- AUTO REMOVE LOGIC
            --------------------------------------------------

            local function kill()
                if state.visualObjects[obj] then
                    visuals.removeVisual(obj)
                end
            end

            -- Proxy bị destroy / move
            utils.storeObjectConnection(obj,
                proxy.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end)
            )

            -- Prompt bị destroy
            utils.storeObjectConnection(obj,
                prompt.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end)
            )

            -- Prompt bị disable
            utils.storeObjectConnection(obj,
                prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not prompt.Enabled then
                        kill()
                    end
                end)
            )
        end

    end

    local function watchWorkspace()
        for _, child in ipairs(Workspace:GetChildren()) do
            pcall(function() processObject(child, nil) end)
        end

        local descAdded = Workspace.ChildAdded:Connect(function(c)
            if not state.running then return end
            pcall(function() processObject(c, nil) end)
        end)
        table.insert(state.connections, descAdded)

        local descRemoving = Workspace.ChildRemoved:Connect(function(c)
        local parent = c.Parent
        if state.visualObjects[c] then
            visuals.removeVisual(c)
            return
        end
        if parent and state.visualObjects[parent] then
            visuals.removeVisual(parent)
        end
    end)

        table.insert(state.connections, descRemoving)
    end

    local function watchRooms(roomsFolder)
        local function registerRoom(room)
            local roomNumber = utils.getRoomNumber(room)
            for _, obj in ipairs(room:GetDescendants()) do
                pcall(function() processObject(obj, roomNumber) end)
            end

            local entrances = room:WaitForChild("Entrances", 10)
            if not entrances then
                warn("No Entrances in room:", room)
                return
            end

            for _, door in ipairs(entrances:GetChildren()) do
                if door:IsA("Model") or door:IsA("BasePart") then
                    local numStr = roomNumber and tostring(roomNumber) or "?"
                    visuals.addVisuals(door, "Item", "Door [".. numStr .."]")
                end
            end

            local doorConn = entrances.ChildAdded:Connect(function(door)
                task.wait(0.1)
                if door:IsA("Model") or door:IsA("BasePart") then
                    local numStr = roomNumber and tostring(roomNumber) or "?"
                    visuals.addVisuals(door, "Item", "Door [".. numStr .."]")
                end

            end)
            utils.storeObjectConnection(room, doorConn)


            local connAdd = room.DescendantAdded:Connect(function(obj)
                task.wait(0.05)
                pcall(function() processObject(obj, roomNumber) end)
            end)
            utils.storeObjectConnection(room, connAdd)

            local connRem = room.DescendantRemoving:Connect(function(obj)
                if state.visualObjects[obj] then visuals.removeVisual(obj) end
            end)
            utils.storeObjectConnection(room, connRem)
        end

        for _, room in ipairs(roomsFolder:GetChildren()) do
            task.spawn(function() registerRoom(room) end)
        end

        local roomsAdded = roomsFolder.ChildAdded:Connect(function(r)
            task.spawn(function() registerRoom(r) end)
        end)
        table.insert(state.connections, roomsAdded)
    end

    function Watchers.Start()
        watchWorkspace()
        local gameplay = Workspace:FindFirstChild("GameplayFolder")
        local rooms = gameplay and gameplay:FindFirstChild("Rooms")

        if rooms then
            watchRooms(rooms)
        else
            task.spawn(function()
                while state.running do
                    gameplay = Workspace:FindFirstChild("GameplayFolder")
                    rooms = gameplay and gameplay:FindFirstChild("Rooms")
                    if rooms then watchRooms(rooms); break end
                    task.wait(1)
                end
            end)
        end
    end

    return Watchers
end

return Watchers
