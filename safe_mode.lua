-- safe_mode.lua
local Safe = {}

function Safe.Init(services, state, config, utils)
    local RunService = services.RunService
    local Player = services.Players.LocalPlayer

    function Safe.toggleSafeMode(enable)
        local char = Player and Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not root or not hum then return end

        if enable then
            if not state.safeModeActive then
                state.originalCFrame = root.CFrame
                state.safeModeActive = true
                hum.PlatformStand = true
                state.bodyVel = Instance.new("BodyVelocity")
                state.bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                state.bodyVel.Velocity = Vector3.zero
                state.bodyVel.Parent = root
                state.bodyGyro = Instance.new("BodyGyro")
                state.bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
                state.bodyGyro.CFrame = root.CFrame
                state.bodyGyro.Parent = root
                root.CFrame = CFrame.new(root.Position.X, 200, root.Position.Z)
            end
        else
            if state.safeModeActive then
                state.safeModeActive = false
                hum.PlatformStand = false
                if state.bodyVel then state.bodyVel:Destroy(); state.bodyVel = nil end
                if state.bodyGyro then state.bodyGyro:Destroy(); state.bodyGyro = nil end
                if state.originalCFrame then
                    root.CFrame = state.originalCFrame + Vector3.new(0, 3, 0)
                    state.originalCFrame = nil
                end
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    -- Heartbeat monitor (caller can call StartHeartbeat and provide a setWarningLabel function)
    local heartbeatConn
    function Safe.StartHeartbeat(setWarningLabel)
        if heartbeatConn then return end
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if not state.running then return end
            local dangerList = {}
            for part, active in pairs(state.dangerousParts) do
                if active and part and part.Parent then table.insert(dangerList, part.Name) end
            end
            if setWarningLabel then
                setWarningLabel((#dangerList>0) and ("⚠️ NGUY HIỂM: " .. table.concat(dangerList,", ") .. " ⚠️") or nil)
            end
            if state.settings.safeHeightEnabled and #dangerList > 0 then
                Safe.toggleSafeMode(true)
            else
                Safe.toggleSafeMode(false)
            end
        end)
        table.insert(state.connections, heartbeatConn)
    end

    return Safe
end

return Safe
