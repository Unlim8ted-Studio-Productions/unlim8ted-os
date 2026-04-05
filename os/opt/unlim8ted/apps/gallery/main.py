import os
from datetime import datetime


def get_manifest():
    return {
        "id": "gallery",
        "title": "Gallery",
        "capabilities": ["files"],
        "routes": ["grid", "detail"],
        "required_services": ["media", "accounts"],
    }


DEFAULT_STATE = {"selected": "", "notice": ""}


def _state(context):
    state = context["services"]["accounts"].store.read("gallery", dict(DEFAULT_STATE))
    for key, value in DEFAULT_STATE.items():
        state.setdefault(key, value)
    return state


def _save(context, value):
    context["services"]["accounts"].store.write("gallery", value)


def _format_bytes(size):
    value = int(size or 0)
    units = ["B", "KB", "MB", "GB"]
    index = 0
    while value >= 1024 and index < len(units) - 1:
        value /= 1024.0
        index += 1
    if index == 0:
        return f"{int(value)} {units[index]}"
    return f"{value:.1f} {units[index]}"


def _capture_details(context, item):
    capture_path = os.path.join(context["paths"]["captures_dir"], item["name"])
    try:
        stat = os.stat(capture_path)
    except OSError:
        return {
            "name": item["name"],
            "url": item["url"],
            "size_label": "Unknown size",
            "created_label": "Unknown date",
        }
    return {
        "name": item["name"],
        "url": item["url"],
        "size_label": _format_bytes(stat.st_size),
        "created_label": datetime.utcfromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M UTC"),
    }


def get_app_payload(context):
    state = _state(context)
    captures = [
        _capture_details(context, item)
        for item in context["services"]["media"].captures(context["media_prefix"], limit=48)
    ]
    if captures and not any(item["name"] == state["selected"] for item in captures):
        state["selected"] = captures[0]["name"]
        _save(context, state)
    selected = next((item for item in captures if item["name"] == state["selected"]), captures[0] if captures else None)

    return {
        "view": "template",
        "title": "Gallery",
        "subtitle": f"{len(captures)} captures saved locally",
        "gallery": {
            "items": captures,
            "selected": selected,
            "notice": state.get("notice", ""),
        },
    }


def handle_action(context, action, payload):
    state = _state(context)
    state["notice"] = ""
    if action == "select_capture":
        state["selected"] = str(payload.get("value", "")).strip()
    elif action == "delete_capture":
        name = str(payload.get("value", "")).strip()
        if name and context["services"]["media"].delete_capture(name):
            if state.get("selected") == name:
                state["selected"] = ""
            state["notice"] = f"Deleted {name}"
    _save(context, state)
    return {"app": get_app_payload(context), "system": context["system"]}
