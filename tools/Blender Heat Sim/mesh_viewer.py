import argparse
import json
import math
from pathlib import Path


HEX_EDGES = (
    (0, 1), (1, 2), (2, 3), (3, 0),
    (4, 5), (5, 6), (6, 7), (7, 4),
    (0, 4), (1, 5), (2, 6), (3, 7),
)

TET_EDGES = (
    (0, 1), (1, 2), (2, 0),
    (0, 3), (1, 3), (2, 3),
)

PALETTE = (
    "#1565c0",
    "#d32f2f",
    "#2e7d32",
    "#6a1b9a",
    "#ef6c00",
    "#00838f",
    "#5d4037",
    "#c2185b",
    "#455a64",
    "#7cb342",
)


def parse_medit_mesh(path):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    index = 0
    vertices = []
    hexes = []
    tets = []

    def next_data_line(start):
        while start < len(lines):
            raw = lines[start].strip()
            start += 1
            if raw and not raw.startswith("#"):
                return raw, start
        return None, start

    while index < len(lines):
        token, index = next_data_line(index)
        if token is None:
            break
        if token == "Vertices":
            count_text, index = next_data_line(index)
            count = int(count_text)
            for _ in range(count):
                raw, index = next_data_line(index)
                parts = raw.split()
                vertices.append((float(parts[0]), float(parts[1]), float(parts[2])))
        elif token == "Hexahedra":
            count_text, index = next_data_line(index)
            count = int(count_text)
            for _ in range(count):
                raw, index = next_data_line(index)
                parts = raw.split()
                region = int(parts[8]) if len(parts) > 8 else 0
                hexes.append((tuple(int(value) - 1 for value in parts[:8]), region))
        elif token == "Tetrahedra":
            count_text, index = next_data_line(index)
            count = int(count_text)
            for _ in range(count):
                raw, index = next_data_line(index)
                parts = raw.split()
                region = int(parts[4]) if len(parts) > 4 else 0
                tets.append((tuple(int(value) - 1 for value in parts[:4]), region))
        elif token == "End":
            break

    return vertices, hexes, tets


def mesh_bounds(vertices):
    xs = [vertex[0] for vertex in vertices]
    ys = [vertex[1] for vertex in vertices]
    zs = [vertex[2] for vertex in vertices]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def build_edges(hexes, tets, max_elements):
    edges = {}
    limited_hexes = hexes[:max_elements]
    limited_tets = tets[:max_elements]
    for cell, region in limited_hexes:
        for left, right in HEX_EDGES:
            edge = tuple(sorted((cell[left], cell[right])))
            edges.setdefault(edge, region)
    for cell, region in limited_tets:
        for left, right in TET_EDGES:
            edge = tuple(sorted((cell[left], cell[right])))
            edges.setdefault(edge, region)
    return sorted(edges.items()), len(limited_hexes), len(limited_tets)


def region_color(region):
    return PALETTE[abs(int(region)) % len(PALETTE)]


def load_results_map(path):
    payload = json.loads(path.read_text(encoding="utf-8"))
    mapping = {}
    min_temp = math.inf
    max_temp = -math.inf
    for part in payload.get("parts", []):
        region = int(part.get("index", 0))
        temp = float(part.get("peak_temp_c", part.get("final_temp_c", 0.0)))
        mapping[region] = {
            "name": part.get("name", f"Part {region}"),
            "temp_c": temp,
        }
        min_temp = min(min_temp, temp)
        max_temp = max(max_temp, temp)
    if min_temp is math.inf or max_temp is -math.inf:
        min_temp = 0.0
        max_temp = 1.0
    return mapping, min_temp, max_temp


def lerp(a, b, t):
    return a + (b - a) * t


def clamp(value, low, high):
    return max(low, min(high, value))


def heat_color(temp_c, min_c, max_c):
    span = max(max_c - min_c, 1e-9)
    t = clamp((temp_c - min_c) / span, 0.0, 1.0)
    stops = (
        (0.0, (21, 101, 192)),
        (0.25, (3, 169, 244)),
        (0.5, (46, 204, 113)),
        (0.75, (255, 193, 7)),
        (1.0, (211, 47, 47)),
    )
    for index in range(len(stops) - 1):
        left_t, left_c = stops[index]
        right_t, right_c = stops[index + 1]
        if t <= right_t:
            local_t = (t - left_t) / max(right_t - left_t, 1e-9)
            rgb = (
                int(lerp(left_c[0], right_c[0], local_t)),
                int(lerp(left_c[1], right_c[1], local_t)),
                int(lerp(left_c[2], right_c[2], local_t)),
            )
            return "#%02x%02x%02x" % rgb
    last = stops[-1][1]
    return "#%02x%02x%02x" % last


def center_and_scale_vertices(vertices):
    bounds_min, bounds_max = mesh_bounds(vertices)
    center = (
        0.5 * (bounds_min[0] + bounds_max[0]),
        0.5 * (bounds_min[1] + bounds_max[1]),
        0.5 * (bounds_min[2] + bounds_max[2]),
    )
    radius = max(
        bounds_max[0] - bounds_min[0],
        bounds_max[1] - bounds_min[1],
        bounds_max[2] - bounds_min[2],
        1e-6,
    ) * 0.5
    normalized = [
        (
            (vertex[0] - center[0]) / radius,
            (vertex[1] - center[1]) / radius,
            (vertex[2] - center[2]) / radius,
        )
        for vertex in vertices
    ]
    return normalized, bounds_min, bounds_max


class MeshViewerApp:
    def __init__(self, root, path, vertices, edges, bounds_min, bounds_max, results_map, min_temp, max_temp):
        import tkinter as tk

        self.root = root
        self.path = path
        self.vertices = vertices
        self.edges = edges
        self.bounds_min = bounds_min
        self.bounds_max = bounds_max
        self.results_map = results_map
        self.min_temp = min_temp
        self.max_temp = max_temp
        self.width = 1200
        self.height = 900
        self.scale = 320.0
        self.yaw = -0.7
        self.pitch = 0.5
        self.offset_x = 0.0
        self.offset_y = 0.0
        self.last_mouse = None
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg="#fbfcfe", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.status = tk.Label(
            root,
            text=(
                "Drag to rotate | Shift+Drag to pan | Mouse wheel to zoom | "
                "R to reset | Esc to quit"
            ),
            anchor="w",
            padx=10,
            pady=6,
        )
        self.status.pack(fill="x")
        self.canvas.bind("<ButtonPress-1>", self.on_mouse_down)
        self.canvas.bind("<B1-Motion>", self.on_mouse_drag)
        self.canvas.bind("<MouseWheel>", self.on_mouse_wheel)
        self.canvas.bind("<Button-4>", self.on_mouse_wheel)
        self.canvas.bind("<Button-5>", self.on_mouse_wheel)
        self.root.bind("<KeyPress-r>", self.on_reset)
        self.root.bind("<Escape>", lambda _event: self.root.destroy())
        self.root.bind("<Configure>", self.on_resize)
        self.draw()

    def on_resize(self, event):
        if event.widget is self.root:
            self.width = max(400, event.width)
            self.height = max(300, event.height - 32)
            self.draw()

    def on_mouse_down(self, event):
        self.last_mouse = (event.x, event.y, bool(event.state & 0x0001))

    def on_mouse_drag(self, event):
        if self.last_mouse is None:
            self.last_mouse = (event.x, event.y, False)
            return
        last_x, last_y, shift = self.last_mouse
        dx = event.x - last_x
        dy = event.y - last_y
        if shift:
            self.offset_x += dx
            self.offset_y += dy
        else:
            self.yaw += dx * 0.01
            self.pitch += dy * 0.01
            self.pitch = max(-1.55, min(1.55, self.pitch))
        self.last_mouse = (event.x, event.y, shift)
        self.draw()

    def on_mouse_wheel(self, event):
        delta = getattr(event, "delta", 0)
        if delta == 0:
            delta = 120 if getattr(event, "num", 0) == 4 else -120
        factor = 1.12 if delta > 0 else 1.0 / 1.12
        self.scale = max(40.0, min(5000.0, self.scale * factor))
        self.draw()

    def on_reset(self, _event=None):
        self.scale = 320.0
        self.yaw = -0.7
        self.pitch = 0.5
        self.offset_x = 0.0
        self.offset_y = 0.0
        self.draw()

    def rotate_point(self, point):
        x, y, z = point
        cy = math.cos(self.yaw)
        sy = math.sin(self.yaw)
        cp = math.cos(self.pitch)
        sp = math.sin(self.pitch)
        xz_x = cy * x + sy * z
        xz_z = -sy * x + cy * z
        yz_y = cp * y - sp * xz_z
        yz_z = sp * y + cp * xz_z
        return xz_x, yz_y, yz_z

    def project(self, point):
        x, y, z = self.rotate_point(point)
        depth = 3.5 + z
        perspective = 1.8 / max(depth, 0.25)
        sx = self.width * 0.5 + self.offset_x + x * self.scale * perspective
        sy = self.height * 0.5 + self.offset_y - y * self.scale * perspective
        return sx, sy, z

    def draw_axes(self):
        axis_len = 0.9
        origin = self.project((0.0, 0.0, 0.0))
        axes = [
            ((axis_len, 0.0, 0.0), "#d32f2f", "X"),
            ((0.0, axis_len, 0.0), "#2e7d32", "Y"),
            ((0.0, 0.0, axis_len), "#1565c0", "Z"),
        ]
        for target, color, label in axes:
            tx, ty, _ = self.project(target)
            self.canvas.create_line(origin[0], origin[1], tx, ty, fill=color, width=2)
            self.canvas.create_text(tx + 12, ty, text=label, fill=color, font=("Segoe UI", 10, "bold"))

    def draw(self):
        self.canvas.delete("all")
        projected = [self.project(vertex) for vertex in self.vertices]
        depth_sorted = []
        for (left, right), color in self.edges:
            a = projected[left]
            b = projected[right]
            depth_sorted.append(((a[2] + b[2]) * 0.5, a, b, color))
        depth_sorted.sort(key=lambda item: item[0])
        for _depth, a, b, color in depth_sorted:
            self.canvas.create_line(a[0], a[1], b[0], b[1], fill=color, width=1)
        self.draw_axes()
        self.canvas.create_text(
            12,
            12,
            anchor="nw",
            text=self.path.name,
            fill="#111111",
            font=("Segoe UI", 13, "bold"),
        )
        if self.results_map:
            self.canvas.create_text(
                12,
                34,
                anchor="nw",
                text=f"Heat view: {self.min_temp:.1f}C to {self.max_temp:.1f}C",
                fill="#333333",
                font=("Segoe UI", 10),
            )
            self.draw_heat_legend()

    def draw_heat_legend(self):
        x0 = self.width - 54
        y0 = 40
        y1 = min(self.height - 80, 300)
        steps = 48
        for idx in range(steps):
            t0 = idx / steps
            t1 = (idx + 1) / steps
            temp = lerp(self.max_temp, self.min_temp, t0)
            color = heat_color(temp, self.min_temp, self.max_temp)
            ya = y0 + (y1 - y0) * t0
            yb = y0 + (y1 - y0) * t1
            self.canvas.create_rectangle(x0, ya, x0 + 18, yb, outline=color, fill=color)
        self.canvas.create_text(x0 - 8, y0, anchor="ne", text=f"{self.max_temp:.1f}C", fill="#222222", font=("Segoe UI", 9))
        self.canvas.create_text(x0 - 8, y1, anchor="se", text=f"{self.min_temp:.1f}C", fill="#222222", font=("Segoe UI", 9))


def resolve_edge_color(region, results_map, min_temp, max_temp):
    if results_map and int(region) in results_map:
        return heat_color(results_map[int(region)]["temp_c"], min_temp, max_temp)
    return region_color(region)


def open_mesh_viewer(path, max_elements, results_path=None):
    try:
        import tkinter as tk
    except ImportError as exc:
        raise RuntimeError("tkinter is required for the mesh viewer on this system.") from exc

    vertices, hexes, tets = parse_medit_mesh(path)
    if not vertices:
        raise RuntimeError("No vertices found in mesh file")
    bounds_min, bounds_max = mesh_bounds(vertices)
    edges, shown_hexes, shown_tets = build_edges(hexes, tets, max_elements)
    normalized_vertices, bounds_min, bounds_max = center_and_scale_vertices(vertices)
    results_map = {}
    min_temp = 0.0
    max_temp = 1.0
    if results_path and results_path.exists():
        results_map, min_temp, max_temp = load_results_map(results_path)
    recolored_edges = [
        (edge, resolve_edge_color(region, results_map, min_temp, max_temp))
        for edge, region in edges
    ]

    print(f"Mesh: {path}")
    print(f"Vertices: {len(vertices)}")
    print(f"Hexahedra: {len(hexes)}")
    print(f"Tetrahedra: {len(tets)}")
    print(
        "Bounds: "
        f"x[{bounds_min[0]:.4f}, {bounds_max[0]:.4f}] "
        f"y[{bounds_min[1]:.4f}, {bounds_max[1]:.4f}] "
        f"z[{bounds_min[2]:.4f}, {bounds_max[2]:.4f}]"
    )
    if shown_hexes < len(hexes) or shown_tets < len(tets):
        print(
            f"Displaying first {shown_hexes} hexes and {shown_tets} tets "
            f"(limit={max_elements})"
        )
    if results_map:
        print(f"Loaded heat results: {results_path}")
        print(f"Temperature range: {min_temp:.2f}C to {max_temp:.2f}C")
    elif results_path is not None:
        print(f"Results file not found: {results_path}")
    print("Opening Tk 3D mesh window...")

    root = tk.Tk()
    root.title(f"Mesh Viewer - {path.name}")
    root.geometry("1200x940")
    MeshViewerApp(
        root,
        path,
        normalized_vertices,
        recolored_edges,
        bounds_min,
        bounds_max,
        results_map,
        min_temp,
        max_temp,
    )
    root.mainloop()


def main():
    parser = argparse.ArgumentParser(description="View a Medit/SfePy .mesh file in a Tk 3D wireframe window.")
    parser.add_argument("mesh_path", nargs="?", help="Path to the .mesh file")
    parser.add_argument(
        "--max-elements",
        type=int,
        default=15000,
        help="Maximum number of hexahedra/tetrahedra to draw for interactive viewing",
    )
    parser.add_argument(
        "--results",
        help="Optional path to *_results.json to color the mesh by solved temperatures",
    )
    args = parser.parse_args()

    mesh_path = Path(args.mesh_path) if args.mesh_path else None
    if mesh_path is None:
        import tkinter as tk
        from tkinter import filedialog

        root = tk.Tk()
        root.withdraw()
        chosen = filedialog.askopenfilename(
            title="Open .mesh file",
            filetypes=[("Medit mesh", "*.mesh"), ("All files", "*.*")],
        )
        root.destroy()
        if not chosen:
            return
        mesh_path = Path(chosen)

    if not mesh_path.exists():
        raise FileNotFoundError(mesh_path)
    results_path = Path(args.results) if args.results else mesh_path.with_name(mesh_path.stem + "_results.json")
    open_mesh_viewer(mesh_path, max(1, args.max_elements), results_path)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        import traceback

        print("Mesh viewer failed:")
        print(exc)
        traceback.print_exc()
        try:
            input("Press Enter to close...")
        except EOFError:
            pass
        raise
