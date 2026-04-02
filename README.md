i mean pressure cheat

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hickwhither/my-new-pc/refs/heads/master/main_loader.lua"))()
```

Set fly speed
```
_G.FLY_SPEED = ...
```

## Flask + Tkinter external GUI bridge

Chạy menu ngoài game:

```bash
python3 roblox_bridge_menu.py
```

Menu có phân loại theo tab (`Farm`, `Movement`, `Visual`, `Utility`) và mỗi nút có ô keybind để tự kích hoạt bằng bàn phím.

### API cho Roblox client (đọc/ghi bằng query params)

- `GET /manifest`: lấy danh sách action + category + event + keybind hiện tại.
- `GET /src/<file.lua>`: lấy file Lua trực tiếp (phù hợp pattern trong `main_loader.lua`).
- `GET /trigger?action_id=farm_toggle`: queue action từ client.
- `GET /set_keybind?action_id=farm_toggle&key=f6`: cập nhật keybind (không cần POST).
- `GET /changes?since=0`: chỉ lấy **delta thay đổi** từ lần đọc trước.

Ví dụ flow client:

1. Gọi `/manifest` khi khởi động để biết action nào tồn tại.
2. Lưu `last_change_id` (ban đầu `0`).
3. Poll `/changes?since=<last_change_id>` để nhận các thay đổi mới (nhấn nút, toggle state, keybind đổi).
4. Sau mỗi lần nhận response, cập nhật `last_change_id = latest`.

Ví dụ Lua dùng query params:

```lua
local HttpService = game:GetService("HttpService")
local base = "http://127.0.0.1:8765"

local manifest = HttpService:JSONDecode(game:HttpGet(base .. "/manifest"))
print("Loaded actions:", #manifest)

-- trigger action
local encodedAction = HttpService:UrlEncode("farm_toggle")
local triggerRes = game:HttpGet(base .. "/trigger?action_id=" .. encodedAction)
print(triggerRes)

-- update keybind bằng query params
local encodedKey = HttpService:UrlEncode("f6")
local keybindRes = game:HttpGet(base .. "/set_keybind?action_id=" .. encodedAction .. "&key=" .. encodedKey)
print(keybindRes)

-- lấy delta thay đổi
local changes = HttpService:JSONDecode(game:HttpGet(base .. "/changes?since=0"))
print("Latest:", changes.latest, "Count:", #changes.changes)
```
