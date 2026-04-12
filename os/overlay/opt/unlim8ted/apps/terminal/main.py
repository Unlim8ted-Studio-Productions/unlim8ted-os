import errno
import os
import shutil
import struct
import subprocess
import threading
import time

try:
    import fcntl
    import pty
    import select
    import signal
    import termios
    PTY_AVAILABLE = True
except ImportError:
    PTY_AVAILABLE = False


APP_ID = "terminal"
TITLE = "Terminal"
STATE_KEY = "terminal_app"
MAX_BUFFER_CHARS = 60000

_sessions = {}
_lock = threading.Lock()


def get_manifest():
    return {
        "id": APP_ID,
        "title": TITLE,
        "capabilities": ["shell", "pty"],
        "routes": ["start", "poll", "input", "resize", "stop", "clear"],
        "required_services": ["store"],
    }


class PtySession:
    def __init__(self, context):
        self.context = context
        self.cwd = _initial_cwd(context)
        self.buffer = ""
        self.offset = 0
        self.last_activity = time.time()
        self.closed = False
        self.exit_status = None
        self.master_fd = None
        self.process = None
        self._start()

    def _start(self):
        if not PTY_AVAILABLE:
            raise RuntimeError("PTY terminal is only available on Unix-like systems")
        self.master_fd, slave_fd = pty.openpty()
        flags = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
        fcntl.fcntl(self.master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        env = os.environ.copy()
        env.setdefault("TERM", "xterm-256color")
        env.setdefault("SHELL", _shell_path())
        env.setdefault("HOME", os.path.expanduser("~") or "/root")
        env.setdefault("USER", os.environ.get("USER", "root"))

        shell = _shell_path()
        shell_args = [shell, "-l"] if os.path.basename(shell) in {"bash", "zsh", "fish"} else [shell]
        self.process = subprocess.Popen(
            shell_args,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            cwd=self.cwd,
            env=env,
            preexec_fn=os.setsid,
            close_fds=True,
        )
        os.close(slave_fd)
        self.resize(24, 80)

    def read_available(self):
        if self.closed:
            return ""
        chunks = []
        while True:
            try:
                ready, _, _ = select.select([self.master_fd], [], [], 0)
                if not ready:
                    break
                data = os.read(self.master_fd, 8192)
                if not data:
                    self._mark_closed()
                    break
                chunks.append(data.decode("utf-8", errors="replace"))
            except OSError as exc:
                if exc.errno in (errno.EAGAIN, errno.EIO):
                    if self.process.poll() is not None:
                        self._mark_closed()
                    break
                raise
        if chunks:
            self.last_activity = time.time()
            self.buffer += "".join(chunks)
            if len(self.buffer) > MAX_BUFFER_CHARS:
                drop = len(self.buffer) - MAX_BUFFER_CHARS
                self.buffer = self.buffer[drop:]
                self.offset += drop
        elif self.process.poll() is not None:
            self._mark_closed()
        return "".join(chunks)

    def write(self, data):
        if self.closed:
            return False
        self.last_activity = time.time()
        os.write(self.master_fd, str(data or "").encode("utf-8", errors="ignore"))
        return True

    def resize(self, rows, cols):
        if self.closed:
            return
        rows = max(8, min(200, int(rows or 24)))
        cols = max(20, min(320, int(cols or 80)))
        packed = struct.pack("HHHH", rows, cols, 0, 0)
        fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, packed)
        try:
            os.killpg(os.getpgid(self.process.pid), signal.SIGWINCH)
        except OSError:
            pass

    def stop(self):
        if self.closed:
            return
        try:
            os.killpg(os.getpgid(self.process.pid), signal.SIGHUP)
        except OSError:
            pass
        self._mark_closed()

    def _mark_closed(self):
        if self.closed:
            return
        self.closed = True
        self.exit_status = self.process.poll()
        try:
            os.close(self.master_fd)
        except OSError:
            pass

    def snapshot(self, since=0):
        self.read_available()
        since = max(0, int(since or 0))
        start = max(since, self.offset)
        relative = start - self.offset
        return {
            "ok": True,
            "output": self.buffer[relative:],
            "offset": self.offset + len(self.buffer),
            "base_offset": self.offset,
            "closed": self.closed,
            "exit_status": self.exit_status,
            "cwd": self.cwd,
        }


def _shell_path():
    return os.environ.get("SHELL") or shutil.which("bash") or shutil.which("sh") or "/bin/sh"


def _initial_cwd(context):
    store = context["services"]["store"]
    state = store.read(STATE_KEY, {"cwd": "/root"}) or {}
    cwd = state.get("cwd") or "/root"
    return cwd if os.path.isdir(cwd) else "/"


def _session(context):
    key = context["app_id"]
    with _lock:
        session = _sessions.get(key)
        if not session or session.closed:
            session = PtySession(context)
            _sessions[key] = session
        return session


def get_app_payload(context):
    system = context["services"].get("system")
    keyboard_present = (
        system.physical_keyboard_present()
        if system and hasattr(system, "physical_keyboard_present")
        else False
    )
    return {
        "view": "template",
        "title": TITLE,
        "subtitle": "Touch shell fallback" if not keyboard_present else "Interactive local shell",
        "cwd": _initial_cwd(context),
        "terminal": {"pty": True, "keyboard_present": keyboard_present},
    }


def handle_action(context, action, payload):
    session = _session(context)
    if action == "clear":
        session.buffer = ""
        session.offset = 0
    elif action == "stop":
        session.stop()
    return {"app": get_app_payload(context), "system": context["system"]}


def handle_http(context, request):
    subpath = request.get("subpath", "")
    payload = request.get("payload", {}) or {}
    session = _session(context)

    if subpath in {"start", "poll"}:
        rows = payload.get("rows")
        cols = payload.get("cols")
        if rows and cols:
            session.resize(rows, cols)
        return {"body": session.snapshot(payload.get("offset", 0))}

    if subpath == "input":
        session.write(payload.get("data", ""))
        return {"body": session.snapshot(payload.get("offset", 0))}

    if subpath == "resize":
        session.resize(payload.get("rows", 24), payload.get("cols", 80))
        return {"body": {"ok": True}}

    if subpath == "clear":
        session.buffer = ""
        session.offset = 0
        return {"body": session.snapshot(0)}

    if subpath == "stop":
        session.stop()
        return {"body": session.snapshot(payload.get("offset", 0))}

    return {
        "status": 404,
        "body": {"ok": False, "code": "route_not_found", "message": f"Unknown terminal route: {subpath}"},
    }
