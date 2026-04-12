import os
from urllib.parse import quote, unquote


def get_manifest():
    return {
        "id": "files",
        "title": "Files",
        "capabilities": ["files"],
        "routes": ["browser", "editor", "item"],
        "required_services": ["files", "accounts"],
    }


DEFAULT_STATE = {
    "path": "",
    "selected": "",
    "notice": "",
    "query": "",
    "sort": "name",
    "view_mode": "list",
}


TEXT_EXTENSIONS = {
    ".txt",
    ".md",
    ".json",
    ".py",
    ".js",
    ".html",
    ".css",
    ".csv",
    ".log",
    ".ini",
    ".yaml",
    ".yml",
    ".toml",
}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".svg"}


def _state(context):
    state = context["services"]["accounts"].store.read("files_app", dict(DEFAULT_STATE))
    for key, value in DEFAULT_STATE.items():
        state.setdefault(key, value)
    if not state["path"]:
        state["path"] = context["paths"]["user_files_dir"]
    return state


def _save(context, value):
    context["services"]["accounts"].store.write("files_app", value)


def _root_label(path, index=0):
    path = os.path.abspath(path)
    if path.endswith("/Files"):
        return "Files"
    if path.endswith("/unlim8ted") or path == "/home/unlim8ted":
        return "Home"
    if path == "/media":
        return "Media"
    if path == "/mnt":
        return "Mounts"
    if path.endswith("/boot/firmware"):
        return "Boot"
    return os.path.basename(path) or f"Root {index + 1}"


def _display_path(path, roots):
    current = os.path.abspath(path or (roots[0] if roots else "/"))
    for index, root_path in enumerate(roots):
        root = os.path.abspath(root_path)
        try:
            if os.path.commonpath([current, root]) != root:
                continue
        except ValueError:
            continue
        if current == root:
            return _root_label(root, index)
        relative = os.path.relpath(current, root)
        return f"{_root_label(root, index)} / {relative.replace(os.sep, ' / ')}"
    return current


def _containing_root(path, roots):
    current = os.path.abspath(path or (roots[0] if roots else "/"))
    best = ""
    for root_path in roots:
        root = os.path.abspath(root_path)
        try:
            if os.path.commonpath([current, root]) == root:
                if not best or len(root) > len(best):
                    best = root
        except ValueError:
            continue
    return best or (os.path.abspath(roots[0]) if roots else current)


def _path_is_within(path, parent):
    current = os.path.abspath(path)
    root = os.path.abspath(parent)
    try:
        return os.path.commonpath([current, root]) == root
    except ValueError:
        return False


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


def _preview_payload(context, selected_path):
    files = context["services"]["files"]
    info = files.describe(selected_path) if selected_path else None
    if not info:
        return {
            "kind": "empty",
            "title": "No file selected",
            "body": "Select a file to preview, rename, edit, or delete it.",
        }

    if info["kind"] == "dir":
        listing = files.list_dir(info["path"])
        return {
            "kind": "dir",
            "title": info["name"],
            "body": f"Folder with {len(listing['items'])} visible items.",
            "info": info,
        }

    extension = os.path.splitext(info["name"])[1].lower()
    mime = str(info.get("mime", ""))
    if info.get("editable") or extension in TEXT_EXTENSIONS:
        return {
            "kind": "text",
            "title": info["name"],
            "body": files.read_text(info["path"], limit=120000),
            "info": info,
        }
    if mime.startswith("image/") or extension in IMAGE_EXTENSIONS:
        return {
            "kind": "image",
            "title": info["name"],
            "url": f"/api/apps/files/item?path={quote(info['path'])}",
            "body": "Image preview available.",
            "info": info,
        }
    return {
        "kind": "binary",
        "title": info["name"],
        "body": "Preview is not available for this file type yet.",
        "info": info,
    }


def get_app_payload(context):
    state = _state(context)
    files = context["services"]["files"]
    root_path = os.path.abspath(context["paths"]["user_files_dir"])
    roots = list(getattr(files, "roots", []) or [root_path])
    listing = files.list_dir(state["path"])
    current_path = os.path.abspath(listing["path"]) if listing["path"] else root_path
    selected_path = state.get("selected", "")
    selected_info = files.describe(selected_path) if selected_path else None
    if selected_path and not selected_info:
        state["selected"] = ""
        selected_path = ""
        _save(context, state)

    items = []
    current_root = _containing_root(current_path, roots)
    if current_path != current_root:
        items.append(
            {
                "name": "..",
                "kind": "nav",
                "description": "Go up one level",
                "action": "open_path",
                "value": os.path.dirname(current_path) or root_path,
                "meta": "Parent folder",
            }
        )
    for index, root in enumerate(roots):
        if os.path.abspath(root) == current_path:
            continue
        items.append(
            {
                "name": _root_label(root, index),
                "kind": "root",
                "description": root,
                "action": "open_path",
                "value": root,
                "meta": "Location",
            }
        )
    for item in listing["items"][:96]:
        extension = os.path.splitext(item["name"])[1].lower()
        meta = (
            "Folder"
            if item["kind"] == "dir"
            else f"{item.get('mime', 'File')} • {_format_bytes(item.get('size', 0))}"
        )
        items.append(
            {
                "name": item["name"],
                "kind": item["kind"],
                "description": item.get("modified_at", ""),
                "action": "open_path" if item["kind"] == "dir" else "select_path",
                "value": item["path"],
                "meta": meta,
                "extension": extension,
                "size": int(item.get("size", 0)),
                "size_label": _format_bytes(item.get("size", 0)),
                "modified_at": item.get("modified_at", ""),
                "selected": item["path"] == selected_path,
            }
        )

    preview = _preview_payload(context, selected_path)
    selected_details = preview.get("info") or selected_info
    detail_rows = []
    if selected_details:
        detail_rows = [
            {
                "label": "Type",
                "value": selected_details.get("mime")
                if selected_details.get("kind") == "file"
                else "Folder",
            },
            {
                "label": "Size",
                "value": _format_bytes(selected_details.get("size", 0))
                if selected_details.get("kind") == "file"
                else f"{len(files.list_dir(selected_details['path'])['items'])} items",
            },
            {"label": "Modified", "value": selected_details.get("modified_at", "")},
            {"label": "Path", "value": selected_details.get("path", "")},
        ]

    return {
        "view": "template",
        "title": "Files",
        "subtitle": f"{len(listing['items'])} items in {_display_path(current_path, roots)}",
        "path": listing["path"] or root_path,
        "path_label": _display_path(listing["path"], roots),
        "roots": [{"label": _root_label(path, index), "path": path} for index, path in enumerate(roots)],
        "entries": items,
        "query": state.get("query", ""),
        "sort": state.get("sort", "name"),
        "view_mode": state.get("view_mode", "list"),
        "preview": preview,
        "selected_path": selected_path,
        "selected_name": selected_details.get("name", "") if selected_details else "",
        "selected_kind": selected_details.get("kind", "") if selected_details else "",
        "details": detail_rows,
        "notice": state.get("notice", ""),
    }


def handle_action(context, action, payload):
    state = _state(context)
    files = context["services"]["files"]
    state["notice"] = ""

    if action == "create_file":
        name = str(payload.get("name", "")).strip()
        body = str(payload.get("body", ""))
        if name and files.create_text(state["path"], name, body):
            state["selected"] = os.path.join(state["path"], os.path.basename(name))
            state["notice"] = f"Created {os.path.basename(name)}"
    elif action == "create_folder":
        name = str(payload.get("name", "")).strip()
        if name and files.create_dir(state["path"], name):
            state["selected"] = os.path.join(state["path"], os.path.basename(name))
            state["notice"] = f"Created folder {os.path.basename(name)}"
    elif action == "open_path":
        target = str(payload.get("value", "")).strip()
        if target:
            listing = files.list_dir(target)
            state["path"] = listing.get("path") or state["path"]
            selected = state.get("selected", "")
            if selected and not _path_is_within(selected, state["path"]):
                state["selected"] = ""
    elif action == "select_path":
        target = str(payload.get("value", "")).strip()
        if target:
            state["selected"] = target
    elif action == "set_view_options":
        state["query"] = str(payload.get("query", state.get("query", ""))).strip()
        sort = str(payload.get("sort", state.get("sort", "name"))).strip()
        view_mode = str(payload.get("view_mode", state.get("view_mode", "list"))).strip()
        if sort in {"name", "date", "size", "type"}:
            state["sort"] = sort
        if view_mode in {"list", "grid"}:
            state["view_mode"] = view_mode
    elif action == "save_file":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        body = str(payload.get("body", ""))
        if target and files.write_text(target, body):
            state["selected"] = target
            state["notice"] = f"Saved {os.path.basename(target)}"
    elif action == "rename_path":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        name = str(payload.get("name", "")).strip()
        renamed = files.rename(target, name) if target and name else None
        if renamed:
            if state.get("path") == target:
                state["path"] = renamed
            state["selected"] = renamed
            state["notice"] = f"Renamed to {os.path.basename(renamed)}"
    elif action == "delete_file":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        if target and files.delete(target):
            if state.get("selected") == target:
                state["selected"] = ""
            if os.path.abspath(state.get("path", "")) == os.path.abspath(target):
                state["path"] = os.path.dirname(target) or context["paths"]["user_files_dir"]
            state["notice"] = f"Deleted {os.path.basename(target)}"

    _save(context, state)
    return {"app": get_app_payload(context), "system": context["system"]}


def handle_http(context, request):
    if request["method"] != "GET" or request["subpath"] != "item":
        return {"type": "json", "status": 404, "body": {"ok": False, "code": "route_not_found"}}

    raw_path = ""
    query_path = request.get("query", {}).get("path", [])
    if query_path:
        raw_path = str(query_path[0])
    target = unquote(raw_path)
    files = context["services"]["files"]
    info = files.describe(target)
    if not info or info.get("kind") != "file":
        return {"type": "json", "status": 404, "body": {"ok": False, "code": "file_not_found"}}

    return {
        "type": "raw",
        "status": 200,
        "content_type": info.get("mime", "application/octet-stream"),
        "body": files.read_binary(target),
    }

