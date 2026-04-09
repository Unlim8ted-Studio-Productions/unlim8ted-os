import os


APP_ID = "code"
TITLE = "Code"
STATE_KEY = "code_app"
DEFAULT_STATE = {
    "path": "",
    "selected": "",
    "notice": "",
}
TEXT_EXTENSIONS = {
    ".c",
    ".cpp",
    ".css",
    ".go",
    ".h",
    ".html",
    ".ini",
    ".java",
    ".js",
    ".json",
    ".md",
    ".py",
    ".rs",
    ".sh",
    ".sql",
    ".toml",
    ".ts",
    ".tsx",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}
STARTER_SNIPPETS = {
    "py": {
        "label": "Python",
        "filename": "main.py",
        "body": "def main():\n    print('Hello from Unlim8ted Code')\n\n\nif __name__ == '__main__':\n    main()\n",
    },
    "js": {
        "label": "JavaScript",
        "filename": "app.js",
        "body": "function main() {\n    console.log('Hello from Unlim8ted Code');\n}\n\nmain();\n",
    },
    "html": {
        "label": "HTML",
        "filename": "index.html",
        "body": "<!doctype html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"utf-8\" />\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n    <title>Unlim8ted Project</title>\n</head>\n<body>\n    <main>\n        <h1>Hello from Unlim8ted Code</h1>\n    </main>\n</body>\n</html>\n",
    },
    "css": {
        "label": "CSS",
        "filename": "styles.css",
        "body": ":root {\n    color-scheme: dark;\n}\n\nbody {\n    margin: 0;\n    font-family: \"Segoe UI\", sans-serif;\n    background: #07111f;\n    color: #eef4ff;\n}\n",
    },
    "json": {
        "label": "JSON",
        "filename": "config.json",
        "body": "{\n  \"name\": \"unlim8ted-project\",\n  \"version\": 1,\n  \"private\": true\n}\n",
    },
}


def get_manifest():
    return {
        "id": APP_ID,
        "title": TITLE,
        "capabilities": ["files"],
        "routes": ["workspace", "editor"],
        "required_services": ["files", "store"],
    }


def _store(context):
    return context["services"]["store"]


def _workspace_root(context):
    root = os.path.join(context["paths"]["user_files_dir"], "Projects")
    os.makedirs(root, exist_ok=True)
    return os.path.abspath(root)


def _state(context):
    state = _store(context).read(STATE_KEY, dict(DEFAULT_STATE)) or {}
    for key, value in DEFAULT_STATE.items():
        state.setdefault(key, value)
    root = _workspace_root(context)
    if not state["path"]:
        state["path"] = root
    return state


def _save(context, value):
    _store(context).write(STATE_KEY, value)


def _display_path(path, root_path):
    current = os.path.abspath(path or root_path)
    root = os.path.abspath(root_path)
    if current == root:
        return "Projects"
    relative = os.path.relpath(current, root)
    return f"Projects / {relative.replace(os.sep, ' / ')}"


def _language_for_name(name):
    extension = os.path.splitext(str(name or ""))[1].lower()
    mapping = {
        ".py": "Python",
        ".js": "JavaScript",
        ".ts": "TypeScript",
        ".tsx": "TSX",
        ".html": "HTML",
        ".css": "CSS",
        ".json": "JSON",
        ".md": "Markdown",
        ".sh": "Shell",
        ".sql": "SQL",
        ".yaml": "YAML",
        ".yml": "YAML",
        ".toml": "TOML",
        ".txt": "Text",
        ".rs": "Rust",
        ".go": "Go",
        ".java": "Java",
        ".c": "C",
        ".h": "Header",
        ".cpp": "C++",
        ".xml": "XML",
        ".ini": "INI",
    }
    return mapping.get(extension, "Text")


def _is_code_file(info):
    if not info or info.get("kind") != "file":
        return False
    extension = os.path.splitext(info.get("name", ""))[1].lower()
    if extension in TEXT_EXTENSIONS:
        return True
    return bool(info.get("editable"))


def _summarize_directory(items):
    counts = {"folders": 0, "files": 0, "code_files": 0}
    for item in items:
        if item.get("kind") == "dir":
            counts["folders"] += 1
        else:
            counts["files"] += 1
            if _is_code_file(item):
                counts["code_files"] += 1
    return counts


def _editor_payload(context, selected_info):
    files = context["services"]["files"]
    if not selected_info:
        body = STARTER_SNIPPETS["py"]["body"]
        return {
            "mode": "starter",
            "title": "No file selected",
            "language": "Python",
            "body": body,
            "line_count": len(body.splitlines()) or 1,
            "read_only": True,
            "status": "Open a file or create one from a starter template.",
        }
    if not _is_code_file(selected_info):
        return {
            "mode": "read_only",
            "title": selected_info.get("name", "Unsupported"),
            "language": "Binary",
            "body": "This item cannot be edited here yet. Open a text-based source file to continue.",
            "line_count": 2,
            "read_only": True,
            "status": "Only text and source files can be edited in Code.",
        }
    body = files.read_text(selected_info["path"], limit=180000)
    return {
        "mode": "editor",
        "title": selected_info.get("name", "Untitled"),
        "language": _language_for_name(selected_info.get("name", "")),
        "body": body,
        "line_count": len(body.splitlines()) or 1,
        "read_only": False,
        "status": "Ready to edit and save.",
    }


def get_app_payload(context):
    state = _state(context)
    files = context["services"]["files"]
    root_path = _workspace_root(context)
    listing = files.list_dir(state["path"])
    current_path = os.path.abspath(listing["path"] or root_path)
    selected_path = state.get("selected", "")
    selected_info = files.describe(selected_path) if selected_path else None
    if selected_path and not selected_info:
        state["selected"] = ""
        selected_path = ""
        _save(context, state)

    items = []
    if current_path != root_path:
        items.append(
            {
                "name": "..",
                "kind": "nav",
                "meta": "Parent folder",
                "action": "open_path",
                "value": os.path.dirname(current_path) or root_path,
            }
        )

    directories = [item for item in listing["items"] if item.get("kind") == "dir"]
    files_only = [item for item in listing["items"] if item.get("kind") != "dir"]
    ordered_items = directories + files_only
    for item in ordered_items[:160]:
        items.append(
            {
                "name": item.get("name", ""),
                "kind": item.get("kind", "file"),
                "meta": (
                    "Folder"
                    if item.get("kind") == "dir"
                    else f"{_language_for_name(item.get('name', ''))} source"
                    if _is_code_file(item)
                    else "Non-editable file"
                ),
                "action": "open_path" if item.get("kind") == "dir" else "select_path",
                "value": item.get("path", ""),
                "selected": item.get("path", "") == selected_path,
                "editable": _is_code_file(item),
            }
        )

    stats = _summarize_directory(listing["items"])
    editor = _editor_payload(context, selected_info)
    selected_name = selected_info.get("name", "") if selected_info else ""
    selected_kind = selected_info.get("kind", "") if selected_info else ""
    relative_selected = ""
    if selected_info:
        relative_selected = os.path.relpath(selected_info["path"], root_path).replace(os.sep, "/")

    return {
        "view": "template",
        "title": TITLE,
        "subtitle": f"{stats['code_files']} source files visible in {_display_path(current_path, root_path)}",
        "workspace_root": root_path,
        "path": current_path,
        "path_label": _display_path(current_path, root_path),
        "entries": items,
        "notice": state.get("notice", ""),
        "selected_path": selected_path,
        "selected_name": selected_name,
        "selected_kind": selected_kind,
        "selected_relative_path": relative_selected,
        "selected_editable": bool(selected_info and _is_code_file(selected_info)),
        "editor": editor,
        "stats": stats,
        "templates": [
            {
                "id": template_id,
                "label": template["label"],
                "filename": template["filename"],
            }
            for template_id, template in STARTER_SNIPPETS.items()
        ],
    }


def handle_action(context, action, payload):
    state = _state(context)
    files = context["services"]["files"]
    root_path = _workspace_root(context)
    state["notice"] = ""

    if action == "open_path":
        target = str(payload.get("value", "")).strip()
        info = files.describe(target)
        if info and info.get("kind") == "dir":
            state["path"] = info["path"]
            if state.get("selected") and not str(state["selected"]).startswith(info["path"]):
                state["selected"] = ""
    elif action == "select_path":
        target = str(payload.get("value", "")).strip()
        info = files.describe(target)
        if info and info.get("kind") == "file":
            state["selected"] = info["path"]
            if not _is_code_file(info):
                state["notice"] = f"{info['name']} is not an editable source file."
    elif action == "create_project":
        name = str(payload.get("name", "")).strip()
        if name and files.create_dir(root_path, name):
            state["path"] = os.path.join(root_path, os.path.basename(name))
            state["selected"] = ""
            state["notice"] = f"Created project {os.path.basename(name)}"
    elif action == "create_folder":
        name = str(payload.get("name", "")).strip()
        if name and files.create_dir(state["path"], name):
            state["notice"] = f"Created folder {os.path.basename(name)}"
    elif action == "create_file":
        name = str(payload.get("name", "")).strip()
        template_id = str(payload.get("template", "")).strip()
        body = str(payload.get("body", ""))
        if template_id in STARTER_SNIPPETS and not name:
            name = STARTER_SNIPPETS[template_id]["filename"]
        if template_id in STARTER_SNIPPETS and not body:
            body = STARTER_SNIPPETS[template_id]["body"]
        if name and files.create_text(state["path"], name, body):
            state["selected"] = os.path.join(state["path"], os.path.basename(name))
            state["notice"] = f"Created {os.path.basename(name)}"
    elif action == "save_file":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        body = str(payload.get("body", ""))
        if target and files.write_text(target, body):
            state["selected"] = target
            state["notice"] = f"Saved {os.path.basename(target)}"
    elif action == "rename_entry":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        name = str(payload.get("name", "")).strip()
        renamed = files.rename(target, name) if target and name else None
        if renamed:
            if os.path.abspath(state.get("path", "")) == os.path.abspath(target):
                state["path"] = renamed
            state["selected"] = renamed if os.path.isfile(renamed) else ""
            state["notice"] = f"Renamed to {os.path.basename(renamed)}"
    elif action == "delete_entry":
        target = str(payload.get("value", "") or state.get("selected", "")).strip()
        if target and files.delete(target):
            if os.path.abspath(state.get("selected", "")) == os.path.abspath(target):
                state["selected"] = ""
            if os.path.abspath(state.get("path", "")) == os.path.abspath(target):
                state["path"] = os.path.dirname(target) or root_path
            state["notice"] = f"Deleted {os.path.basename(target)}"

    _save(context, state)
    return {"app": get_app_payload(context), "system": context["system"]}
