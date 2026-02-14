-- utils.lua
local Utils = {}

function Utils.Init(services, state, config)
    local Workspace = services.Workspace
    local Players = services.Players

    function Utils.safeDisconnectList(list)
        if not list then return end
        for _, c in ipairs(list) do
            pcall(function() if c and c.Disconnect then c:Disconnect() end end)
        end
    end

    function Utils.storeObjectConnection(obj, conn)
        if not obj then return end
        state.objectConnections[obj] = state.objectConnections[obj] or {}
        table.insert(state.objectConnections[obj], conn)
        table.insert(state.connections, conn)
    end

    function Utils.clearObjectConnections(obj)
        if not obj then return end
        local tbl = state.objectConnections[obj]
        if tbl then
            for _, c in ipairs(tbl) do
                pcall(function() c:Disconnect() end)
            end
            state.objectConnections[obj] = nil
        end
    end

    -- teleport tới một object đã biết (model hoặc part).
    -- Nếu là model và có ProxyPart thì ưu tiên teleport tới ProxyPart.
    -- Nếu ProxyPart đã bị xóa, hàm trả về false + message và (tuỳ cấu hình) remove visual.
    function Utils.teleportToTarget(targetObj)
        local player = Players.LocalPlayer
        local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return false end

        if targetObj:IsA("Model") then
            local proxy = targetObj:FindFirstChild("ProxyPart", true)
            if proxy and proxy:IsA("BasePart") then
                root.CFrame = CFrame.new(proxy.Position + Vector3.new(0,3,0))
                return true
            end

            local part =
                targetObj.PrimaryPart
                or targetObj:FindFirstChildWhichIsA("BasePart", true)

            if part then
                root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                return true
            end
        end

        if targetObj:IsA("BasePart") then
            root.CFrame = CFrame.new(targetObj.Position + Vector3.new(0,3,0))
            return true
        end

        return false
    end


    -- Tìm object gần nhất theo pattern. Ưu tiên các object có ProxyPart.
    function Utils.teleportToNearestByPattern(pattern)
        local player = Players.LocalPlayer
        local char = player and player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false, "No HumanoidRootPart" end

        local withProxy = {}
        local withoutProxy = {}

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj and obj.Name and string.find(obj.Name, pattern) then
                if obj:IsA("Model") then
                    if obj:FindFirstChild("ProxyPart") then
                        table.insert(withProxy, obj)
                    else
                        table.insert(withoutProxy, obj)
                    end
                else
                    -- BasePart (treat as withoutProxy)
                    table.insert(withoutProxy, obj)
                end
            end
        end

        local function chooseNearest(list)
            local best, bestD = nil, math.huge
            for _, obj in ipairs(list) do
                local targetPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or (obj:IsA("BasePart") and obj)
                if targetPart and targetPart.Position then
                    local d = (root.Position - targetPart.Position).Magnitude
                    if d < bestD then bestD, best = d, obj end
                end
            end
            return best
        end

        local chosen = chooseNearest(withProxy) or chooseNearest(withoutProxy)
        if not chosen then return false, "No matching object found" end

        -- nếu chosen là model với ProxyPart, teleport tới ProxyPart; nếu model ko có ProxyPart thì fallback tới PrimaryPart
        if chosen:IsA("Model") then
            local proxy = chosen:FindFirstChild("ProxyPart")
            if proxy and proxy:IsA("BasePart") then
                root.CFrame = CFrame.new(proxy.Position + Vector3.new(0,3,0))
                return true, proxy
            else
                local p = chosen.PrimaryPart or chosen:FindFirstChildWhichIsA("BasePart")
                if p then
                    root.CFrame = CFrame.new(p.Position + Vector3.new(0,3,0))
                    return true, p
                else
                    return false, "No suitable part in chosen model"
                end
            end
        else
            -- BasePart
            root.CFrame = CFrame.new(chosen.Position + Vector3.new(0,3,0))
            return true, chosen
        end
    end

    function Utils.getRoomNumber(room)
        local lights = room:WaitForChild("Lights", 10)
        if not lights then return nil end
        local minNum = 9999
        local found = false
        for _, child in ipairs(lights:GetChildren()) do
            if child.Name == "Sign" then
                local sg = child:WaitForChild("SurfaceGui")
                local tl = sg and sg:WaitForChild("TextLabel")
                if tl then
                    local num = tonumber(tl.Text)
                    if num and num < minNum then
                        minNum = num
                        found = true
                    end
                end
            end
        end
        return found and minNum-1 or nil
    end

    return Utils
end

return Utils
