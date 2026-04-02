i mean pressure cheat

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hickwhither/my-new-pc/refs/heads/master/main_loader.lua"))()
```

Set fly speed
```
_G.FLY_SPEED = ...
```

## Flask + Tkinter external GUI bridge

Client có thể load **1 lần duy nhất** từ server local (không cần `HttpService`):

```lua
loadstring(game:HttpGet("http://127.0.0.1:8765/client.lua"))()
```

Script `/client.lua` sẽ tự tải các module cần thiết qua `GET /src/<file.lua>`.

Chạy menu ngoài game:

```bash
python3 roblox_bridge_menu.py
```

Menu có phân loại theo tab (`Farm`, `Movement`, `Visual`, `Utility`) và mỗi nút có ô keybind để tự kích hoạt bằng bàn phím.

### API chính

- `GET /client.lua`: trả về script bootstrap để client `loadstring` 1 lần.
- `GET /src/<file.lua>`: trả về từng module Lua.
- `GET /trigger?action_id=...`: client/executor kích hoạt action.
- `GET /set_keybind?action_id=...&key=...`: cập nhật keybind qua query params.
- `GET /changes?since=<id>`: lấy delta thay đổi mới nếu tool/executor của bạn hỗ trợ đọc JSON.
