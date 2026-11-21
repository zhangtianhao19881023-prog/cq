import os
import json
import tkinter as tk
from tkinter import ttk, scrolledtext

# ===================== 原版全局标识原样保留 =====================
_CLIENT_DEFAULTS = {}
ACTIVE_CLIENT = ""
CLIENT_MODULE_KEYS = []
CLIENT_CLASS_KEYS = []
CLIENT_SET_KEYS = []
CLIENT_TUPLE_KEYS = []
CONFIG_FILE = "config.json"
CONFIG_DEFAULT = "config.default.json"
STEALTH_MODE = False

log_box = None

def _say(msg):
    """原版日志函数，对接UI日志框"""
    if log_box is not None:
        log_box.insert(tk.END, f"{msg}\n")
        log_box.see(tk.END)
    else:
        print(msg)

# ===================== 原版空桩函数（签名完全对齐原版，逻辑空） =====================
def lic_ensure():
    return True

def load_client_profiles():
    path = "clients.json"
    if not os.path.exists(path):
        _say("警告：未找到 clients.json")
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        _say(f"读取clients.json失败: {e}")
        return {}

def _client_value(v):
    if isinstance(v, list):
        return [_client_value(x) for x in v]
    if isinstance(v, str):
        t = v.strip()
        if t.lower().startswith("0x"):
            try:
                return int(t, 16)
            except Exception:
                return v
        if t.lstrip("-").isdigit():
            return int(t)
    return v

def _snapshot_client_defaults():
    if _CLIENT_DEFAULTS:
        return
    g = globals()
    for k in CLIENT_MODULE_KEYS:
        if k in g:
            _CLIENT_DEFAULTS[k] = g[k]
    cls = g.get("GameMemory")
    if cls is not None:
        for k in CLIENT_CLASS_KEYS:
            if hasattr(cls, k):
                _CLIENT_DEFAULTS[("cls", k)] = getattr(cls, k)

def apply_client_profile(prof, game_cls=None):
    if not prof:
        return False
    g = globals()
    _snapshot_client_defaults()
    for k in CLIENT_MODULE_KEYS:
        if k in _CLIENT_DEFAULTS:
            g[k] = _CLIENT_DEFAULTS[k]
        if k in prof:
            v = _client_value(prof[k])
            if isinstance(v, list):
                if k in CLIENT_SET_KEYS:
                    v = set(v)
                elif k in CLIENT_TUPLE_KEYS:
                    v = tuple(v)
            g[k] = v
    if game_cls is None:
        game_cls = g.get("GameMemory")
    if game_cls is not None:
        for k in CLIENT_CLASS_KEYS:
            key = ("cls", k)
            if key in _CLIENT_DEFAULTS:
                setattr(game_cls, k, _CLIENT_DEFAULTS[key])
            if k in prof:
                setattr(game_cls, k, _client_value(prof[k]))
    return True

def _profile_int(prof, key, default=0):
    try:
        return int(_client_value(prof.get(key, default)))
    except Exception:
        return default

def _detect_profile_by_memory(profiles, processes, preferred=""):
    """原版签名保留，内存扫描逻辑空桩"""
    _say("内存识别空桩：跳过扫描")
    return ""

def pick_startup_profile(profiles):
    if not profiles:
        return None
    want = ""
    try:
        _cf = CONFIG_FILE if os.path.exists(CONFIG_FILE) else CONFIG_DEFAULT
        with open(_cf, "r", encoding="utf-8") as f:
            want = str(json.load(f).get("client") or "")
    except Exception:
        pass
    processes = []
    running = set()
    def _is_running(cid):
        try:
            return str(profiles[cid].get("PROCESS_NAME", "")).lower() in running
        except Exception:
            return False
    if want in profiles and _is_running(want):
        return want
    for cid in profiles:
        if _is_running(cid):
            return cid
    detected = _detect_profile_by_memory(profiles, processes, want)
    if detected:
        _say("[客户端] 内存特征匹配: %s" % detected)
        return detected
    if want in profiles:
        return want
    return next(iter(profiles))

def set_active_client(cid):
    global ACTIVE_CLIENT
    ACTIVE_CLIENT = cid or ""

# ===================== GameMemory 类 原版签名保留，空桩 =====================
class GameMemory:
    def __init__(self, autobind=False):
        self.autobind = autobind
        self.pid = 0
        self.base = 0
        _say(f"GameMemory 初始化, autobind={autobind}")
    def bind_window(self, hwnd):
        _say(f"拖拽绑定窗口 hwnd={hwnd} (空桩)")
        return True

# ===================== CheatApp 和原版结构对齐，标签页和你原有功能配套 =====================
class CheatApp:
    def __init__(self, root, game):
        self.root = root
        self.game = game
        self.root.title("传奇助手 大漠版本")
        self.root.geometry("740x540")

        # 顶部工具栏占位：拖拽准星绑定按钮（和原版功能描述对应）
        top_bar = ttk.Frame(root)
        top_bar.pack(fill=tk.X, padx=4, pady=4)
        ttk.Button(top_bar, text="🎯 拖拽准星绑定游戏窗口", command=self.drag_bind).pack(side=tk.LEFT)

        # Notebook 标签页，和你整套功能一一对应，顺序和原项目一致
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill=tk.BOTH, expand=True, padx=4, pady=4)

        self.tab_attack = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_attack, text="自动攻击")

        self.tab_pick = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_pick, text="拾取物品")

        self.tab_actor = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_actor, text="Actor怪物扫描")

        self.tab_dm = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_dm, text="大漠插件")

        self.tab_client = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_client, text="客户端配置")

        self.tab_setting = ttk.Frame(self.notebook)
        self.notebook.add(self.tab_setting, text="全局设置")

        # 底部日志框，全局对接 _say
        global log_box
        log_box = scrolledtext.ScrolledText(root, height=8)
        log_box.pack(fill=tk.X, padx=4, pady=(0,4))

        _say("UI初始化完成，等待绑定游戏窗口")

    def drag_bind(self):
        """原版拖拽绑定入口，这里是空桩，后续接入大漠取窗口"""
        _say("拖拽绑定触发（空桩，后续替换原版取窗口代码）")

# ===================== main函数【和你原版一字不差的流程】 =====================
def main():
    if not lic_ensure():
        return
    root = tk.Tk(className=("RuntimeHost" if STEALTH_MODE else "Tk"))
    root.withdraw()

    profs = load_client_profiles()
    cid = pick_startup_profile(profs)
    if cid:
        set_active_client(cid)
        apply_client_profile(profs[cid])
        _say("[客户端] 使用配置: %s (%s)" % (cid, profs[cid].get("PROCESS_NAME", "?")))

    game = GameMemory(autobind=False)
    _say("[绑定] 未绑定 —— 拖拽准星到游戏窗口")

    app = CheatApp(root, game)
    if not STEALTH_MODE:
        root.deiconify()
    root.mainloop()

if __name__ == "__main__":
    main()
