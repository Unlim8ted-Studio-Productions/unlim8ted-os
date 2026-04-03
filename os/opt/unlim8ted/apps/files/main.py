import os


def get_manifest():
    return {
        "id": "files",
        "title": "Files",
        "capabilities": ["files"],
        "routes": ["browser", "preview"],
        "required_services": ["files", "accounts"],
    }


def _state(context):
    return context["services"]["accounts"].store.read("files_app", {"path": context["paths"]["user_files_dir"], "preview": ""})


def _save(context, value):
    context["services"]["accounts"].store.write("files_app", value)


def _display_path(path, root_path):
    current = os.path.abspath(path or root_path)
    root = os.path.abspath(root_path)
    if current == root:
        return "Personal Storage"
    relative = os.path.relpath(current, root)
    return f"Personal Storage / {relative.replace(os.sep, ' / ')}"


def get_app_payload(context):
    state = _state(context)
    root_path = os.path.abspath(context["paths"]["user_files_dir"])
    listing = context["services"]["files"].list_dir(state["path"])
    preview = context["services"]["files"].read_text(state["preview"]) if state.get("preview") else ""
    current_path = os.path.abspath(listing["path"]) if listing["path"] else root_path
    items = []
    if current_path != root_path:
        items.append({
            "name": "Back",
            "kind": "nav",
            "description": "Go up one level",
            "action": "open_path",
            "value": os.path.dirname(current_path) or root_path,
        })
    for item in listing["items"][:48]:
        items.append({
            "name": item["name"],
            "kind": item["kind"],
            "description": "Folder" if item["kind"] == "dir" else "Text preview available",
            "action": "open_path" if item["kind"] == "dir" else "preview_file",
            "value": item["path"],
        })

    return {
        "view": "template",
        "title": "Files",
        "path": listing["path"] or root_path,
        "path_label": _display_path(listing["path"], root_path),
        "root_label": "Personal Storage",
        "entries": items,
        "preview": preview or "Select a text file to preview its contents.",
        "preview_path": state.get("preview", ""),
    }


def handle_action(context, action, payload):
    state = _state(context)
    files = context["services"]["files"]
    if action == "create_file":
        name = str(payload.get("name", "")).strip()
        body = str(payload.get("body", ""))
        if name:
            files.create_text(state["path"], name, body)
    elif action == "create_folder":
        name = str(payload.get("name", "")).strip()
        if name:
            files.create_dir(state["path"], name)
    elif action == "open_path":
        target = str(payload.get("value", "")).strip()
        if target:
            state["path"] = target
            _save(context, state)
    elif action == "preview_file":
        target = str(payload.get("value", "")).strip()
        if target:
            state["preview"] = target
            _save(context, state)
    elif action == "delete_file":
        target = str(payload.get("value", "")).strip()
        if target:
            files.delete(target)
            if state.get("preview") == target:
                state["preview"] = ""
            _save(context, state)
    return {"app": get_app_payload(context), "system": context["system"]}
