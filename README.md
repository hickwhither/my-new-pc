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

### API để Roblox client kết nối

- `GET /health`: kiểm tra bridge đang chạy.
- `GET /manifest`: lấy danh sách nút + category + event.
- `POST /trigger`: gửi `{ "action_id": "farm_toggle" }` để kích hoạt từ Roblox.
- `GET /keybinds`: lấy keybind hiện tại.
- `POST /keybinds`: lưu keybind, ví dụ `{ "action_id": "farm_toggle", "key": "f6" }`.

Ví dụ Lua (Roblox `HttpService`) gọi bridge local:

```lua
local HttpService = game:GetService("HttpService")
local base = "http://127.0.0.1:8765"

local manifest = HttpService:JSONDecode(game:HttpGet(base .. "/manifest"))
print("Loaded actions:", #manifest)

local payload = HttpService:JSONEncode({ action_id = "farm_toggle" })
request({
    Url = base .. "/trigger",
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = payload
})
```
