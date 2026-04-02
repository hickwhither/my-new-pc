import json
import queue
import threading
from dataclasses import dataclass
from pathlib import Path
from flask import Flask, jsonify, request
import tkinter as tk
from tkinter import ttk, messagebox


HOST = "127.0.0.1"
PORT = 8765
KEYBIND_FILE = Path("keybinds.json")


@dataclass
class MenuAction:
    action_id: str
    label: str
    category: str
    roblox_event: str


ACTIONS: list[MenuAction] = [
    MenuAction("farm_toggle", "Bật/Tắt Auto Farm", "Farm", "toggle_auto_farm"),
    MenuAction("farm_collect", "Thu thập vật phẩm", "Farm", "collect_items"),
    MenuAction("movement_speed", "Tăng tốc độ", "Movement", "boost_speed"),
    MenuAction("movement_noclip", "Bật/Tắt Noclip", "Movement", "toggle_noclip"),
    MenuAction("visual_fullbright", "Bật/Tắt Fullbright", "Visual", "toggle_fullbright"),
    MenuAction("utility_safe", "Safe Mode", "Utility", "enable_safe_mode"),
]


class RobloxBridgeMenu:
    def __init__(self) -> None:
        self.app = Flask(__name__)
        self.root = tk.Tk()
        self.root.title("Roblox External Menu Bridge")
        self.root.geometry("700x460")

        self.trigger_queue: queue.Queue[str] = queue.Queue()
        self.keybind_vars: dict[str, tk.StringVar] = {}
        self.action_buttons: dict[str, ttk.Button] = {}
        self.last_action_var = tk.StringVar(value="Chưa có hành động nào.")

        self.keybinds = self._load_keybinds()
        self._setup_flask_routes()
        self._build_ui()

        self.root.bind_all("<KeyPress>", self._on_keypress)
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _setup_flask_routes(self) -> None:
        @self.app.get("/health")
        def health():
            return jsonify({"status": "ok", "message": "bridge is running"})

        @self.app.get("/manifest")
        def manifest():
            payload = [
                {
                    "id": action.action_id,
                    "label": action.label,
                    "category": action.category,
                    "roblox_event": action.roblox_event,
                    "keybind": self.keybinds.get(action.action_id, ""),
                }
                for action in ACTIONS
            ]
            return jsonify(payload)

        @self.app.post("/trigger")
        def trigger_action():
            data = request.get_json(silent=True) or {}
            action_id = data.get("action_id")

            if not action_id:
                return jsonify({"status": "error", "message": "missing action_id"}), 400

            if action_id not in {a.action_id for a in ACTIONS}:
                return jsonify({"status": "error", "message": f"unknown action_id: {action_id}"}), 404

            self.trigger_queue.put(action_id)
            return jsonify({"status": "ok", "queued_action": action_id})

        @self.app.get("/keybinds")
        def get_keybinds():
            return jsonify(self.keybinds)

        @self.app.post("/keybinds")
        def save_keybind():
            data = request.get_json(silent=True) or {}
            action_id = data.get("action_id")
            key = (data.get("key") or "").strip().lower()

            if action_id not in {a.action_id for a in ACTIONS}:
                return jsonify({"status": "error", "message": "action_id không hợp lệ"}), 400

            self.keybinds[action_id] = key
            self._save_keybinds(self.keybinds)
            return jsonify({"status": "ok", "action_id": action_id, "key": key})

    def _build_ui(self) -> None:
        wrapper = ttk.Frame(self.root, padding=12)
        wrapper.pack(fill="both", expand=True)

        header = ttk.Label(
            wrapper,
            text="External GUI cho Roblox Client (Flask + Tkinter)",
            font=("Segoe UI", 14, "bold"),
        )
        header.pack(anchor="w", pady=(0, 10))

        hint = ttk.Label(
            wrapper,
            text=(
                f"Flask API đang chạy tại http://{HOST}:{PORT}. "
                "Mỗi nút có ô bên cạnh để gán keybind."
            ),
        )
        hint.pack(anchor="w", pady=(0, 8))

        notebook = ttk.Notebook(wrapper)
        notebook.pack(fill="both", expand=True)

        grouped: dict[str, list[MenuAction]] = {}
        for action in ACTIONS:
            grouped.setdefault(action.category, []).append(action)

        for category, actions in grouped.items():
            frame = ttk.Frame(notebook, padding=10)
            notebook.add(frame, text=category)
            self._build_action_rows(frame, actions)

        footer = ttk.Label(wrapper, textvariable=self.last_action_var, foreground="#0b5cad")
        footer.pack(anchor="w", pady=(10, 0))

    def _build_action_rows(self, parent: ttk.Frame, actions: list[MenuAction]) -> None:
        for row, action in enumerate(actions):
            action_button = ttk.Button(
                parent,
                text=action.label,
                command=lambda action_id=action.action_id: self._execute_action(action_id, source="gui"),
                width=30,
            )
            action_button.grid(row=row, column=0, padx=(0, 8), pady=5, sticky="w")
            self.action_buttons[action.action_id] = action_button

            keybind_var = tk.StringVar(value=self.keybinds.get(action.action_id, ""))
            self.keybind_vars[action.action_id] = keybind_var

            key_entry = ttk.Entry(parent, width=14, textvariable=keybind_var)
            key_entry.grid(row=row, column=1, padx=(0, 8), pady=5, sticky="w")

            save_btn = ttk.Button(
                parent,
                text="Lưu keybind",
                command=lambda action_id=action.action_id: self._save_single_keybind(action_id),
            )
            save_btn.grid(row=row, column=2, pady=5, sticky="w")

            info = ttk.Label(parent, text=f"Event: {action.roblox_event}", foreground="#666")
            info.grid(row=row, column=3, padx=(10, 0), pady=5, sticky="w")

    def _save_single_keybind(self, action_id: str) -> None:
        key = self.keybind_vars[action_id].get().strip().lower()
        self.keybinds[action_id] = key
        self._save_keybinds(self.keybinds)
        self.last_action_var.set(f"Đã lưu keybind [{key or 'none'}] cho {action_id}.")

    def _on_keypress(self, event: tk.Event) -> None:
        key = (event.keysym or "").lower().strip()
        if not key:
            return

        for action_id, bind_key in self.keybinds.items():
            if bind_key and bind_key == key:
                self._execute_action(action_id, source=f"keybind:{key}")
                break

    def _execute_action(self, action_id: str, source: str) -> None:
        action = next((a for a in ACTIONS if a.action_id == action_id), None)
        if action is None:
            return

        self.last_action_var.set(
            f"Đã kích hoạt '{action.label}' từ {source}. Roblox event='{action.roblox_event}'."
        )

    def _process_queue(self) -> None:
        while True:
            try:
                action_id = self.trigger_queue.get_nowait()
            except queue.Empty:
                break
            self._execute_action(action_id, source="flask")

        self.root.after(100, self._process_queue)

    def _run_flask(self) -> None:
        self.app.run(host=HOST, port=PORT, debug=False, use_reloader=False)

    def _load_keybinds(self) -> dict[str, str]:
        if not KEYBIND_FILE.exists():
            return {}

        try:
            data = json.loads(KEYBIND_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return {k: str(v).lower() for k, v in data.items()}
        except (json.JSONDecodeError, OSError):
            pass

        return {}

    def _save_keybinds(self, data: dict[str, str]) -> None:
        KEYBIND_FILE.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _on_close(self) -> None:
        if messagebox.askokcancel("Thoát", "Bạn có chắc muốn đóng menu?"):
            self.root.destroy()

    def start(self) -> None:
        flask_thread = threading.Thread(target=self._run_flask, daemon=True)
        flask_thread.start()
        self._process_queue()
        self.root.mainloop()


if __name__ == "__main__":
    RobloxBridgeMenu().start()
