-- Watcher.lua
local Watcher = _G.offlineservice("Watcher")

local Workspace = _G.services.Workspace

-- Helper functions for kind categories
local function addToKind(obj, kind)
    if not _G.state.objectsByKind[kind] then
        _G.state.objectsByKind[kind] = {}
    end
    table.insert(_G.state.objectsByKind[kind], obj)
    _G.state.objectKinds[obj] = kind
end

local function removeFromKind(obj)
    local kind = _G.state.objectKinds[obj]
    if kind then
        local list = _G.state.objectsByKind[kind]
        if list then
            for i, o in ipairs(list) do
                if o == obj then
                    table.remove(list, i)
                    break
                end
            end
        end
        _G.state.objectKinds[obj] = nil
    end
end

local function processWorkspaceObject(obj)
    if not obj:IsDescendantOf(Workspace) then return end
    if not _G.state.running or not obj then return end
    if _G.state.visualObjects[obj] then return end
    if obj:IsA("Attachment") then return end
    if obj:IsA("Beam") then return end

    local objName = obj.Name or "Unknown"
    local lowerName = string.lower(objName)

    for dangerousName, _ in pairs(_G.config.DANGEROUS_ENTITY_NAMES) do
        if string.find(lowerName, string.lower(dangerousName), 1, true) then
            _G.state.dangerousParts[obj] = true
            _G.Visuals.addVisuals(obj, "Enemy", objName)
            addToKind(obj, "Enemy")
            return
        end
    end
end

local function processRoomObject(obj)
    if not _G.state.running or not obj then return end
    if _G.state.visualObjects[obj] then return end
    if obj:IsA("Attachment") then return end
    if obj:IsA("Beam") then return end

    local objName = obj.Name or "Unknown"
    local lowerName = string.lower(objName)

    if objName == "Locker" then
        _G.Visuals.addVisuals(obj, "Item", "Locker")
        addToKind(obj, "Item")
        return
    end

    if objName == "Generator" then
        _G.Visuals.addVisuals(obj, "Item", "Generator")
        addToKind(obj, "Item")
        return
    end

    if objName == "PasswordPaper" then
        local codePart = obj:WaitForChild("Code")
        local codeText = "????"
        if codePart and codePart:WaitForChild("SurfaceGui") and codePart.SurfaceGui:WaitForChild("TextLabel") then
            codeText = codePart.SurfaceGui.TextLabel.Text
        end
        _G.Visuals.addTracer(obj, Color3.fromRGB(255,100,255))
        _G.Visuals.addVisuals(obj, "Item", "Pass: " .. codeText)
        addToKind(obj, "Item")
        -- Auto remove logic
        local proxy = obj:FindFirstChild("ProxyPart", true)
        if proxy then
            local prompt = proxy:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                local function kill()
                    removeFromKind(obj)
                    if _G.state.visualObjects[obj] then
                        _G.Visuals.removeVisual(obj)
                    end
                end
                _G.Utils.storeObjectConnection(obj, proxy.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end))
                _G.Utils.storeObjectConnection(obj, prompt.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end))
                _G.Utils.storeObjectConnection(obj, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not prompt.Enabled then kill() end
                end))
            end
        end
        return
    end

    if string.find(objName, "KeyCard") then
        if obj:FindFirstChild("ProxyPart") then
            task.spawn(function() _G.Visuals.addTracer(obj, Color3.fromRGB(0,255,255)) end)
            _G.Visuals.addVisuals(obj, "Item", objName)
            addToKind(obj, "Item")
            -- Auto remove logic
            local proxy = obj:FindFirstChild("ProxyPart", true)
            if proxy then
                local prompt = proxy:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    local function kill()
                        removeFromKind(obj)
                        if _G.state.visualObjects[obj] then
                            _G.Visuals.removeVisual(obj)
                        end
                    end
                    _G.Utils.storeObjectConnection(obj, proxy.AncestryChanged:Connect(function(_, parent)
                        if not parent then kill() end
                    end))
                    _G.Utils.storeObjectConnection(obj, prompt.AncestryChanged:Connect(function(_, parent)
                        if not parent then kill() end
                    end))
                    _G.Utils.storeObjectConnection(obj, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if not prompt.Enabled then kill() end
                    end))
                end
            end
            return
        end
    end

    if objName == "ProxyPart" then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt and prompt.Enabled then
            local target = (obj.Parent and obj.Parent:IsA("Model")) and obj.Parent or obj
            if not string.find(target.Name, "KeyCard") then
                _G.Visuals.addVisuals(target, "Item", target.Name)
                addToKind(target, "Item")
                -- Auto remove logic
                local function kill()
                    removeFromKind(target)
                    if _G.state.visualObjects[target] then
                        _G.Visuals.removeVisual(target)
                    end
                end
                _G.Utils.storeObjectConnection(target, obj.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end))
                _G.Utils.storeObjectConnection(target, prompt.AncestryChanged:Connect(function(_, parent)
                    if not parent then kill() end
                end))
                _G.Utils.storeObjectConnection(target, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                    if not prompt.Enabled then kill() end
                end))
                return
            end
        end
    end
end

local function processMonsterObject(obj)
    if not _G.state.running or not obj then return end
    if _G.state.visualObjects[obj] then return end
    if obj:IsA("Model") then
        _G.Visuals.addVisuals(obj, "UnknownMonster")
        addToKind(obj, "UnknownMonster")
    end
end

local function watchWorkspace()
    for _, child in ipairs(Workspace:GetChildren()) do
        pcall(function() processWorkspaceObject(child, nil) end)
    end

    local descAdded = Workspace.ChildAdded:Connect(function(c)
        if not _G.state.running then return end
        pcall(function() processWorkspaceObject(c, nil) end)
    end)
    table.insert(_G.state.connections, descAdded)

    local descRemoving = Workspace.ChildRemoved:Connect(function(c)
    local parent = c.Parent
    if _G.state.visualObjects[c] then
        removeFromKind(c)
        _G.Visuals.removeVisual(c)
        return
    end
    if parent and _G.state.visualObjects[parent] then
        removeFromKind(parent)
        _G.Visuals.removeVisual(parent)
    end
end)

    table.insert(_G.state.connections, descRemoving)
end

Watcher.latestDoor = nil

local function registerRoom(room)
    for _, obj in ipairs(room:GetDescendants()) do
        pcall(function() processRoomObject(obj) end)
    end

    local entrances = room:WaitForChild("Entrances", 10)
    if not entrances then
        warn("No Entrances in room:", room)
        return
    end

    for _, door in ipairs(entrances:GetChildren()) do
        if door:IsA("Model") or door:IsA("BasePart") then
            _G.Visuals.addVisuals(door, "Item", "Door")
            addToKind(door, "Item")
            if Watcher.latestDoor then
                removeFromKind(Watcher.latestDoor)
                _G.Visuals.removeVisual(Watcher.latestDoor)
            end
            Watcher.latestDoor = door
        end
    end

    local doorConn = entrances.ChildAdded:Connect(function(door)
        task.wait(0.1)
        if door:IsA("Model") or door:IsA("BasePart") then
            _G.Visuals.addVisuals(door, "Item", "Door")
            addToKind(door, "Item")
            if Watcher.latestDoor then
                removeFromKind(Watcher.latestDoor)
                _G.Visuals.removeVisual(Watcher.latestDoor)
            end
            Watcher.latestDoor = door
        end

    end)
    _G.Utils.storeObjectConnection(room, doorConn)


    local connAdd = room.DescendantAdded:Connect(function(obj)
        task.wait(0.05)
        pcall(function() processRoomObject(obj) end)
    end)
    _G.Utils.storeObjectConnection(room, connAdd)

    local connRem = room.DescendantRemoving:Connect(function(obj)
        removeFromKind(obj)
        if _G.state.visualObjects[obj] then _G.Visuals.removeVisual(obj) end
    end)
    _G.Utils.storeObjectConnection(room, connRem)
end

local function watchRooms(roomsFolder)

    for _, room in ipairs(roomsFolder:GetChildren()) do
        task.spawn(function() registerRoom(room) end)
    end

    local roomsAdded = roomsFolder.ChildAdded:Connect(function(r)
        task.spawn(function() registerRoom(r) end)
    end)
    table.insert(_G.state.connections, roomsAdded)
end

local function watchMonsters(monstersFolder)

    for _, monster in ipairs(monstersFolder:GetChildren()) do
        pcall(function() processMonsterObject(monster) end)
    end

    local monstersAdded = monstersFolder.ChildAdded:Connect(function(m)
        pcall(function() processMonsterObject(m) end)
    end)
    table.insert(_G.state.connections, monstersAdded)
end

watchWorkspace()
local gameplay = Workspace:FindFirstChild("GameplayFolder")
local rooms = gameplay and gameplay:FindFirstChild("Rooms")
local monsters = gameplay and gameplay:FindFirstChild("Monsters")

if rooms then
    watchRooms(rooms)
else
    task.spawn(function()
        while _G.state.running do
            gameplay = Workspace:FindFirstChild("GameplayFolder")
            rooms = gameplay and gameplay:FindFirstChild("Rooms")
            if rooms then watchRooms(rooms); break end
            task.wait(1)
        end
    end)
end

if monsters then
    watchMonsters(monsters)
else
    task.spawn(function()
        while _G.state.running do
            gameplay = Workspace:FindFirstChild("GameplayFolder")
            monsters = gameplay and gameplay:FindFirstChild("Monsters")
            if monsters then watchMonsters(monsters); break end
            task.wait(1)
        end
    end)
end
