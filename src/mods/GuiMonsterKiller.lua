local GuiMonsterKiller = _G.offlineservice("GuiMonsterKiller")

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer.PlayerGui

_G.UI.addEventHandler("deleteClientsidedNodeEnabled", function(enabled)
    if not enabled then return end

    -- Danh sách các từ khóa cần tìm để xóa
    local keywords = {"Lopee", "Popups"}

    -- Duyệt qua toàn bộ các con của PlayerGui
    for _, object in ipairs(PlayerGui:GetDescendants()) do
        for _, keyword in ipairs(keywords) do
            -- Kiểm tra xem tên Object có chứa từ khóa không (không phân biệt hoa thường với string.lower)
            if string.find(object.Name, keyword) then
                object:Destroy()
                print("Đã xóa UI: " .. object.Name)
                break -- Thoát vòng lặp keywords để chuyển sang object tiếp theo
            end
        end
    end
end)