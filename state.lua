-- state.lua
-- Trả về bảng state dùng chung cho các module
local state = {
    running = true,
    connections = {},        -- tất cả connections chung
    visualObjects = {},      -- map object -> visuals
    itemTracers = {},        -- map object -> tracer parts
    objectConnections = {},  -- map object -> list of per-object connections
    dangerousParts = {},

    settings = {
        safeHeightEnabled = false,
        fullbrightEnabled = false,
        pandemoniumIgnore = false,
        abominationIgnore = false,
    },

    -- safe mode physics
    safeModeActive = false,
    originalCFrame = nil,
    bodyVel = nil,
    bodyGyro = nil,

    originalLighting = nil
}

return state
