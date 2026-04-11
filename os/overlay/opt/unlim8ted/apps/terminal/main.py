import os
import subprocess


APP_ID = "terminal"
TITLE = "Terminal"
STATE_KEY = "terminal_app"
MAX_OUTPUT_CHARS = 24000
DEFAULT_STATE = {
    "cwd": "/root",
    "lines": [
        {"kind": "system", "text": "Unlim8ted terminal ready. Commands run locally on this device."}
    ],
}


def get_manifest():
    return {
        "id": APP_ID,
        "title": TITLE,
        "capabilities": ["shell"],
        "routes": ["run", "clear"],
        "required_services": ["store"],
    }


def _store(context):
    return context["services"]["store"]


def _state(context):
    state = _store(context).read(STATE_KEY, dict(DEFAULT_STATE)) or {}
    state.setdefault("cwd", DEFAULT_STATE["cwd"])
    state.setdefault("lines", list(DEFAULT_STATE["lines"]))
    if not os.path.isdir(state["cwd"]):
        state["cwd"] = "/root" if os.path.isdir("/root") else "/"
    return state


def _save(context, state):
    state["lines"] = state.get("lines", [])[-80:]
    _store(context).write(STATE_KEY, state)


def _append(state, kind, text):
    if text is None:
        text = ""
    text = str(text)
    if len(text) > MAX_OUTPUT_CHARS:
        text = text[-MAX_OUTPUT_CHARS:]
        text = "[output truncated]\n" + text
    state.setdefault("lines", []).append({"kind": kind, "text": text})


def _resolve_cwd(current, value):
    target = os.path.expanduser(str(value or "").strip() or "~")
    if not os.path.isabs(target):
        target = os.path.join(current, target)
    target = os.path.abspath(target)
    return target if os.path.isdir(target) else None


def _run_command(state, command):
    command = str(command or "").strip()
    if not command:
        return

    _append(state, "command", f"{state['cwd']} $ {command}")

    if command == "clear":
        state["lines"] = []
        return

    if command == "pwd":
        _append(state, "output", state["cwd"])
        return

    if command.startswith("cd"):
        parts = command.split(maxsplit=1)
        target = _resolve_cwd(state["cwd"], parts[1] if len(parts) > 1 else "~")
        if target:
            state["cwd"] = target
            _append(state, "output", state["cwd"])
        else:
            _append(state, "error", "cd: no such directory")
        return

    env = os.environ.copy()
    env.setdefault("TERM", "xterm-256color")
    env.setdefault("HOME", "/root")

    try:
        result = subprocess.run(
            ["/bin/sh", "-lc", command],
            cwd=state["cwd"],
            env=env,
            text=True,
            capture_output=True,
            timeout=30,
        )
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + (exc.stderr or "")
        if output:
            _append(state, "output", output)
        _append(state, "error", "command timed out after 30 seconds")
        return
    except OSError as exc:
        _append(state, "error", str(exc))
        return

    if result.stdout:
        _append(state, "output", result.stdout.rstrip("\n"))
    if result.stderr:
        _append(state, "error", result.stderr.rstrip("\n"))
    if result.returncode:
        _append(state, "status", f"exit {result.returncode}")


def get_app_payload(context):
    state = _state(context)
    return {
        "view": "template",
        "title": TITLE,
        "subtitle": f"Shell at {state['cwd']}",
        "cwd": state["cwd"],
        "lines": state.get("lines", []),
    }


def handle_action(context, action, payload):
    state = _state(context)
    if action == "run":
        _run_command(state, payload.get("command", ""))
    elif action == "clear":
        state["lines"] = []
    _save(context, state)
    return {"app": get_app_payload(context), "system": context["system"]}
