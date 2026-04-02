import json
import queue
import threading
import time
from dataclasses import dataclass
from pathlib import Path

from flask import Flask, abort, jsonify, request, send_file
import tkinter as tk
from tkinter import ttk, messagebox


HOST = "127.0.0.1"
PORT = 8765
BASE_DIR = Path(__file__).resolve().parent
KEYBIND_FILE = BASE_DIR / "keybinds.json"


@dataclass
class MenuAction:
    action_id: str
    label: str
    category: str
    roblox_event: str
    is_toggle: bool = False


ACTIONS: list[MenuAction] = [
    MenuAction("farm_toggle", "Bật/Tắt Auto Farm", "Farm", "toggle_auto_farm", True),
    MenuAction("farm_collect", "Thu thập vật phẩm", "Farm", "collect_items"),
    MenuAction("movement_speed", "Tăng tốc độ", "Movement", "boost_speed"),
    MenuAction("movement_noclip", "Bật/Tắt Noclip", "Movement", "toggle_noclip", True),
    MenuAction("visual_fullbright", "Bật/Tắt Fullbright", "Visual", "toggle_fullbright", True),
    MenuAction("utility_safe", "Safe Mode", "Utility", "enable_safe_mode", True),
]


class RobloxBridgeMenu:
    def __init__(self) -> None:
        self.app = Flask(__name__)
        self.root = tk.Tk()
        self.root.title("Roblox External Menu Bridge")
        self.root.geometry("760x500")

        self.trigger_queue: queue.Queue[str] = queue.Queue()
        self.keybind_vars: dict[str, tk.StringVar] = {}
        self.last_action_var = tk.StringVar(value="Chưa có hành động nào.")

        self.actions_by_id = {action.action_id: action for action in ACTIONS}
        self.toggle_state = {action.action_id: False for action in ACTIONS if action.is_toggle}

        self.keybinds = self._load_keybinds()

        self.changes_lock = threading.Lock()
        self.next_change_id = 1
        self.change_log: list[dict] = []

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
                    "is_toggle": action.is_toggle,
                    "keybind": self.keybinds.get(action.action_id, ""),
                }
                for action in ACTIONS
            ]
            return jsonify(payload)

        @self.app.get("/src/<path:filepath>")
        def src_file(filepath: str):
            file_path = (BASE_DIR / filepath).resolve()
            if BASE_DIR not in file_path.parents and file_path != BASE_DIR:
                abort(403)
            if file_path.suffix.lower() != ".lua" or not file_path.is_file():
                abort(404)
            return send_file(file_path, mimetype="text/plain")

        @self.app.get("/trigger")
        def trigger_from_query():
            action_id = (request.args.get("action_id") or "").strip()
            return self._queue_action_from_client(action_id, source="http:get")

        @self.app.post("/trigger")
        def trigger_from_post():
            data = request.get_json(silent=True) or {}
            action_id = (data.get("action_id") or "").strip()
            return self._queue_action_from_client(action_id, source="http:post")

        @self.app.get("/set_keybind")
        def set_keybind_from_query():
            action_id = (request.args.get("action_id") or "").strip()
            key = (request.args.get("key") or "").strip().lower()
            return self._set_keybind(action_id, key, source="http:query")

        @self.app.get("/changes")
        def get_changes():
            since = request.args.get("since", default="0")
            try:
                since_id = int(since)
            except ValueError:
                return jsonify({"status": "error", "message": "since must be integer"}), 400

            with self.changes_lock:
                updates = [entry for entry in self.change_log if entry["id"] > since_id]
                latest = self.next_change_id - 1

            return jsonify({"status": "ok", "since": since_id, "latest": latest, "changes": updates})

    def _queue_action_from_client(self, action_id: str, source: str):
        if not action_id:
            return jsonify({"status": "error", "message": "missing action_id"}), 400
        if action_id not in self.actions_by_id:
            return jsonify({"status": "error", "message": f"unknown action_id: {action_id}"}), 404

        self.trigger_queue.put((action_id, source))
        self._record_change(
            change_type="queued",
            action_id=action_id,
            payload={"source": source},
        )
        return jsonify({"status": "ok", "queued_action": action_id})

    def _set_keybind(self, action_id: str, key: str, source: str):
        if action_id not in self.actions_by_id:
            return jsonify({"status": "error", "message": "action_id không hợp lệ"}), 400

        self.keybinds[action_id] = key
        self._save_keybinds(self.keybinds)

        self._record_change(
            change_type="keybind",
            action_id=action_id,
            payload={"key": key, "source": source},
        )

        if action_id in self.keybind_vars:
            self.keybind_vars[action_id].set(key)

        return jsonify({"status": "ok", "action_id": action_id, "key": key})

    def _record_change(self, change_type: str, action_id: str, payload: dict | None = None) -> None:
        payload = payload or {}
        with self.changes_lock:
            change_id = self.next_change_id
            self.next_change_id += 1
            self.change_log.append(
                {
                    "id": change_id,
                    "type": change_type,
                    "action_id": action_id,
                    "payload": payload,
                    "ts": int(time.time()),
                }
            )

            if len(self.change_log) > 1000:
                self.change_log = self.change_log[-500:]

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
                f"API: http://{HOST}:{PORT} | Client đọc thay đổi bằng /changes?since=<id> "
                "và cập nhật keybind bằng /set_keybind?action_id=...&key=..."
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
        result = self._set_keybind(action_id, key, source="gui")
        if isinstance(result, tuple):
            self.last_action_var.set("Không lưu được keybind.")
            return
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
        action = self.actions_by_id.get(action_id)
        if action is None:
            return

        state = None
        if action.is_toggle:
            state = not self.toggle_state[action_id]
            self.toggle_state[action_id] = state

        self._record_change(
            change_type="action",
            action_id=action_id,
            payload={"source": source, "active": state, "event": action.roblox_event},
        )

        state_msg = ""
        if state is not None:
            state_msg = f" (active={state})"

        self.last_action_var.set(
            f"Đã kích hoạt '{action.label}' từ {source}. Roblox event='{action.roblox_event}'{state_msg}."
        )

    def _process_queue(self) -> None:
        while True:
            try:
                action_id, source = self.trigger_queue.get_nowait()
            except queue.Empty:
                break
            self._execute_action(action_id, source=source)

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
        KEYBIND_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

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
