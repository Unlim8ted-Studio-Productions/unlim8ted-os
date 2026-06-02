bl_info = {
    "name": "CAD Heat Sim",
    "author": "Unlim8ted Studios",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Heat Sim",
    "description": "Material-aware transient heat simulation for CAD-style Blender scenes",
    "category": "Object",
}

import csv
import gzip
import json
import math
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass

import bmesh
import bpy
from bpy_extras.io_utils import ExportHelper
from bpy.props import (
    BoolProperty,
    CollectionProperty,
    EnumProperty,
    FloatProperty,
    IntProperty,
    PointerProperty,
    StringProperty,
)
from bpy.types import AddonPreferences, Operator, Panel, PropertyGroup
from mathutils import Vector

SIGMA = 5.670374419e-8
EPSILON = 1.0e-9

MATERIAL_LIBRARY = {
    "ALUMINUM_6061": {
        "label": "Aluminum 6061",
        "conductivity": 167.0,
        "density": 2700.0,
        "specific_heat": 896.0,
        "emissivity": 0.09,
    },
    "COPPER": {
        "label": "Copper",
        "conductivity": 401.0,
        "density": 8960.0,
        "specific_heat": 385.0,
        "emissivity": 0.05,
    },
    "STEEL_304": {
        "label": "Stainless Steel 304",
        "conductivity": 16.2,
        "density": 8030.0,
        "specific_heat": 500.0,
        "emissivity": 0.59,
    },
    "STEEL_SCREW": {
        "label": "Steel Screw",
        "conductivity": 16.2,
        "density": 7850.0,
        "specific_heat": 490.0,
        "emissivity": 0.55,
    },
    "TITANIUM": {
        "label": "Titanium",
        "conductivity": 21.9,
        "density": 4500.0,
        "specific_heat": 522.0,
        "emissivity": 0.40,
    },
    "BRASS": {
        "label": "Brass",
        "conductivity": 109.0,
        "density": 8500.0,
        "specific_heat": 380.0,
        "emissivity": 0.30,
    },
    "ABS": {
        "label": "ABS Plastic",
        "conductivity": 0.18,
        "density": 1040.0,
        "specific_heat": 1300.0,
        "emissivity": 0.94,
    },
    "PLA": {
        "label": "PLA",
        "conductivity": 0.13,
        "density": 1240.0,
        "specific_heat": 1800.0,
        "emissivity": 0.94,
    },
    "POLYCARBONATE": {
        "label": "Polycarbonate",
        "conductivity": 0.20,
        "density": 1200.0,
        "specific_heat": 1200.0,
        "emissivity": 0.92,
    },
    "TPU": {
        "label": "TPU",
        "conductivity": 0.20,
        "density": 1210.0,
        "specific_heat": 1800.0,
        "emissivity": 0.94,
    },
    "NYLON": {
        "label": "Nylon",
        "conductivity": 0.25,
        "density": 1150.0,
        "specific_heat": 1700.0,
        "emissivity": 0.94,
    },
    "GLASS": {
        "label": "Glass",
        "conductivity": 1.05,
        "density": 2500.0,
        "specific_heat": 840.0,
        "emissivity": 0.94,
    },
    "CERAMIC": {
        "label": "Ceramic",
        "conductivity": 2.5,
        "density": 3900.0,
        "specific_heat": 750.0,
        "emissivity": 0.90,
    },
    "SILICON": {
        "label": "Silicon",
        "conductivity": 148.0,
        "density": 2330.0,
        "specific_heat": 700.0,
        "emissivity": 0.70,
    },
    "THERMAL_PAD": {
        "label": "Thermal Pad",
        "conductivity": 6.0,
        "density": 3200.0,
        "specific_heat": 1000.0,
        "emissivity": 0.95,
    },
    "THERMAL_PASTE": {
        "label": "Thermal Paste",
        "conductivity": 4.0,
        "density": 2500.0,
        "specific_heat": 900.0,
        "emissivity": 0.95,
    },
    "GRAPHITE_PAD": {
        "label": "Graphite Pad",
        "conductivity": 350.0,
        "density": 1800.0,
        "specific_heat": 710.0,
        "emissivity": 0.85,
    },
    "LIPO_BATTERY": {
        "label": "LiPo Battery",
        "conductivity": 1.5,
        "density": 2300.0,
        "specific_heat": 1100.0,
        "emissivity": 0.90,
    },
    "PCB_FR4": {
        "label": "PCB FR4",
        "conductivity": 0.30,
        "density": 1850.0,
        "specific_heat": 1200.0,
        "emissivity": 0.90,
    },
    "CM4_PCB": {
        "label": "CM4 PCB",
        "conductivity": 0.30,
        "density": 1850.0,
        "specific_heat": 1200.0,
        "emissivity": 0.90,
    },
    "CM4_SOC": {
        "label": "CM4 SoC Package",
        "conductivity": 18.0,
        "density": 3200.0,
        "specific_heat": 850.0,
        "emissivity": 0.88,
    },
    "CM4_MODULE": {
        "label": "CM4 Module",
        "conductivity": 8.0,
        "density": 2100.0,
        "specific_heat": 900.0,
        "emissivity": 0.85,
    },
    "DSI_DISPLAY": {
        "label": "Waveshare 6.25 DSI Display",
        "conductivity": 3.2,
        "density": 2400.0,
        "specific_heat": 900.0,
        "emissivity": 0.92,
    },
    "FPC_CABLE": {
        "label": "FPC Ribbon Cable",
        "conductivity": 0.8,
        "density": 1450.0,
        "specific_heat": 1100.0,
        "emissivity": 0.92,
    },
    "ADHESIVE": {
        "label": "Adhesive Tape",
        "conductivity": 0.20,
        "density": 1100.0,
        "specific_heat": 1400.0,
        "emissivity": 0.95,
    },
    "CUSTOM": {
        "label": "Custom",
        "conductivity": 10.0,
        "density": 1000.0,
        "specific_heat": 1000.0,
        "emissivity": 0.90,
    },
}


MATERIAL_ITEMS = [
    (key, value["label"], value["label"]) for key, value in MATERIAL_LIBRARY.items()
]

COMPONENT_LIBRARY = {
    "GENERIC": {
        "label": "Generic Part",
        "material": "CUSTOM",
        "idle_power": 0.0,
        "max_power": 0.0,
        "convection_h": 8.0,
        "contact_h": 2500.0,
    },
    "CM4_LITE_8GB": {
        "label": "Raspberry Pi CM4 Lite 8GB",
        "material": "CM4_MODULE",
        "idle_power": 1.8,
        "max_power": 7.5,
        "convection_h": 8.0,
        "contact_h": 3000.0,
    },
    "CM4_NANO_C": {
        "label": "Waveshare CM4-NANO-C",
        "material": "PCB_FR4",
        "idle_power": 0.15,
        "max_power": 0.9,
        "convection_h": 7.0,
        "contact_h": 2500.0,
    },
    "WAVESHARE_625_DSI": {
        "label": "Waveshare 6.25-inch DSI LCD",
        "material": "DSI_DISPLAY",
        "idle_power": 0.8,
        "max_power": 3.8,
        "convection_h": 7.0,
        "contact_h": 1800.0,
    },
    "MICROSD_32GB": {
        "label": "32GB microSD Card",
        "material": "PCB_FR4",
        "idle_power": 0.03,
        "max_power": 0.6,
        "convection_h": 8.0,
        "contact_h": 1800.0,
    },
    "LIPO_RIDER_PLUS": {
        "label": "Seeed LiPo Rider Plus",
        "material": "PCB_FR4",
        "idle_power": 0.1,
        "max_power": 1.5,
        "convection_h": 8.0,
        "contact_h": 2200.0,
    },
    "LIPO_3000MAH": {
        "label": "3.7V 3000mAh LiPo",
        "material": "LIPO_BATTERY",
        "idle_power": 0.02,
        "max_power": 2.0,
        "convection_h": 5.0,
        "contact_h": 1200.0,
    },
    "DSI_15PIN_CABLE": {
        "label": "15cm 15-pin DSI Cable",
        "material": "FPC_CABLE",
        "idle_power": 0.01,
        "max_power": 0.08,
        "convection_h": 8.0,
        "contact_h": 1200.0,
    },
    "USB_A_TO_C_CABLE": {
        "label": "USB Type A to Type C Cable",
        "material": "FPC_CABLE",
        "idle_power": 0.02,
        "max_power": 0.15,
        "convection_h": 8.0,
        "contact_h": 1200.0,
    },
}

COMPONENT_ITEMS = [
    (key, value["label"], value["label"]) for key, value in COMPONENT_LIBRARY.items()
]

COLOR_SCOPE_ITEMS = [
    ("RUN", "Whole Run", "Normalize colors across the full simulation range"),
    ("FRAME", "Current Frame", "Normalize colors using the current preview frame"),
    ("MANUAL", "Manual", "Use manual temperature limits for coloring"),
]

PREVIEW_MODE_ITEMS = [
    ("SURFACE", "Surface", "Preview exposed surface temperature"),
    ("CORE", "Core", "Preview internal/core temperature"),
    ("MAX", "Max", "Preview the hotter of core and surface"),
]

SOLVER_BACKEND_ITEMS = [
    ("INTERNAL", "Internal Preview", "Use Blender's built-in preview solver"),
    ("SFEPY_SERVER", "SfePy Server", "Send the exported case to an external SfePy solver server"),
]


def clamp(value, low, high):
    return max(low, min(high, value))


def lerp(a, b, t):
    return a + (b - a) * t


def safe_tag(value, prefix="n"):
    tag = re.sub(r"[^0-9A-Za-z_]+", "_", value)
    tag = tag.strip("_")
    if not tag:
        tag = prefix
    if tag[0].isdigit():
        tag = f"{prefix}_{tag}"
    return tag.lower()


def java_string(value):
    return json.dumps(str(value).replace("\\", "\\\\"))


def addon_preferences(context=None):
    prefs_owner = context.preferences if context else bpy.context.preferences
    addon = prefs_owner.addons.get(__name__)
    if addon is None:
        return None
    return addon.preferences


def ensure_directory(path):
    os.makedirs(path, exist_ok=True)
    return path


def server_script_path():
    return os.path.join(os.path.dirname(__file__), "solver_server.py")


def server_base_url(prefs):
    return f"http://{prefs.server_host}:{prefs.server_port}"


def http_json(method, url, payload=None, timeout=10.0):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(body) if body else {}
        except json.JSONDecodeError:
            payload = {"status": "error", "message": body or str(exc), "http_status": exc.code}
        error = RuntimeError(payload.get("message") or str(exc))
        setattr(error, "payload", payload)
        raise error from exc


def solver_server_health(prefs, timeout=2.0):
    try:
        return http_json("GET", server_base_url(prefs) + "/health", timeout=timeout)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def solver_server_job_status(prefs, job_id, timeout=2.0):
    try:
        return http_json("GET", server_base_url(prefs) + f"/job/{job_id}", timeout=timeout)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def launch_solver_server(prefs):
    python_executable = bpy.path.abspath(prefs.server_python_executable)
    if not python_executable:
        raise RuntimeError("Set Server Python in the add-on preferences first")
    command = [
        python_executable,
        server_script_path(),
        "--host",
        prefs.server_host,
        "--port",
        str(prefs.server_port),
    ]
    kwargs = {
        "cwd": os.path.dirname(server_script_path()),
    }
    if os.name == "nt":
        if prefs.show_server_console:
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NEW_CONSOLE", 0)
        else:
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            kwargs["startupinfo"] = startupinfo
            kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            kwargs["stdout"] = subprocess.DEVNULL
            kwargs["stderr"] = subprocess.DEVNULL
    elif not prefs.show_server_console:
        kwargs["stdout"] = subprocess.DEVNULL
        kwargs["stderr"] = subprocess.DEVNULL
    subprocess.Popen(command, **kwargs)


def heat_color(temp_c, min_c, max_c):
    span = max(max_c - min_c, EPSILON)
    t = clamp((temp_c - min_c) / span, 0.0, 1.0)
    stops = [
        (0.0, (0.06, 0.17, 0.42)),
        (0.25, (0.11, 0.52, 0.89)),
        (0.5, (0.14, 0.78, 0.56)),
        (0.75, (0.99, 0.73, 0.18)),
        (1.0, (0.86, 0.17, 0.08)),
    ]
    for index in range(len(stops) - 1):
        left_t, left_c = stops[index]
        right_t, right_c = stops[index + 1]
        if t <= right_t:
            local_t = (t - left_t) / max(right_t - left_t, EPSILON)
            return (
                lerp(left_c[0], right_c[0], local_t),
                lerp(left_c[1], right_c[1], local_t),
                lerp(left_c[2], right_c[2], local_t),
                1.0,
            )
    return (*stops[-1][1], 1.0)


def ensure_preview_material(obj):
    material_name = "_HeatSimPreview"
    material = bpy.data.materials.get(material_name)
    if material is None:
        material = bpy.data.materials.new(name=material_name)
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled:
            principled.inputs["Roughness"].default_value = 0.35
            principled.inputs["Metallic"].default_value = 0.0
    if obj.type == "MESH":
        if not obj.data.materials:
            obj.data.materials.append(material)
        elif material_name not in {
            slot.material.name for slot in obj.material_slots if slot.material
        }:
            obj.data.materials.append(material)
    return material


def apply_preview_color(obj, color):
    obj.color = color
    material = ensure_preview_material(obj)
    if material and material.use_nodes:
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled:
            principled.inputs["Base Color"].default_value = color
            emission = principled.inputs.get("Emission Color")
            if emission:
                emission.default_value = color
            emission_strength = principled.inputs.get("Emission Strength")
            if emission_strength:
                emission_strength.default_value = 0.25


def frame_mode_temperatures(frame, mode):
    core_temps = frame.get("core_temps", frame.get("temps", []))
    surface_temps = frame.get("surface_temps", frame.get("temps", []))
    if mode == "CORE":
        return core_temps
    if mode == "MAX":
        return [max(core, surface) for core, surface in zip(core_temps, surface_temps)]
    return surface_temps


def run_mode_range(results, mode):
    min_temp = math.inf
    max_temp = -math.inf
    for frame in results.get("frames", []):
        temps = frame_mode_temperatures(frame, mode)
        if not temps:
            continue
        min_temp = min(min_temp, min(temps))
        max_temp = max(max_temp, max(temps))
    if min_temp == math.inf or max_temp == -math.inf:
        return None
    return min_temp, max_temp


def frame_temperature_stats(results, frame_index, mode):
    frames = results.get("frames", [])
    object_names = results.get("objects", [])
    if not frames or not object_names:
        return None
    frame_index = clamp(frame_index, 0, len(frames) - 1)
    frame = frames[frame_index]
    pairs = list(zip(object_names, frame_mode_temperatures(frame, mode)))
    if not pairs:
        return None
    hottest = max(pairs, key=lambda item: item[1])
    coolest = min(pairs, key=lambda item: item[1])
    temperatures = [item[1] for item in pairs]
    return {
        "time": frame.get("time", 0.0),
        "min_temp": min(temperatures),
        "max_temp": max(temperatures),
        "hottest_name": hottest[0],
        "hottest_temp": hottest[1],
        "coolest_name": coolest[0],
        "coolest_temp": coolest[1],
    }


def preview_range(settings, results, frame_index):
    if settings.color_scope == "MANUAL":
        return settings.color_min, settings.color_max
    if settings.color_scope == "FRAME":
        stats = frame_temperature_stats(results, frame_index, settings.preview_temperature_mode)
        if stats:
            return stats["min_temp"], stats["max_temp"]
    run_range = run_mode_range(results, settings.preview_temperature_mode)
    if run_range:
        return run_range
    return results.get("min_temp", settings.color_min), results.get("max_temp", settings.color_max)


def set_preferred_viewport(context):
    screen = getattr(context, "screen", None)
    if screen is None:
        return
    for area in screen.areas:
        if area.type != "VIEW_3D":
            continue
        for space in area.spaces:
            if space.type != "VIEW_3D":
                continue
            shading = space.shading
            shading.type = "MATERIAL"
            if hasattr(shading, "color_type"):
                shading.color_type = "OBJECT"


def interval_gap(a_min, a_max, b_min, b_max):
    if a_max < b_min:
        return b_min - a_max
    if b_max < a_min:
        return a_min - b_max
    return 0.0


def interval_overlap(a_min, a_max, b_min, b_max):
    return max(0.0, min(a_max, b_max) - max(a_min, b_min))


def bbox_min_max(world_vertices):
    mins = Vector((math.inf, math.inf, math.inf))
    maxs = Vector((-math.inf, -math.inf, -math.inf))
    for vertex in world_vertices:
        mins.x = min(mins.x, vertex.x)
        mins.y = min(mins.y, vertex.y)
        mins.z = min(mins.z, vertex.z)
        maxs.x = max(maxs.x, vertex.x)
        maxs.y = max(maxs.y, vertex.y)
        maxs.z = max(maxs.z, vertex.z)
    return mins, maxs


def choose_external_cell_size(dims, requested_cell_size, max_voxels=250000):
    requested = max(float(requested_cell_size), 1e-5)
    volume = max(dims.x, EPSILON) * max(dims.y, EPSILON) * max(dims.z, EPSILON)
    minimum_safe = max(0.0025, requested)
    target = max(requested, (volume / max(max_voxels, 1)) ** (1.0 / 3.0))
    return max(minimum_safe, target)


def mesh_volume(mesh):
    if hasattr(mesh, "calc_volume"):
        return abs(mesh.calc_volume(signed=False))
    bm = bmesh.new()
    try:
        bm.from_mesh(mesh)
        return abs(bm.calc_volume(signed=False))
    finally:
        bm.free()


def polygon_world_metrics(mesh):
    centers = []
    normals = []
    areas = []
    for poly in mesh.polygons:
        centers.append(poly.center.copy())
        normals.append(poly.normal.copy().normalized())
        areas.append(poly.area)
    return centers, normals, areas


def object_world_metrics(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    if mesh is None or len(mesh.vertices) == 0:
        if mesh is not None:
            evaluated.to_mesh_clear()
        raise ValueError(f"Object '{obj.name}' has no mesh data to simulate")
    mesh.transform(evaluated.matrix_world)
    area = sum(poly.area for poly in mesh.polygons)
    volume = mesh_volume(mesh) if len(mesh.polygons) else 0.0
    vertices = [vertex.co.copy() for vertex in mesh.vertices]
    face_centers, face_normals, face_areas = polygon_world_metrics(mesh)
    mins, maxs = bbox_min_max(vertices)
    center = (mins + maxs) * 0.5
    evaluated.to_mesh_clear()
    return area, volume, mins, maxs, center, face_centers, face_normals, face_areas


def estimate_contact_area(metrics_a, metrics_b, max_gap):
    mins_a = metrics_a.bbox_min
    maxs_a = metrics_a.bbox_max
    mins_b = metrics_b.bbox_min
    maxs_b = metrics_b.bbox_max
    gaps = (
        interval_gap(mins_a.x, maxs_a.x, mins_b.x, maxs_b.x),
        interval_gap(mins_a.y, maxs_a.y, mins_b.y, maxs_b.y),
        interval_gap(mins_a.z, maxs_a.z, mins_b.z, maxs_b.z),
    )
    if min(gaps) > max_gap:
        return 0.0, None
    axis = gaps.index(min(gaps))
    coarse_other_axes = [0, 1, 2]
    coarse_other_axes.remove(axis)
    coarse_lengths = []
    for component in coarse_other_axes:
        a0 = mins_a[component]
        a1 = maxs_a[component]
        b0 = mins_b[component]
        b1 = maxs_b[component]
        coarse_lengths.append(interval_overlap(a0, a1, b0, b1))
    coarse_area = coarse_lengths[0] * coarse_lengths[1]
    if coarse_area <= EPSILON:
        return 0.0, None

    face_count_a = len(metrics_a.face_areas)
    face_count_b = len(metrics_b.face_areas)
    if face_count_a == 0 or face_count_b == 0:
        return coarse_area, axis

    if face_count_a <= face_count_b:
        source = metrics_a
        target = metrics_b
        source_sign = 1.0
    else:
        source = metrics_b
        target = metrics_a
        source_sign = -1.0

    normal_tolerance = 0.75
    accumulated = 0.0
    for src_center, src_normal, src_area in zip(
        source.face_centers, source.face_normals, source.face_areas
    ):
        best = 0.0
        src_radius = math.sqrt(max(src_area, EPSILON) / math.pi)
        compare_normal = src_normal * source_sign
        for dst_center, dst_normal, dst_area in zip(
            target.face_centers, target.face_normals, target.face_areas
        ):
            alignment = compare_normal.dot(-dst_normal * source_sign)
            if alignment < normal_tolerance:
                continue
            delta = dst_center - src_center
            plane_gap = abs(delta.dot(compare_normal))
            if plane_gap > max_gap:
                continue
            tangential = (delta - compare_normal * delta.dot(compare_normal)).length
            dst_radius = math.sqrt(max(dst_area, EPSILON) / math.pi)
            limit = src_radius + dst_radius
            if tangential > limit:
                continue
            tangential_factor = 1.0 - clamp(tangential / max(limit, EPSILON), 0.0, 1.0)
            gap_factor = 1.0 - clamp(plane_gap / max(max_gap, EPSILON), 0.0, 1.0)
            alignment_factor = clamp(
                (alignment - normal_tolerance) / max(1.0 - normal_tolerance, EPSILON),
                0.0,
                1.0,
            )
            candidate = min(src_area, dst_area) * tangential_factor * gap_factor * alignment_factor
            if candidate > best:
                best = candidate
        accumulated += best

    if accumulated > EPSILON:
        return min(accumulated, coarse_area), axis
    return coarse_area, axis


@dataclass
class ThermalNode:
    name: str
    obj_name: str
    initial_temperature: float
    fixed_temperature: bool
    fixed_temperature_value: float
    internal_heat: float
    convection_h: float
    conductivity: float
    density: float
    specific_heat: float
    emissivity: float
    area: float
    exposed_area: float
    volume: float
    mass: float
    heat_capacity: float
    thickness: float
    core_temperature: float
    surface_temperature: float
    core_heat_capacity: float
    surface_heat_capacity: float
    internal_conductance: float
    bbox_min: Vector
    bbox_max: Vector
    center: Vector
    face_centers: list
    face_normals: list
    face_areas: list


class HeatSimObjectProperties(PropertyGroup):
    enabled: BoolProperty(
        name="Include In Simulation",
        description="Include this object when building the thermal model",
        default=True,
    )
    material_preset: EnumProperty(
        name="Material",
        description="Thermal material preset",
        items=MATERIAL_ITEMS,
        default="ALUMINUM_6061",
    )
    component_preset: EnumProperty(
        name="Component",
        description="Component preset with thermal material and load defaults",
        items=COMPONENT_ITEMS,
        default="GENERIC",
    )
    conductivity: FloatProperty(
        name="Conductivity",
        description="Thermal conductivity in W/mK",
        default=167.0,
        min=0.001,
        soft_max=500.0,
    )
    density: FloatProperty(
        name="Density",
        description="Material density in kg/m^3",
        default=2700.0,
        min=0.1,
        soft_max=15000.0,
    )
    specific_heat: FloatProperty(
        name="Specific Heat",
        description="Specific heat capacity in J/kgK",
        default=896.0,
        min=1.0,
        soft_max=3000.0,
    )
    emissivity: FloatProperty(
        name="Emissivity",
        description="Surface emissivity for radiative losses",
        default=0.09,
        min=0.0,
        max=1.0,
    )
    heat_generation: FloatProperty(
        name="Heat Generation",
        description="Manual constant heat generation in Watts when load profile is disabled",
        default=0.0,
        soft_min=0.0,
        soft_max=150.0,
    )
    use_load_profile: BoolProperty(
        name="Use Load Profile",
        description="Scale dissipated power between idle and max based on the scene load factor",
        default=False,
    )
    idle_power: FloatProperty(
        name="Idle Power",
        description="Power dissipated at 0% scene load in Watts",
        default=0.0,
        min=0.0,
        soft_max=50.0,
    )
    max_power: FloatProperty(
        name="Max Power",
        description="Power dissipated at 100% scene load in Watts",
        default=0.0,
        min=0.0,
        soft_max=150.0,
    )
    current_power: FloatProperty(
        name="Current Power",
        description="Effective power used in the last simulation in Watts",
        default=0.0,
    )
    initial_temperature: FloatProperty(
        name="Initial Temp",
        description="Initial object temperature in C",
        default=25.0,
        soft_min=-50.0,
        soft_max=250.0,
    )
    fixed_temperature: BoolProperty(
        name="Fixed Temperature",
        description="Use this object as a thermal boundary held at a constant temperature",
        default=False,
    )
    fixed_temperature_value: FloatProperty(
        name="Boundary Temp",
        description="Constant boundary temperature in C",
        default=25.0,
        soft_min=-50.0,
        soft_max=250.0,
    )
    convection_h: FloatProperty(
        name="Convection h",
        description="Convective heat transfer coefficient in W/m^2K",
        default=8.0,
        min=0.0,
        soft_max=200.0,
    )
    contact_h: FloatProperty(
        name="Contact h",
        description="Interface conductance in W/m^2K when this part touches another part",
        default=2500.0,
        min=1.0,
        soft_max=25000.0,
    )
    override_thickness: BoolProperty(
        name="Override Thickness",
        description="Use a manual characteristic thickness instead of auto-derived thickness",
        default=False,
    )
    thickness: FloatProperty(
        name="Thickness",
        description="Characteristic conduction thickness in meters",
        default=0.001,
        min=0.00001,
        soft_max=0.05,
        subtype="DISTANCE",
    )
    latest_temperature: FloatProperty(
        name="Latest Temp",
        description="Latest simulated surface temperature in C",
        default=25.0,
    )
    peak_temperature: FloatProperty(
        name="Peak Temp",
        description="Peak simulated maximum temperature in C",
        default=25.0,
    )
    latest_core_temperature: FloatProperty(
        name="Latest Core Temp",
        description="Latest simulated core temperature in C",
        default=25.0,
    )
    latest_surface_temperature: FloatProperty(
        name="Latest Surface Temp",
        description="Latest simulated surface temperature in C",
        default=25.0,
    )
    peak_core_temperature: FloatProperty(
        name="Peak Core Temp",
        description="Peak simulated core temperature in C",
        default=25.0,
    )
    peak_surface_temperature: FloatProperty(
        name="Peak Surface Temp",
        description="Peak simulated surface temperature in C",
        default=25.0,
    )


class HeatSimResultRow(PropertyGroup):
    object_name: StringProperty(name="Object")
    material_name: StringProperty(name="Material")
    initial_temp: FloatProperty(name="Initial Temp")
    final_temp: FloatProperty(name="Final Temp")
    peak_temp: FloatProperty(name="Peak Temp")
    core_temp: FloatProperty(name="Core Temp")
    surface_temp: FloatProperty(name="Surface Temp")
    power: FloatProperty(name="Power")
    mass: FloatProperty(name="Mass")
    heat_capacity: FloatProperty(name="Heat Capacity")


class HeatSimAddonPreferences(AddonPreferences):
    bl_idname = __name__
    server_python_executable: StringProperty(
        name="Server Python",
        description="Path to the external Python executable that hosts the solver server",
        subtype="FILE_PATH",
        default="",
    )
    case_output_dir: StringProperty(
        name="Case Output Folder",
        description="Folder where external solver cases, meshes, sources, and logs will be written",
        subtype="DIR_PATH",
        default="//heat_sim_cases",
    )
    server_host: StringProperty(
        name="Server Host",
        description="Host used by the external solver server",
        default="127.0.0.1",
    )
    server_port: IntProperty(
        name="Server Port",
        description="Port used by the external solver server",
        default=8765,
        min=1,
        max=65535,
    )
    auto_start_server: BoolProperty(
        name="Auto Start Server",
        description="Start the solver server automatically if Blender cannot reach it",
        default=True,
    )
    show_server_console: BoolProperty(
        name="Show Server Console",
        description="Launch the external solver server in a visible console window so logs can be watched live",
        default=True,
    )
    server_python_modules: StringProperty(
        name="Server Modules",
        description="Space-separated Python packages to install into the external solver Python environment",
        default="numpy scipy sfepy trimesh numpy-stl",
    )
    install_status: StringProperty(
        name="Install Status",
        description="Status of the latest server module installation attempt",
        default="Server modules not installed yet",
    )
    last_case_dir: StringProperty(
        name="Last Case",
        description="Last generated external solver case directory",
        default="",
    )

    def draw(self, context):
        layout = self.layout
        layout.label(text="External Solver Integration")
        layout.prop(self, "server_python_executable")
        layout.prop(self, "case_output_dir")
        layout.prop(self, "server_host")
        layout.prop(self, "server_port")
        layout.prop(self, "auto_start_server")
        layout.prop(self, "show_server_console")
        row = layout.row(align=True)
        row.operator("heatsim.start_solver_server", icon="PLAY")
        row.operator("heatsim.check_solver_server", icon="FILE_REFRESH")
        layout.separator()
        layout.label(text="External Server Python Modules")
        layout.prop(self, "server_python_modules")
        row = layout.row(align=True)
        row.operator("heatsim.install_server_modules", icon="IMPORT")
        layout.label(text=self.install_status)
        if self.last_case_dir:
            layout.label(text=f"Last case: {self.last_case_dir}")


def update_result_frame(self, context):
    apply_result_frame(context, self.result_frame)


class HeatSimSceneProperties(PropertyGroup):
    solver_backend: EnumProperty(
        name="Backend",
        description="Solver backend to use from the Heat Sim panel",
        items=SOLVER_BACKEND_ITEMS,
        default="INTERNAL",
    )
    external_case_name: StringProperty(
        name="Case Name",
        description="Base name for generated external solver files",
        default="heat_sim_case",
    )
    sfepy_voxel_size: FloatProperty(
        name="SfePy Cell Size",
        description="Voxel cell size in meters for the SfePy finite-element mesh",
        default=0.0015,
        min=0.0001,
        soft_max=0.02,
        subtype="DISTANCE",
    )
    ambient_temperature: FloatProperty(
        name="Ambient Temp",
        description="Ambient environment temperature in C",
        default=25.0,
        soft_min=-50.0,
        soft_max=120.0,
    )
    load_factor: FloatProperty(
        name="System Load",
        description="Normalized device load from idle (0) to maximum sustained load (1)",
        default=0.5,
        min=0.0,
        max=1.0,
        subtype="FACTOR",
    )
    simulation_time: FloatProperty(
        name="Duration",
        description="Total simulated time in seconds",
        default=120.0,
        min=0.01,
        soft_max=3600.0,
    )
    timestep: FloatProperty(
        name="Base Step",
        description="Requested solver step in seconds before stability adjustment",
        default=0.5,
        min=0.001,
        soft_max=60.0,
    )
    contact_distance: FloatProperty(
        name="Contact Gap",
        description="Maximum gap in meters to treat two parts as thermally connected",
        default=0.0005,
        min=0.0,
        soft_max=0.01,
        subtype="DISTANCE",
    )
    min_thickness: FloatProperty(
        name="Min Thickness",
        description="Floor for automatic characteristic thickness",
        default=0.0005,
        min=0.00001,
        soft_max=0.01,
        subtype="DISTANCE",
    )
    auto_stable_timestep: BoolProperty(
        name="Auto Stable Step",
        description="Shrink the step size automatically when the network becomes stiff",
        default=True,
    )
    max_temp_step: FloatProperty(
        name="Max Temp Step",
        description="Adaptive target for maximum temperature change per integration step in C",
        default=0.35,
        min=0.01,
        soft_max=5.0,
    )
    store_frames: IntProperty(
        name="Stored Frames",
        description="Number of timeline samples stored from the simulation",
        default=120,
        min=2,
        soft_max=2000,
    )
    result_blob: StringProperty(
        name="Result Blob",
        description="Serialized simulation results",
        default="",
        options={"HIDDEN"},
    )
    result_frame: IntProperty(
        name="Preview Frame",
        description="Preview a stored simulation sample",
        default=0,
        min=0,
        update=update_result_frame,
    )
    result_status: StringProperty(
        name="Status",
        description="Latest solver status message",
        default="No simulation run yet",
    )
    sfepy_status: StringProperty(
        name="SfePy Status",
        description="Latest SfePy export or run status",
        default="No SfePy case generated yet",
    )
    sfepy_job_id: StringProperty(
        name="SfePy Job ID",
        description="Current background SfePy server job identifier",
        default="",
        options={"HIDDEN"},
    )
    color_auto_range: BoolProperty(
        name="Auto Color Range",
        description="Use the result temperature span automatically for coloring",
        default=True,
    )
    color_scope: EnumProperty(
        name="Color Scope",
        description="How preview colors are normalized",
        items=COLOR_SCOPE_ITEMS,
        default="RUN",
    )
    preview_temperature_mode: EnumProperty(
        name="Preview Temp",
        description="Which temperature field to preview on the model",
        items=PREVIEW_MODE_ITEMS,
        default="SURFACE",
    )
    color_min: FloatProperty(
        name="Color Min",
        description="Minimum temperature for the heat map in C",
        default=20.0,
    )
    color_max: FloatProperty(
        name="Color Max",
        description="Maximum temperature for the heat map in C",
        default=80.0,
    )
    preview_time: FloatProperty(
        name="Preview Time",
        description="Time of the current preview frame in seconds",
        default=0.0,
    )
    hottest_object: StringProperty(
        name="Hottest Object",
        description="Hottest object in the current preview frame",
        default="",
    )
    coolest_object: StringProperty(
        name="Coolest Object",
        description="Coolest object in the current preview frame",
        default="",
    )
    hottest_temperature: FloatProperty(
        name="Hottest Temp",
        description="Highest temperature in the current preview frame",
        default=0.0,
    )
    coolest_temperature: FloatProperty(
        name="Coolest Temp",
        description="Lowest temperature in the current preview frame",
        default=0.0,
    )
    surface_fraction: FloatProperty(
        name="Surface Layer",
        description="Fraction of object mass treated as the exposed surface thermal layer",
        default=0.12,
        min=0.02,
        max=0.45,
        subtype="FACTOR",
    )


def sync_material_from_preset(target):
    preset = MATERIAL_LIBRARY.get(target.material_preset)
    if preset is None or target.material_preset == "CUSTOM":
        return
    target.conductivity = preset["conductivity"]
    target.density = preset["density"]
    target.specific_heat = preset["specific_heat"]
    target.emissivity = preset["emissivity"]


def sync_component_from_preset(target):
    preset = COMPONENT_LIBRARY.get(target.component_preset)
    if preset is None:
        return
    target.material_preset = preset["material"]
    sync_material_from_preset(target)
    target.idle_power = preset["idle_power"]
    target.max_power = preset["max_power"]
    target.use_load_profile = True
    target.convection_h = preset["convection_h"]
    target.contact_h = preset["contact_h"]


def object_effective_power(props, load_factor):
    if props.use_load_profile:
        return props.idle_power + (props.max_power - props.idle_power) * clamp(load_factor, 0.0, 1.0)
    return props.heat_generation


def export_object_as_stl(context, obj, filepath):
    view_layer = context.view_layer
    previous_active = view_layer.objects.active
    previous_selection = list(context.selected_objects)
    try:
        for selected in previous_selection:
            selected.select_set(False)
        obj.select_set(True)
        view_layer.objects.active = obj
        if hasattr(bpy.ops.wm, "stl_export"):
            result = bpy.ops.wm.stl_export(filepath=filepath, export_selected_objects=True)
        else:
            result = bpy.ops.export_mesh.stl(filepath=filepath, use_selection=True)
        return result
    finally:
        obj.select_set(False)
        for selected in previous_selection:
            if selected.name in bpy.data.objects:
                bpy.data.objects[selected.name].select_set(True)
        view_layer.objects.active = previous_active


def scene_export_objects(scene):
    return [obj for obj in scene.objects if obj.type == "MESH" and obj.heat_sim.enabled]


def build_external_parts(context):
    scene = context.scene
    depsgraph = context.evaluated_depsgraph_get()
    parts = []
    for index, obj in enumerate(scene_export_objects(scene), start=1):
        props = obj.heat_sim
        (
            area,
            volume,
            bbox_min,
            bbox_max,
            center,
            _face_centers,
            _face_normals,
            _face_areas,
        ) = object_world_metrics(obj, depsgraph)
        parts.append(
            {
                "index": index,
                "name": obj.name,
                "tag": safe_tag(obj.name, prefix=f"part{index}"),
                "material_label": MATERIAL_LIBRARY.get(props.material_preset, {}).get(
                    "label", props.material_preset
                ),
                "material_key": props.material_preset,
                "conductivity": props.conductivity,
                "density": props.density,
                "specific_heat": props.specific_heat,
                "emissivity": props.emissivity,
                "power_w": object_effective_power(props, scene.heat_sim.load_factor),
                "initial_temp_c": props.initial_temperature,
                "fixed_temperature": props.fixed_temperature,
                "fixed_temperature_c": props.fixed_temperature_value,
                "convection_h": props.convection_h,
                "contact_h": props.contact_h,
                "override_thickness": props.override_thickness,
                "thickness_m": props.thickness,
                "area_m2": area,
                "volume_m3": max(volume, EPSILON),
                "bbox_min": [bbox_min.x, bbox_min.y, bbox_min.z],
                "bbox_max": [bbox_max.x, bbox_max.y, bbox_max.z],
                "center": [center.x, center.y, center.z],
            }
        )
    return parts


def build_scene_parts(scene):
    parts = []
    for index, obj in enumerate(scene_export_objects(scene), start=1):
        props = obj.heat_sim
        power = object_effective_power(props, scene.heat_sim.load_factor)
        parts.append(
            {
                "index": index,
                "name": obj.name,
                "tag": safe_tag(obj.name, prefix=f"part{index}"),
                "material_label": MATERIAL_LIBRARY.get(props.material_preset, {}).get(
                    "label", props.material_preset
                ),
                "material_key": props.material_preset,
                "conductivity": props.conductivity,
                "density": props.density,
                "specific_heat": props.specific_heat,
                "emissivity": props.emissivity,
                "power_w": power,
                "initial_temp_c": props.initial_temperature,
                "fixed_temperature": props.fixed_temperature,
                "fixed_temperature_c": props.fixed_temperature_value,
                "convection_h": props.convection_h,
                "contact_h": props.contact_h,
                "override_thickness": props.override_thickness,
                "thickness_m": props.thickness,
            }
        )
    return parts


def build_contact_pairs(parts, gap_distance):
    pairs = []
    object_lookup = {part["name"]: bpy.data.objects.get(part["name"]) for part in parts}
    metrics = {}
    for part in parts:
        obj = object_lookup.get(part["name"])
        if obj is None:
            continue
        bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        mins, maxs = bbox_min_max(bbox)
        metrics[part["name"]] = {
            "bbox_min": mins,
            "bbox_max": maxs,
            "face_areas": [],
            "face_centers": [],
            "face_normals": [],
        }
    for left_index in range(len(parts)):
        for right_index in range(left_index + 1, len(parts)):
            left = parts[left_index]
            right = parts[right_index]
            left_metrics = metrics.get(left["name"])
            right_metrics = metrics.get(right["name"])
            if not left_metrics or not right_metrics:
                continue
            contact_area, axis = estimate_contact_area(left_metrics, right_metrics, gap_distance)
            if contact_area <= EPSILON:
                continue
            pairs.append(
                {
                    "left_tag": left["tag"],
                    "right_tag": right["tag"],
                    "contact_area_m2": contact_area,
                    "contact_h": min(left["contact_h"], right["contact_h"]),
                    "axis": axis if axis is not None else 0,
                }
            )
    return pairs


def signed_distance_to_object(obj_eval, point_world):
    local_point = obj_eval.matrix_world.inverted() @ point_world
    success, location, normal, _face_index = obj_eval.closest_point_on_mesh(local_point)
    if not success:
        return math.inf
    delta = local_point - location
    if delta.length <= EPSILON:
        return -0.0
    sign = 1.0 if delta.dot(normal) >= 0.0 else -1.0
    return sign * delta.length


def voxelize_scene_for_sfepy(context, parts, cell_size):
    scene = context.scene
    depsgraph = context.evaluated_depsgraph_get()
    objects = []
    mins = Vector((math.inf, math.inf, math.inf))
    maxs = Vector((-math.inf, -math.inf, -math.inf))
    for part in parts:
        obj = bpy.data.objects.get(part["name"])
        if obj is None:
            continue
        obj_eval = obj.evaluated_get(depsgraph)
        objects.append((part, obj_eval))
        bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        bbox_min, bbox_max = bbox_min_max(bbox)
        mins.x = min(mins.x, bbox_min.x)
        mins.y = min(mins.y, bbox_min.y)
        mins.z = min(mins.z, bbox_min.z)
        maxs.x = max(maxs.x, bbox_max.x)
        maxs.y = max(maxs.y, bbox_max.y)
        maxs.z = max(maxs.z, bbox_max.z)
    if not objects:
        raise RuntimeError("No enabled mesh objects found for SfePy export")

    padding = cell_size * 0.5
    mins -= Vector((padding, padding, padding))
    maxs += Vector((padding, padding, padding))
    dims = maxs - mins
    nx = max(1, math.ceil(dims.x / cell_size))
    ny = max(1, math.ceil(dims.y / cell_size))
    nz = max(1, math.ceil(dims.z / cell_size))
    cell_size_vec = Vector((dims.x / nx, dims.y / ny, dims.z / nz))

    labels = [[[0 for _ in range(nz)] for _ in range(ny)] for _ in range(nx)]
    for ix in range(nx):
        x = mins.x + (ix + 0.5) * cell_size_vec.x
        for iy in range(ny):
            y = mins.y + (iy + 0.5) * cell_size_vec.y
            for iz in range(nz):
                z = mins.z + (iz + 0.5) * cell_size_vec.z
                point = Vector((x, y, z))
                best_part = None
                best_distance = math.inf
                near_part = None
                near_distance = math.inf
                for part, obj_eval in objects:
                    distance = signed_distance_to_object(obj_eval, point)
                    if distance < 0.0 and distance < best_distance:
                        best_distance = distance
                        best_part = part
                    abs_distance = abs(distance)
                    if abs_distance < near_distance:
                        near_distance = abs_distance
                        near_part = part
                if best_part is not None:
                    labels[ix][iy][iz] = best_part["index"]
                elif near_part is not None and near_distance <= min(cell_size_vec) * 0.35:
                    labels[ix][iy][iz] = near_part["index"]

    node_ids = {}
    coors = []
    conn = []
    mat_ids = []

    def get_node(ix, iy, iz):
        key = (ix, iy, iz)
        if key in node_ids:
            return node_ids[key]
        node_ids[key] = len(coors)
        coors.append(
            [
                mins.x + ix * cell_size_vec.x,
                mins.y + iy * cell_size_vec.y,
                mins.z + iz * cell_size_vec.z,
            ]
        )
        return node_ids[key]

    for ix in range(nx):
        for iy in range(ny):
            for iz in range(nz):
                mat_id = labels[ix][iy][iz]
                if mat_id <= 0:
                    continue
                conn.append(
                    [
                        get_node(ix, iy, iz),
                        get_node(ix + 1, iy, iz),
                        get_node(ix + 1, iy + 1, iz),
                        get_node(ix, iy + 1, iz),
                        get_node(ix, iy, iz + 1),
                        get_node(ix + 1, iy, iz + 1),
                        get_node(ix + 1, iy + 1, iz + 1),
                        get_node(ix, iy + 1, iz + 1),
                    ]
                )
                mat_ids.append(mat_id)

    if not conn:
        raise RuntimeError("Voxelization produced no finite elements; reduce SfePy cell size")

    return {
        "coors": coors,
        "conn": conn,
        "mat_ids": mat_ids,
        "bbox_min": [mins.x, mins.y, mins.z],
        "bbox_max": [maxs.x, maxs.y, maxs.z],
        "cell_size": [cell_size_vec.x, cell_size_vec.y, cell_size_vec.z],
        "shape": [nx, ny, nz],
        "ambient_temperature_c": scene.heat_sim.ambient_temperature,
    }


def generate_sfepy_problem(case_name, case_dir, scene_settings, parts):
    mesh_filename = os.path.join(case_dir, f"{case_name}.mesh").replace("\\", "/")
    n_step = max(2, math.ceil(scene_settings.simulation_time / max(scene_settings.timestep, EPSILON)) + 1)
    material_lines = []
    region_lines = ["    'Omega': 'all',", "    'Gamma_Exterior': ('vertices of surface *v r.Omega', 'facet'),"]
    equation_lhs = []
    equation_rhs = ["dw_bc_newton.i.Gamma_Exterior(env.h, env.T_inf, s, T)"]
    ic_lines = []

    for part in parts:
        mat_tag = safe_tag(part["tag"], prefix="mat")
        src_tag = f"src_{mat_tag}"
        region_tag = f"Omega_{mat_tag}"
        group_id = part["index"]
        material_lines.append(
            f"    '{mat_tag}': ({{'lam': {part['conductivity']}, 'rho_cp': {part['density'] * part['specific_heat']}}},),"
        )
        material_lines.append(
            f"    '{src_tag}': ({{'val': {part['power_w'] / max(part['volume_m3'], EPSILON)}}},),"
        )
        region_lines.append(f"    '{region_tag}': 'cells of group {group_id}',")
        equation_lhs.append(
            f"dw_dot.i.{region_tag}({mat_tag}.rho_cp, s, dT/dt ) + dw_laplace.i.{region_tag}({mat_tag}.lam, s, T)"
        )
        if part["power_w"] > EPSILON:
            equation_rhs.append(f"dw_volume_lvf.i.{region_tag}({src_tag}.val, s)")
        ic_temp = part["fixed_temperature_c"] if part["fixed_temperature"] else part["initial_temp_c"]
        ic_lines.append(f"    'ic_{mat_tag}': ('{region_tag}', {{'T.0': {ic_temp}}}),")

    equation_text = " \\\n        + ".join(equation_lhs)
    rhs_text = " \\\n        + ".join(equation_rhs)
    return f'''import os

T0 = {scene_settings.ambient_temperature}
filename_mesh = r"{mesh_filename}"

materials = {{
{chr(10).join(material_lines)}
    'env': ({{'h': -8.0, 'T_inf': T0}},),
}}

regions = {{
{chr(10).join(region_lines)}
}}

fields = {{
    'temperature': ('real', 1, 'Omega', 1),
}}

variables = {{
    'T': ('unknown field', 'temperature', 1, 1),
    's': ('test field', 'temperature', 'T'),
}}

integrals = {{
    'i': 2,
}}

equations = {{
    'Temperature': """
        {equation_text}
        = {rhs_text}
    """
}}

ics = {{
{chr(10).join(ic_lines)}
}}

ebcs = {{
}}

solvers = {{
    'ls': ('ls.auto_direct', {{
        'use_presolve': True,
        'use_mtx_digest': False,
    }}),
    'newton': ('nls.newton', {{
        'i_max': 1,
        'eps_a': 1e-8,
        'is_linear': True,
    }}),
    'ts': ('ts.simple', {{
        't0': 0.0,
        't1': {scene_settings.simulation_time},
        'dt': None,
        'n_step': {n_step},
        'verbose': True,
        'is_linear': True,
    }}),
}}

options = {{
    'output_dir': r"{case_dir.replace("\\", "/")}",
    'output_format': 'vtk',
    'save_results': True,
}}
'''


def generate_sfepy_runner(case_name, case_dir, manifest_path):
    case_dir_text = case_dir.replace("\\", "/")
    manifest_path_text = manifest_path.replace("\\", "/")
    return f'''import json
import math
import numpy as nm
import os
import traceback
from stl import mesh as stl_mesh
from sfepy.applications import solve_pde
from sfepy.discrete.fem import Mesh


def get_node(node_ids, coors, origin, cell_size, ix, iy, iz):
    key = (ix, iy, iz)
    if key in node_ids:
        return node_ids[key]
    node_ids[key] = len(coors)
    coors.append([
        origin[0] + ix * cell_size[0],
        origin[1] + iy * cell_size[1],
        origin[2] + iz * cell_size[2],
    ])
    return node_ids[key]


def write_progress(path, **payload):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def append_log(path, message):
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(message + "\\n")


def load_stl_as_trimesh(path):
    raw = stl_mesh.Mesh.from_file(path)
    triangles = raw.vectors.reshape((-1, 3))
    vertices, inverse = nm.unique(triangles, axis=0, return_inverse=True)
    faces = inverse.reshape((-1, 3))
    mins = triangles.min(axis=0)
    maxs = triangles.max(axis=0)
    return vertices, faces, mins, maxs


case_dir = r"{case_dir_text}"
progress_path = os.path.join(case_dir, "{case_name}_progress.json")
log_path = os.path.join(case_dir, "{case_name}_runner.log")
results_path = os.path.join(case_dir, "{case_name}_results.json")
append_log(log_path, "runner started")
write_progress(progress_path, stage="startup", message="Runner started", percent=0.0)
with open(r"{manifest_path_text}", "r", encoding="utf-8") as _handle:
    manifest = json.load(_handle)
origin = manifest["bbox_min"]
cell_size = manifest["cell_size"]
pitch = float(cell_size[0])
occupied = {{}}
parts = manifest["parts"]

try:
    for index, part in enumerate(parts, start=1):
        write_progress(
            progress_path,
            stage="voxelize",
            message=f"Voxelizing {{part['name']}}",
            percent=0.05 + 0.55 * (index - 1) / max(len(parts), 1),
            part=part["name"],
            current=index,
            total=len(parts),
        )
        append_log(log_path, f"loading mesh {{part['mesh_path']}}")
        vertices, faces, mesh_min, mesh_max = load_stl_as_trimesh(part["mesh_path"])
        append_log(
            log_path,
            f"mesh loaded {{part['name']}} faces={{len(faces)}} vertices={{len(vertices)}}"
        )
        write_progress(
            progress_path,
            stage="voxelize",
            message=f"Voxelizing {{part['name']}}",
            percent=0.05 + 0.55 * (index - 1) / max(len(parts), 1),
            part=part["name"],
            current=index,
            total=len(parts),
            detail="mesh_loaded",
        )
        append_log(log_path, f"voxelizing {{part['name']}} pitch={{pitch}} using bbox occupancy")
        ix0 = int(math.floor((mesh_min[0] - origin[0]) / pitch))
        iy0 = int(math.floor((mesh_min[1] - origin[1]) / pitch))
        iz0 = int(math.floor((mesh_min[2] - origin[2]) / pitch))
        ix1 = int(math.ceil((mesh_max[0] - origin[0]) / pitch))
        iy1 = int(math.ceil((mesh_max[1] - origin[1]) / pitch))
        iz1 = int(math.ceil((mesh_max[2] - origin[2]) / pitch))
        voxel_count = 0
        for ix in range(ix0, ix1 + 1):
            for iy in range(iy0, iy1 + 1):
                for iz in range(iz0, iz1 + 1):
                    occupied[(ix, iy, iz)] = int(part["index"])
                    voxel_count += 1
        append_log(log_path, f"voxelized {{part['name']}} bbox_voxels={{voxel_count}}")

    if not occupied:
        raise RuntimeError("External voxelization produced no finite elements")

    write_progress(
        progress_path,
        stage="mesh_build",
        message="Building SfePy mesh",
        percent=0.7,
        occupied_voxels=len(occupied),
    )
    node_ids = {{}}
    coors = []
    conn = []
    mat_ids = []
    for index, (ix, iy, iz) in enumerate(sorted(occupied.keys()), start=1):
        mat_id = occupied[(ix, iy, iz)]
        conn.append([
            get_node(node_ids, coors, origin, cell_size, ix, iy, iz),
            get_node(node_ids, coors, origin, cell_size, ix + 1, iy, iz),
            get_node(node_ids, coors, origin, cell_size, ix + 1, iy + 1, iz),
            get_node(node_ids, coors, origin, cell_size, ix, iy + 1, iz),
            get_node(node_ids, coors, origin, cell_size, ix, iy, iz + 1),
            get_node(node_ids, coors, origin, cell_size, ix + 1, iy, iz + 1),
            get_node(node_ids, coors, origin, cell_size, ix + 1, iy + 1, iz + 1),
            get_node(node_ids, coors, origin, cell_size, ix, iy + 1, iz + 1),
        ])
        mat_ids.append(mat_id)
        if index % 50000 == 0:
            write_progress(
                progress_path,
                stage="mesh_build",
                message="Building SfePy mesh",
                percent=0.7 + 0.15 * index / max(len(occupied), 1),
                occupied_voxels=len(occupied),
                cells_built=index,
            )

    mesh = Mesh.from_data(
        "{case_name}",
        nm.asarray(coors, dtype=nm.float64),
        None,
        [nm.asarray(conn, dtype=nm.int32)],
        [nm.asarray(mat_ids, dtype=nm.int32)],
        ["3_8"],
    )
    mesh_path = os.path.join(case_dir, "{case_name}.mesh")
    mesh.write(mesh_path, io="auto")
    append_log(log_path, f"mesh written {{mesh_path}}")
    write_progress(progress_path, stage="solve", message="Running SfePy solve", percent=0.9)
    append_log(log_path, "calling solve_pde")
    try:
        problem, state = solve_pde(os.path.join(case_dir, "{case_name}_sfepy_problem.py"))
    except BaseException as exc:
        append_log(log_path, f"solve_pde exited via {{type(exc).__name__}}: {{exc}}")
        append_log(log_path, traceback.format_exc())
        raise
    append_log(
        log_path,
        "solve completed, extracting temperatures "
        f"(problem={{type(problem).__name__}}, state={{'None' if state is None else type(state).__name__}})",
    )
    state_parts = state.get_state_parts()
    temperatures = nm.asarray(state_parts.get("T"))
    if temperatures.ndim > 1:
        temperatures = temperatures.reshape(-1)
    part_by_index = {{int(part["index"]): part for part in parts}}
    region_stats = {{}}
    for cell_nodes, mat_id in zip(conn, mat_ids):
        mat_id = int(mat_id)
        values = [float(temperatures[node_index]) for node_index in cell_nodes]
        region = region_stats.setdefault(
            mat_id,
            {{"sum": 0.0, "count": 0, "min": float("inf"), "max": float("-inf")}},
        )
        cell_avg = sum(values) / max(len(values), 1)
        region["sum"] += cell_avg
        region["count"] += 1
        region["min"] = min(region["min"], min(values))
        region["max"] = max(region["max"], max(values))

    part_results = []
    for part in parts:
        stats = region_stats.get(int(part["index"]))
        if stats is None or stats["count"] <= 0:
            avg_temp = float(manifest.get("ambient_temperature_c", 25.0))
            min_temp = avg_temp
            max_temp = avg_temp
        else:
            avg_temp = stats["sum"] / stats["count"]
            min_temp = stats["min"]
            max_temp = stats["max"]
        part_results.append(
            {{
                "index": int(part["index"]),
                "name": part["name"],
                "material": part.get("material_label", part.get("material_key", "")),
                "final_temp_c": float(avg_temp),
                "surface_temp_c": float(avg_temp),
                "core_temp_c": float(max_temp),
                "peak_temp_c": float(max_temp),
                "min_temp_c": float(min_temp),
                "max_temp_c": float(max_temp),
                "power_w": float(part.get("power_w", 0.0)),
                "mass_proxy": float(part.get("density", 0.0) * part.get("volume_m3", 0.0)),
                "heat_capacity_proxy": float(
                    part.get("density", 0.0) * part.get("volume_m3", 0.0) * part.get("specific_heat", 0.0)
                ),
            }}
        )

    with open(results_path, "w", encoding="utf-8") as handle:
        json.dump(
            {{
                "case_name": manifest["case_name"],
                "ambient_temperature_c": manifest.get("ambient_temperature_c", 25.0),
                "time_s": manifest.get("duration_s", 0.0),
                "parts": part_results,
            }},
            handle,
            indent=2,
        )
    append_log(log_path, f"results written {{results_path}}")
    write_progress(progress_path, stage="done", message="Solve completed", percent=1.0)
    append_log(log_path, "runner completed")
except BaseException as exc:
    append_log(log_path, f"runner failed: {{exc}}")
    append_log(log_path, traceback.format_exc())
    write_progress(progress_path, stage="error", message=str(exc), percent=1.0)
    raise
'''


class SfePyCaseBuildJob:
    def __init__(self, context):
        scene = context.scene
        settings = scene.heat_sim
        prefs = addon_preferences(context)
        if prefs is None:
            raise RuntimeError("Add-on preferences are not available")
        self.context = context
        self.scene = scene
        self.settings = settings
        self.prefs = prefs
        self.output_root = ensure_directory(bpy.path.abspath(prefs.case_output_dir))
        self.case_name = safe_tag(settings.external_case_name or "heat_sim_case", prefix="case")
        self.case_dir = ensure_directory(os.path.join(self.output_root, self.case_name + "_sfepy"))
        self.parts = build_external_parts(context)
        self.objects = []
        mins = Vector((math.inf, math.inf, math.inf))
        maxs = Vector((-math.inf, -math.inf, -math.inf))
        for part in self.parts:
            obj = bpy.data.objects.get(part["name"])
            if obj is None:
                continue
            self.objects.append((part, obj))
            bbox_min = Vector(part["bbox_min"])
            bbox_max = Vector(part["bbox_max"])
            mins.x = min(mins.x, bbox_min.x)
            mins.y = min(mins.y, bbox_min.y)
            mins.z = min(mins.z, bbox_min.z)
            maxs.x = max(maxs.x, bbox_max.x)
            maxs.y = max(maxs.y, bbox_max.y)
            maxs.z = max(maxs.z, bbox_max.z)
        if not self.objects:
            raise RuntimeError("No enabled mesh objects found for SfePy export")

        cell_size = settings.sfepy_voxel_size
        padding = cell_size * 0.5
        mins -= Vector((padding, padding, padding))
        maxs += Vector((padding, padding, padding))
        dims = maxs - mins
        self.requested_cell_size = cell_size
        self.effective_cell_size = choose_external_cell_size(dims, cell_size)
        self.nx = max(1, math.ceil(dims.x / self.effective_cell_size))
        self.ny = max(1, math.ceil(dims.y / self.effective_cell_size))
        self.nz = max(1, math.ceil(dims.z / self.effective_cell_size))
        self.mins = mins
        self.maxs = maxs
        self.cell_size_vec = Vector((dims.x / self.nx, dims.y / self.ny, dims.z / self.nz))
        self.mesh_dir = ensure_directory(os.path.join(self.case_dir, "meshes"))
        self.phase = "export_meshes"
        self.export_index = 0
        self.total_exports = len(self.objects)
        self.status = (
            f"Exporting 0/{self.total_exports} mesh files "
            f"(requested {self.requested_cell_size:.4f} m, using {self.cell_size_vec.x:.4f} m)"
        )

    def progress(self):
        if self.phase == "export_meshes":
            return 0.8 * (self.export_index / max(self.total_exports, 1))
        if self.phase == "write":
            return 0.9
        if self.phase == "submit_ready":
            return 0.95
        if self.phase == "write":
            return 0.95
        if self.phase == "done":
            return 1.0
        return 0.0

    def step(self, max_seconds=0.03, max_cells=128):
        if self.phase == "export_meshes":
            return self._step_export_meshes()
        if self.phase == "write":
            return self._write_outputs()
        return True

    def _step_export_meshes(self):
        if self.export_index >= self.total_exports:
            self.phase = "write"
            self.status = "Writing solver manifest"
            return False
        part, obj = self.objects[self.export_index]
        mesh_path = os.path.join(self.mesh_dir, f"{part['tag']}.stl")
        result = export_object_as_stl(self.context, obj, mesh_path)
        if "FINISHED" not in result:
            raise RuntimeError(f"Failed to export mesh for {obj.name}")
        part["mesh_path"] = mesh_path.replace("\\", "/")
        self.export_index += 1
        self.status = (
            f"Exporting {self.export_index}/{self.total_exports} mesh files "
            f"(using {self.cell_size_vec.x:.4f} m cells)"
        )
        return False

    def _write_outputs(self):
        metadata = {
            "case_name": self.case_name,
            "ambient_temperature_c": self.settings.ambient_temperature,
            "load_factor": self.settings.load_factor,
            "timestep_s": self.settings.timestep,
            "duration_s": self.settings.simulation_time,
            "parts": self.parts,
            "voxel_shape": [self.nx, self.ny, self.nz],
            "voxel_cell_size_m": [
                self.cell_size_vec.x,
                self.cell_size_vec.y,
                self.cell_size_vec.z,
            ],
            "bbox_min": [self.mins.x, self.mins.y, self.mins.z],
            "bbox_max": [self.maxs.x, self.maxs.y, self.maxs.z],
            "cell_size": [self.cell_size_vec.x, self.cell_size_vec.y, self.cell_size_vec.z],
            "requested_cell_size": self.requested_cell_size,
            "effective_cell_size": self.cell_size_vec.x,
        }
        manifest_path = os.path.join(self.case_dir, f"{self.case_name}_manifest.json")
        with open(manifest_path, "w", encoding="utf-8") as handle:
            json.dump(metadata, handle, indent=2)
        problem_path = os.path.join(self.case_dir, f"{self.case_name}_sfepy_problem.py")
        with open(problem_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(generate_sfepy_problem(self.case_name, self.case_dir, self.settings, self.parts))
        runner_path = os.path.join(self.case_dir, f"{self.case_name}_sfepy_run.py")
        with open(runner_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(generate_sfepy_runner(self.case_name, self.case_dir, manifest_path))
        self.prefs.last_case_dir = self.case_dir
        self.result = {
            "case_dir": self.case_dir,
            "case_name": self.case_name,
            "metadata_path": manifest_path,
            "problem_path": problem_path,
            "runner_path": runner_path,
            "results_path": os.path.join(self.case_dir, f"{self.case_name}_results.json"),
        }
        self.phase = "done"
        self.status = f"Generated SfePy case in {self.case_dir}"
        return True


def create_sfepy_case(context):
    scene = context.scene
    settings = scene.heat_sim
    prefs = addon_preferences(context)
    if prefs is None:
        raise RuntimeError("Add-on preferences are not available")
    output_root = ensure_directory(bpy.path.abspath(prefs.case_output_dir))
    case_name = safe_tag(settings.external_case_name or "heat_sim_case", prefix="case")
    case_dir = ensure_directory(os.path.join(output_root, case_name + "_sfepy"))
    parts = build_external_parts(context)
    voxel_data = voxelize_scene_for_sfepy(context, parts, settings.sfepy_voxel_size)
    metadata = {
        "case_name": case_name,
        "ambient_temperature_c": settings.ambient_temperature,
        "load_factor": settings.load_factor,
        "timestep_s": settings.timestep,
        "duration_s": settings.simulation_time,
        "parts": parts,
        "voxel_shape": voxel_data["shape"],
        "voxel_cell_size_m": voxel_data["cell_size"],
    }
    metadata_path = os.path.join(case_dir, f"{case_name}_sfepy.json")
    with open(metadata_path, "w", encoding="utf-8") as handle:
        json.dump(metadata, handle, indent=2)
    voxel_path = os.path.join(case_dir, f"{case_name}_voxel_mesh.json.gz")
    with gzip.open(voxel_path, "wt", encoding="utf-8") as handle:
        json.dump(
            {
                "coors": voxel_data["coors"],
                "conn": voxel_data["conn"],
                "mat_ids": voxel_data["mat_ids"],
            },
            handle,
        )
    problem_path = os.path.join(case_dir, f"{case_name}_sfepy_problem.py")
    with open(problem_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(generate_sfepy_problem(case_name, case_dir, settings, parts))
    runner_path = os.path.join(case_dir, f"{case_name}_sfepy_run.py")
    with open(runner_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(generate_sfepy_runner(case_name, case_dir, voxel_path))
    prefs.last_case_dir = case_dir
    settings.sfepy_status = f"Generated SfePy case in {case_dir}"
    return {
        "case_dir": case_dir,
        "case_name": case_name,
        "metadata_path": metadata_path,
        "voxel_path": voxel_path,
        "problem_path": problem_path,
        "runner_path": runner_path,
    }


class InternalSimulationJob:
    def __init__(self, context):
        scene = context.scene
        settings = scene.heat_sim
        depsgraph = context.evaluated_depsgraph_get()
        self.context = context
        self.scene = scene
        self.settings = settings
        self.nodes = []
        mesh_objects = [
            obj for obj in scene.objects if obj.type == "MESH" and obj.heat_sim.enabled
        ]
        if not mesh_objects:
            raise RuntimeError("No enabled mesh objects found")

        for obj in mesh_objects:
            props = obj.heat_sim
            try:
                (
                    area,
                    volume,
                    bbox_min,
                    bbox_max,
                    center,
                    face_centers,
                    face_normals,
                    face_areas,
                ) = object_world_metrics(obj, depsgraph)
            except ValueError:
                continue
            if area <= EPSILON:
                continue
            thickness = (
                props.thickness
                if props.override_thickness
                else max(volume / max(area * 0.5, EPSILON), settings.min_thickness)
            )
            volume = max(volume, thickness * area * 0.5)
            mass = max(props.density * volume, EPSILON)
            heat_capacity = max(mass * props.specific_heat, EPSILON)
            surface_fraction = clamp(settings.surface_fraction, 0.02, 0.45)
            surface_mass = max(mass * surface_fraction, EPSILON)
            core_mass = max(mass - surface_mass, EPSILON)
            core_heat_capacity = max(core_mass * props.specific_heat, EPSILON)
            surface_heat_capacity = max(surface_mass * props.specific_heat, EPSILON)
            internal_area = max(area * 0.5, EPSILON)
            internal_path = max(thickness * 0.5, settings.min_thickness * 0.5)
            internal_conductance = max(
                props.conductivity * internal_area / max(internal_path, EPSILON), EPSILON
            )
            initial_temp = (
                props.fixed_temperature_value
                if props.fixed_temperature
                else props.initial_temperature
            )
            self.nodes.append(
                ThermalNode(
                    name=obj.name,
                    obj_name=obj.name,
                    initial_temperature=props.initial_temperature,
                    fixed_temperature=props.fixed_temperature,
                    fixed_temperature_value=props.fixed_temperature_value,
                    internal_heat=object_effective_power(props, settings.load_factor),
                    convection_h=props.convection_h,
                    conductivity=max(props.conductivity, EPSILON),
                    density=props.density,
                    specific_heat=props.specific_heat,
                    emissivity=props.emissivity,
                    area=area,
                    exposed_area=area,
                    volume=volume,
                    mass=mass,
                    heat_capacity=heat_capacity,
                    thickness=max(thickness, settings.min_thickness),
                    core_temperature=initial_temp,
                    surface_temperature=initial_temp,
                    core_heat_capacity=core_heat_capacity,
                    surface_heat_capacity=surface_heat_capacity,
                    internal_conductance=internal_conductance,
                    bbox_min=bbox_min,
                    bbox_max=bbox_max,
                    center=center,
                    face_centers=face_centers,
                    face_normals=face_normals,
                    face_areas=face_areas,
                )
            )
        if not self.nodes:
            raise RuntimeError("No valid mesh objects were available for simulation")

        self.connections = []
        for left_index in range(len(self.nodes)):
            for right_index in range(left_index + 1, len(self.nodes)):
                left = self.nodes[left_index]
                right = self.nodes[right_index]
                contact_area, _axis = estimate_contact_area(
                    left, right, settings.contact_distance
                )
                if contact_area <= EPSILON:
                    continue
                props_left = bpy.data.objects[left.obj_name].heat_sim
                props_right = bpy.data.objects[right.obj_name].heat_sim
                interface_h = min(props_left.contact_h, props_right.contact_h)
                conductance = contact_area * max(interface_h, EPSILON)
                if conductance <= EPSILON:
                    continue
                self.connections.append((left_index, right_index, conductance, contact_area))
                left.exposed_area = max(0.0, left.exposed_area - (contact_area * 0.5))
                right.exposed_area = max(0.0, right.exposed_area - (contact_area * 0.5))

        self.base_dt = settings.timestep
        if settings.auto_stable_timestep:
            max_ratio = 0.0
            ambient_linearized = 4.0 * SIGMA * max((settings.ambient_temperature + 273.15) ** 3, EPSILON)
            for index, node in enumerate(self.nodes):
                surface_g = (
                    node.convection_h * node.exposed_area
                    + node.emissivity * ambient_linearized * node.exposed_area
                    + node.internal_conductance
                )
                core_g = node.internal_conductance
                for left_idx, right_idx, conductance, _contact_area in self.connections:
                    if left_idx == index or right_idx == index:
                        surface_g += conductance
                if surface_g > EPSILON:
                    max_ratio = max(max_ratio, surface_g / node.surface_heat_capacity)
                if core_g > EPSILON:
                    max_ratio = max(max_ratio, core_g / node.core_heat_capacity)
            if max_ratio > EPSILON:
                stable_dt = 0.2 / max_ratio
                self.base_dt = min(self.base_dt, stable_dt)

        self.duration = settings.simulation_time
        self.steps = max(1, math.ceil(self.duration / max(self.base_dt, EPSILON)))
        self.storage_count = min(settings.store_frames, self.steps + 1)
        self.storage_stride = max(1, math.floor(self.steps / max(self.storage_count - 1, 1)))
        self.ambient_k = settings.ambient_temperature + 273.15
        self.frames = []
        self.global_min = math.inf
        self.global_max = -math.inf
        self.peak_core_by_object = [node.core_temperature for node in self.nodes]
        self.peak_surface_by_object = [node.surface_temperature for node in self.nodes]
        self.sim_time = 0.0
        self.step_index = 0
        self.status = f"Prepared {len(self.nodes)} parts, {len(self.connections)} contacts"
        self.record_frame(0, 0.0)

    def progress(self):
        return self.sim_time / max(self.duration, EPSILON)

    def record_frame(self, step_index, sim_time):
        core_temps = [node.core_temperature for node in self.nodes]
        surface_temps = [node.surface_temperature for node in self.nodes]
        temps = [max(core, surface) for core, surface in zip(core_temps, surface_temps)]
        self.global_min = min(self.global_min, min(temps))
        self.global_max = max(self.global_max, max(temps))
        self.frames.append(
            {
                "step": step_index,
                "time": sim_time,
                "core_temps": core_temps,
                "surface_temps": surface_temps,
                "temps": temps,
            }
        )

    def step(self, max_seconds=0.03, max_iterations=8):
        deadline = time.perf_counter() + max_seconds
        iterations = 0
        while self.sim_time < self.duration - EPSILON and iterations < max_iterations and time.perf_counter() < deadline:
            dt = min(self.base_dt, self.duration - self.sim_time)
            if dt <= 0.0:
                break

            current_core_temps = [node.core_temperature for node in self.nodes]
            current_surface_temps = [node.surface_temperature for node in self.nodes]
            while True:
                net_core_heat_0, net_surface_heat_0 = compute_net_heat_for_state(
                    self.nodes,
                    self.connections,
                    self.settings.ambient_temperature,
                    self.ambient_k,
                    current_core_temps,
                    current_surface_temps,
                )
                predicted_core = []
                predicted_surface = []
                max_change = 0.0
                for index, node in enumerate(self.nodes):
                    if node.fixed_temperature:
                        predicted_core.append(node.fixed_temperature_value)
                        predicted_surface.append(node.fixed_temperature_value)
                        continue
                    core_delta = (net_core_heat_0[index] * dt) / node.core_heat_capacity
                    surface_delta = (net_surface_heat_0[index] * dt) / node.surface_heat_capacity
                    predicted_core.append(current_core_temps[index] + core_delta)
                    predicted_surface.append(current_surface_temps[index] + surface_delta)
                    max_change = max(max_change, abs(core_delta), abs(surface_delta))
                if dt <= EPSILON or max_change <= self.settings.max_temp_step:
                    break
                dt *= 0.5

            net_core_heat_1, net_surface_heat_1 = compute_net_heat_for_state(
                self.nodes,
                self.connections,
                self.settings.ambient_temperature,
                self.ambient_k,
                predicted_core,
                predicted_surface,
            )
            for index, node in enumerate(self.nodes):
                if node.fixed_temperature:
                    node.core_temperature = node.fixed_temperature_value
                    node.surface_temperature = node.fixed_temperature_value
                else:
                    core_delta_0 = (net_core_heat_0[index] * dt) / node.core_heat_capacity
                    surface_delta_0 = (net_surface_heat_0[index] * dt) / node.surface_heat_capacity
                    core_delta_1 = (net_core_heat_1[index] * dt) / node.core_heat_capacity
                    surface_delta_1 = (net_surface_heat_1[index] * dt) / node.surface_heat_capacity
                    node.core_temperature = current_core_temps[index] + 0.5 * (core_delta_0 + core_delta_1)
                    node.surface_temperature = current_surface_temps[index] + 0.5 * (
                        surface_delta_0 + surface_delta_1
                    )
                self.peak_core_by_object[index] = max(self.peak_core_by_object[index], node.core_temperature)
                self.peak_surface_by_object[index] = max(
                    self.peak_surface_by_object[index], node.surface_temperature
                )

            self.sim_time += dt
            self.step_index += 1
            iterations += 1
            if (
                self.step_index == 1
                or self.step_index % self.storage_stride == 0
                or self.sim_time >= self.duration - EPSILON
            ):
                if len(self.frames) < self.storage_count or self.sim_time >= self.duration - EPSILON:
                    self.record_frame(self.step_index, self.sim_time)
            self.status = (
                f"Solving {self.step_index}/{self.steps} steps "
                f"({100.0 * self.progress():.1f}%)"
            )

        return self.sim_time >= self.duration - EPSILON

    def finalize(self):
        clear_result_rows(self.scene)
        object_names = []
        summary = []
        for index, node in enumerate(self.nodes):
            object_names.append(node.obj_name)
            obj = bpy.data.objects.get(node.obj_name)
            final_max_temp = max(node.core_temperature, node.surface_temperature)
            peak_max_temp = max(
                self.peak_core_by_object[index], self.peak_surface_by_object[index]
            )
            if obj:
                obj.heat_sim.latest_temperature = node.surface_temperature
                obj.heat_sim.peak_temperature = peak_max_temp
                obj.heat_sim.latest_surface_temperature = node.surface_temperature
                obj.heat_sim.latest_core_temperature = node.core_temperature
                obj.heat_sim.peak_surface_temperature = self.peak_surface_by_object[index]
                obj.heat_sim.peak_core_temperature = self.peak_core_by_object[index]
                obj.heat_sim.current_power = node.internal_heat
            row = self.scene.heat_sim_results.add()
            row.object_name = node.obj_name
            preset_key = bpy.data.objects[node.obj_name].heat_sim.material_preset
            row.material_name = MATERIAL_LIBRARY.get(preset_key, {}).get("label", preset_key)
            row.initial_temp = node.initial_temperature
            row.final_temp = final_max_temp
            row.peak_temp = peak_max_temp
            row.core_temp = node.core_temperature
            row.surface_temp = node.surface_temperature
            row.power = node.internal_heat
            row.mass = node.mass
            row.heat_capacity = node.heat_capacity
            summary.append(
                {
                    "object": node.obj_name,
                    "initial_temp": node.initial_temperature,
                    "final_temp": final_max_temp,
                    "peak_temp": peak_max_temp,
                    "core_temp": node.core_temperature,
                    "surface_temp": node.surface_temperature,
                    "power": node.internal_heat,
                    "mass": node.mass,
                    "heat_capacity": node.heat_capacity,
                }
            )

        self.scene.heat_sim.result_blob = json.dumps(
            {
                "objects": object_names,
                "frames": self.frames,
                "summary": summary,
                "min_temp": self.global_min,
                "max_temp": self.global_max,
            }
        )
        self.settings.result_frame = len(self.frames) - 1
        apply_result_frame(self.context, self.settings.result_frame)
        set_preferred_viewport(self.context)
        self.settings.result_status = (
            f"Solved {len(self.nodes)} parts, {len(self.connections)} contacts, "
            f"{len(self.frames)} stored frames at {self.settings.load_factor * 100:.0f}% load, "
            f"final range {self.global_min:.1f}C to {self.global_max:.1f}C"
        )


def selected_mesh_objects(context):
    return [obj for obj in context.selected_objects if obj.type == "MESH"]


def active_mesh_object(context):
    obj = context.object
    if obj and obj.type == "MESH":
        return obj
    return None


def clear_result_rows(scene):
    scene.heat_sim_results.clear()


def load_results(scene):
    blob = scene.heat_sim.result_blob
    if not blob:
        return None
    try:
        return json.loads(blob)
    except json.JSONDecodeError:
        return None


def import_external_results(context, results_path):
    if not os.path.isfile(results_path):
        raise RuntimeError(f"External results file not found: {results_path}")
    with open(results_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    parts = payload.get("parts", [])
    if not parts:
        raise RuntimeError("External results file contained no part data")

    scene = context.scene
    settings = scene.heat_sim
    clear_result_rows(scene)
    object_names = []
    summary = []
    surface_temps = []
    core_temps = []
    preview_temps = []
    for part in parts:
        name = part["name"]
        object_names.append(name)
        surface_temp = float(part.get("surface_temp_c", part.get("final_temp_c", 25.0)))
        core_temp = float(part.get("core_temp_c", part.get("peak_temp_c", surface_temp)))
        peak_temp = float(part.get("peak_temp_c", max(surface_temp, core_temp)))
        preview_temps.append(max(surface_temp, core_temp))
        surface_temps.append(surface_temp)
        core_temps.append(core_temp)

        obj = bpy.data.objects.get(name)
        if obj is not None:
            props = obj.heat_sim
            props.latest_temperature = surface_temp
            props.peak_temperature = peak_temp
            props.latest_surface_temperature = surface_temp
            props.latest_core_temperature = core_temp
            props.peak_surface_temperature = max(props.peak_surface_temperature, surface_temp)
            props.peak_core_temperature = max(props.peak_core_temperature, core_temp)
            props.current_power = float(part.get("power_w", 0.0))

        row = scene.heat_sim_results.add()
        row.object_name = name
        row.material_name = part.get("material", "")
        row.initial_temp = float(payload.get("ambient_temperature_c", 25.0))
        row.final_temp = float(part.get("final_temp_c", surface_temp))
        row.peak_temp = peak_temp
        row.core_temp = core_temp
        row.surface_temp = surface_temp
        row.power = float(part.get("power_w", 0.0))
        row.mass = float(part.get("mass_proxy", 0.0))
        row.heat_capacity = float(part.get("heat_capacity_proxy", 0.0))

        summary.append(
            {
                "object": name,
                "initial_temp": float(payload.get("ambient_temperature_c", 25.0)),
                "final_temp": float(part.get("final_temp_c", surface_temp)),
                "peak_temp": peak_temp,
                "core_temp": core_temp,
                "surface_temp": surface_temp,
                "power": float(part.get("power_w", 0.0)),
                "mass": float(part.get("mass_proxy", 0.0)),
                "heat_capacity": float(part.get("heat_capacity_proxy", 0.0)),
            }
        )

    results = {
        "objects": object_names,
        "frames": [
            {
                "step": 1,
                "time": float(payload.get("time_s", 0.0)),
                "core_temps": core_temps,
                "surface_temps": surface_temps,
                "temps": preview_temps,
            }
        ],
        "summary": summary,
        "min_temp": min(preview_temps),
        "max_temp": max(preview_temps),
    }
    scene.heat_sim.result_blob = json.dumps(results)
    settings.result_frame = 0
    apply_result_frame(context, 0)
    set_preferred_viewport(context)
    settings.result_status = (
        f"Imported external FEA results for {len(parts)} parts, "
        f"range {min(preview_temps):.1f}C to {max(preview_temps):.1f}C"
    )


def apply_result_frame(context, frame_index):
    scene = context.scene
    settings = scene.heat_sim
    results = load_results(scene)
    if not results:
        return
    frames = results.get("frames", [])
    object_names = results.get("objects", [])
    if not frames or not object_names:
        return
    frame_index = clamp(frame_index, 0, len(frames) - 1)
    frame = frames[frame_index]
    min_temp, max_temp = preview_range(settings, results, frame_index)
    if settings.color_auto_range or settings.color_scope != "MANUAL":
        settings.color_min = min_temp
        settings.color_max = max_temp
    preview_temps = frame_mode_temperatures(frame, settings.preview_temperature_mode)
    core_temps = frame.get("core_temps", preview_temps)
    surface_temps = frame.get("surface_temps", preview_temps)
    for name, temperature, core_temp, surface_temp in zip(
        object_names, preview_temps, core_temps, surface_temps
    ):
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        apply_preview_color(obj, heat_color(temperature, min_temp, max_temp))
        props = obj.heat_sim
        props.latest_temperature = surface_temp
        props.latest_surface_temperature = surface_temp
        props.latest_core_temperature = core_temp
    stats = frame_temperature_stats(results, frame_index, settings.preview_temperature_mode)
    if stats:
        settings.preview_time = stats["time"]
        settings.hottest_object = stats["hottest_name"]
        settings.coolest_object = stats["coolest_name"]
        settings.hottest_temperature = stats["hottest_temp"]
        settings.coolest_temperature = stats["coolest_temp"]


def compute_net_heat_for_state(
    nodes,
    connections,
    ambient_temperature,
    ambient_k,
    core_temps,
    surface_temps,
):
    net_core_heat = [node.internal_heat for node in nodes]
    net_surface_heat = [0.0 for _node in nodes]
    for index, node in enumerate(nodes):
        delta = surface_temps[index] - core_temps[index]
        q_internal = node.internal_conductance * delta
        net_core_heat[index] += q_internal
        net_surface_heat[index] -= q_internal
    for left_idx, right_idx, conductance, _contact_area in connections:
        delta = surface_temps[right_idx] - surface_temps[left_idx]
        q = conductance * delta
        net_surface_heat[left_idx] += q
        net_surface_heat[right_idx] -= q
    for index, node in enumerate(nodes):
        if node.fixed_temperature:
            continue
        q_conv = node.convection_h * node.exposed_area * (
            ambient_temperature - surface_temps[index]
        )
        surface_k = surface_temps[index] + 273.15
        q_rad = (
            node.emissivity
            * SIGMA
            * node.exposed_area
            * (ambient_k**4 - surface_k**4)
        )
        net_surface_heat[index] += q_conv + q_rad
    return net_core_heat, net_surface_heat


class HEATSIM_OT_apply_material_preset(Operator):
    bl_idname = "heatsim.apply_material_preset"
    bl_label = "Apply Material"
    bl_description = "Apply the chosen thermal material preset to selected mesh objects"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        active = active_mesh_object(context)
        objects = selected_mesh_objects(context)
        if not objects:
            self.report({"WARNING"}, "Select at least one mesh object")
            return {"CANCELLED"}
        if active is None:
            self.report({"WARNING"}, "Active object must be a mesh")
            return {"CANCELLED"}
        source = active.heat_sim
        for obj in objects:
            props = obj.heat_sim
            props.material_preset = source.material_preset
            sync_material_from_preset(props)
        self.report({"INFO"}, f"Applied material preset to {len(objects)} object(s)")
        return {"FINISHED"}


class HEATSIM_OT_apply_component_preset(Operator):
    bl_idname = "heatsim.apply_component_preset"
    bl_label = "Apply Component"
    bl_description = "Apply the active object's component preset to selected mesh objects"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        active = active_mesh_object(context)
        objects = selected_mesh_objects(context)
        if not objects:
            self.report({"WARNING"}, "Select at least one mesh object")
            return {"CANCELLED"}
        if active is None:
            self.report({"WARNING"}, "Active object must be a mesh")
            return {"CANCELLED"}
        source = active.heat_sim
        for obj in objects:
            props = obj.heat_sim
            props.component_preset = source.component_preset
            sync_component_from_preset(props)
        self.report({"INFO"}, f"Applied component preset to {len(objects)} object(s)")
        return {"FINISHED"}


class HEATSIM_OT_sync_active_material(Operator):
    bl_idname = "heatsim.sync_active_material"
    bl_label = "Sync Preset"
    bl_description = (
        "Copy preset values into the active object's thermal material fields"
    )
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = active_mesh_object(context)
        if obj is None:
            self.report({"WARNING"}, "Active object must be a mesh")
            return {"CANCELLED"}
        sync_material_from_preset(obj.heat_sim)
        self.report({"INFO"}, f"Synchronized preset for '{obj.name}'")
        return {"FINISHED"}


class HEATSIM_OT_sync_active_component(Operator):
    bl_idname = "heatsim.sync_active_component"
    bl_label = "Sync Component"
    bl_description = "Copy component preset defaults into the active object's thermal and power fields"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = active_mesh_object(context)
        if obj is None:
            self.report({"WARNING"}, "Active object must be a mesh")
            return {"CANCELLED"}
        sync_component_from_preset(obj.heat_sim)
        self.report({"INFO"}, f"Synchronized component preset for '{obj.name}'")
        return {"FINISHED"}


class HEATSIM_OT_install_server_modules(Operator):
    bl_idname = "heatsim.install_server_modules"
    bl_label = "Install Server Modules"
    bl_description = "Install solver modules into the external Python environment used by the server"
    bl_options = {"REGISTER"}

    def execute(self, context):
        prefs = addon_preferences(context)
        if prefs is None:
            self.report({"ERROR"}, "Add-on preferences are unavailable")
            return {"CANCELLED"}
        python_executable = bpy.path.abspath(prefs.server_python_executable)
        if not python_executable:
            prefs.install_status = "Set Server Python in the add-on preferences first"
            self.report({"ERROR"}, prefs.install_status)
            return {"CANCELLED"}
        packages = [item.strip() for item in prefs.server_python_modules.split() if item.strip()]
        if not packages:
            prefs.install_status = "No server modules were requested"
            self.report({"WARNING"}, prefs.install_status)
            return {"CANCELLED"}
        try:
            subprocess.run(
                [python_executable, "-m", "ensurepip", "--upgrade"],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                [python_executable, "-m", "pip", "install", "--upgrade", *packages],
                check=True,
                capture_output=True,
                text=True,
            )
        except OSError as exc:
            prefs.install_status = str(exc)
            self.report({"ERROR"}, prefs.install_status)
            return {"CANCELLED"}
        except subprocess.CalledProcessError as exc:
            prefs.install_status = exc.stderr.strip() or exc.stdout.strip() or str(exc)
            self.report({"ERROR"}, "Server module installation failed")
            return {"CANCELLED"}
        prefs.install_status = f"Installed: {' '.join(packages)}"
        self.report({"INFO"}, prefs.install_status)
        return {"FINISHED"}


class HEATSIM_OT_start_solver_server(Operator):
    bl_idname = "heatsim.start_solver_server"
    bl_label = "Start Solver Server"
    bl_description = "Launch the external solver server with the configured Python environment"
    bl_options = {"REGISTER"}

    def execute(self, context):
        prefs = addon_preferences(context)
        if prefs is None:
            self.report({"ERROR"}, "Add-on preferences are unavailable")
            return {"CANCELLED"}
        try:
            launch_solver_server(prefs)
        except Exception as exc:
            prefs.install_status = str(exc)
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}
        prefs.install_status = f"Solver server launch requested at {server_base_url(prefs)}"
        self.report({"INFO"}, prefs.install_status)
        return {"FINISHED"}


class HEATSIM_OT_check_solver_server(Operator):
    bl_idname = "heatsim.check_solver_server"
    bl_label = "Check Solver Server"
    bl_description = "Check whether the external solver server is reachable"
    bl_options = {"REGISTER"}

    def execute(self, context):
        prefs = addon_preferences(context)
        if prefs is None:
            self.report({"ERROR"}, "Add-on preferences are unavailable")
            return {"CANCELLED"}
        status = solver_server_health(prefs)
        if status is None:
            prefs.install_status = f"Solver server not reachable at {server_base_url(prefs)}"
            self.report({"WARNING"}, prefs.install_status)
            return {"CANCELLED"}
        if not status.get("solver_ready", False):
            module_errors = status.get("module_errors", {})
            prefs.install_status = (
                f"Solver server online but not ready at {server_base_url(prefs)} "
                f"(missing: {', '.join(module_errors.keys()) or 'unknown'})"
            )
            self.report({"WARNING"}, prefs.install_status)
            return {"CANCELLED"}
        prefs.install_status = (
            f"Solver server online at {server_base_url(prefs)} "
            f"(status={status.get('last_status', 'unknown')})"
        )
        self.report({"INFO"}, prefs.install_status)
        return {"FINISHED"}


class HEATSIM_OT_export_sfepy_case(Operator):
    bl_idname = "heatsim.export_sfepy_case"
    bl_label = "Export SfePy Case"
    bl_description = "Generate a voxelized SfePy finite-element case from the current Blender scene"
    bl_options = {"REGISTER"}

    def execute(self, context):
        try:
            case_info = create_sfepy_case(context)
        except Exception as exc:
            context.scene.heat_sim.sfepy_status = str(exc)
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}
        context.scene.heat_sim.sfepy_status = f"SfePy case exported to {case_info['case_dir']}"
        self.report({"INFO"}, context.scene.heat_sim.sfepy_status)
        return {"FINISHED"}


class HEATSIM_OT_run_sfepy_case(Operator):
    bl_idname = "heatsim.run_sfepy_case"
    bl_label = "Run SfePy Server Solve"
    bl_description = "Generate the SfePy case and submit it to the external solver server"
    bl_options = {"REGISTER"}

    _timer = None
    _phase = "idle"
    _case_info = None
    _case_job = None
    _started_at = 0.0
    _job_id = ""
    _server_launch_attempted = False

    def _finish(self, context):
        if self._timer is not None:
            context.window_manager.event_timer_remove(self._timer)
            self._timer = None
        self._phase = "idle"
        self._case_info = None
        self._case_job = None
        self._started_at = 0.0
        self._job_id = ""
        self._server_launch_attempted = False

    def modal(self, context, event):
        if event.type != "TIMER":
            return {"PASS_THROUGH"}

        prefs = addon_preferences(context)
        settings = context.scene.heat_sim
        if prefs is None:
            settings.sfepy_status = "Add-on preferences are unavailable"
            context.window_manager.progress_end()
            self.report({"ERROR"}, settings.sfepy_status)
            self._finish(context)
            return {"CANCELLED"}

        elapsed = time.time() - self._started_at
        if self._phase == "build_case":
            try:
                done = self._case_job.step(max_seconds=0.02, max_cells=64)
            except Exception as exc:
                settings.sfepy_status = str(exc)
                context.window_manager.progress_end()
                self.report({"ERROR"}, str(exc))
                self._finish(context)
                return {"CANCELLED"}
            context.window_manager.progress_update(self._case_job.progress())
            settings.sfepy_status = self._case_job.status
            if not done:
                return {"RUNNING_MODAL"}
            self._case_info = self._case_job.result
            settings.sfepy_status = f"Submitting {self._case_info['case_name']} to solver server"
            self._phase = "wait_server"
            return {"RUNNING_MODAL"}

        if self._phase == "wait_server":
            status = solver_server_health(prefs)
            if status is None:
                if prefs.auto_start_server and elapsed <= 15.0 and not self._server_launch_attempted:
                    self._server_launch_attempted = True
                    try:
                        launch_solver_server(prefs)
                    except Exception:
                        pass
                if elapsed > 15.0:
                    settings.sfepy_status = f"SfePy server not reachable at {server_base_url(prefs)}"
                    context.window_manager.progress_end()
                    self.report({"ERROR"}, settings.sfepy_status)
                    self._finish(context)
                    return {"CANCELLED"}
                settings.sfepy_status = f"Waiting for SfePy server... {elapsed:.1f}s"
                return {"RUNNING_MODAL"}
            if not status.get("solver_ready"):
                missing = ", ".join((status.get("module_errors") or {}).keys()) or "unknown"
                settings.sfepy_status = f"SfePy server online but not ready: missing {missing}"
                context.window_manager.progress_end()
                self.report({"ERROR"}, settings.sfepy_status)
                self._finish(context)
                return {"CANCELLED"}
            try:
                response = http_json(
                    "POST",
                    server_base_url(prefs) + "/solve",
                    {
                        "case_dir": self._case_info["case_dir"],
                        "runner_path": self._case_info["runner_path"],
                        "case_name": self._case_info["case_name"],
                    },
                    timeout=10.0,
                )
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, RuntimeError) as exc:
                payload = getattr(exc, "payload", None)
                if isinstance(payload, dict) and payload.get("message"):
                    settings.sfepy_status = f"SfePy server request failed: {payload['message']}"
                else:
                    settings.sfepy_status = f"SfePy server request failed: {exc}"
                context.window_manager.progress_end()
                self.report({"ERROR"}, settings.sfepy_status)
                self._finish(context)
                return {"CANCELLED"}
            if response.get("status") != "accepted":
                settings.sfepy_status = response.get("message", "SfePy server solve failed")
                context.window_manager.progress_end()
                self.report({"ERROR"}, settings.sfepy_status)
                self._finish(context)
                return {"CANCELLED"}
            self._job_id = response.get("job_id", "")
            settings.sfepy_job_id = self._job_id
            settings.sfepy_status = f"SfePy solve queued (job {self._job_id[:8]})"
            self._phase = "wait_job"
            return {"RUNNING_MODAL"}

        if self._phase == "wait_job":
            if not self._job_id:
                settings.sfepy_status = "SfePy solve lost its job id"
                context.window_manager.progress_end()
                self.report({"ERROR"}, settings.sfepy_status)
                self._finish(context)
                return {"CANCELLED"}
            job = solver_server_job_status(prefs, self._job_id)
            if job is None:
                settings.sfepy_status = f"Waiting for job {self._job_id[:8]}... server not responding"
                return {"RUNNING_MODAL"}
            job_status = job.get("status", "unknown")
            message = job.get("message", "Working")
            if job_status in {"queued", "running"}:
                tail = job.get("log_tail") or []
                suffix = f" | {tail[-1]}" if tail else ""
                settings.sfepy_status = f"SfePy {job_status}: {message}{suffix}"
                return {"RUNNING_MODAL"}
            settings.sfepy_job_id = ""
            log_path = job.get("log_path", "")
            if job_status == "ok":
                results_path = self._case_info.get("results_path", "")
                if results_path:
                    try:
                        import_external_results(context, results_path)
                    except Exception as exc:
                        settings.sfepy_status = f"SfePy solve completed but results import failed: {exc}"
                        context.window_manager.progress_end()
                        self.report({"ERROR"}, settings.sfepy_status)
                        self._finish(context)
                        return {"CANCELLED"}
                settings.sfepy_status = (
                    f"SfePy solve completed{f', see {log_path}' if log_path else ''}"
                )
                context.window_manager.progress_end()
                self.report({"INFO"}, settings.sfepy_status)
                self._finish(context)
                return {"FINISHED"}
            settings.sfepy_status = message
            context.window_manager.progress_end()
            self.report({"ERROR"}, message)
            self._finish(context)
            return {"CANCELLED"}

        return {"RUNNING_MODAL"}

    def cancel(self, context):
        context.scene.heat_sim.sfepy_job_id = ""
        context.window_manager.progress_end()
        self._finish(context)

    def execute(self, context):
        prefs = addon_preferences(context)
        if prefs is None:
            self.report({"ERROR"}, "Add-on preferences are unavailable")
            return {"CANCELLED"}
        try:
            self._case_job = SfePyCaseBuildJob(context)
        except Exception as exc:
            context.scene.heat_sim.sfepy_status = str(exc)
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}

        self._case_info = None
        self._started_at = time.time()
        self._job_id = ""
        self._server_launch_attempted = False
        self._phase = "build_case"
        context.scene.heat_sim.sfepy_status = self._case_job.status
        wm = context.window_manager
        wm.progress_begin(0.0, 1.0)
        self._timer = wm.event_timer_add(0.5, window=context.window)
        wm.modal_handler_add(self)
        return {"RUNNING_MODAL"}


class HEATSIM_OT_run_simulation(Operator):
    bl_idname = "heatsim.run_simulation"
    bl_label = "Run Heat Simulation"
    bl_description = (
        "Build a thermal network from the scene and run a transient heat simulation"
    )
    bl_options = {"REGISTER"}

    def execute(self, context):
        scene = context.scene
        settings = scene.heat_sim
        if settings.solver_backend == "SFEPY_SERVER":
            return bpy.ops.heatsim.run_sfepy_case()
        depsgraph = context.evaluated_depsgraph_get()
        nodes = []
        mesh_objects = [
            obj for obj in scene.objects if obj.type == "MESH" and obj.heat_sim.enabled
        ]
        if not mesh_objects:
            self.report({"WARNING"}, "No enabled mesh objects found")
            return {"CANCELLED"}

        for obj in mesh_objects:
            props = obj.heat_sim
            try:
                (
                    area,
                    volume,
                    bbox_min,
                    bbox_max,
                    center,
                    face_centers,
                    face_normals,
                    face_areas,
                ) = object_world_metrics(obj, depsgraph)
            except ValueError as exc:
                self.report({"WARNING"}, str(exc))
                continue
            if area <= EPSILON:
                self.report(
                    {"WARNING"}, f"Object '{obj.name}' has no measurable surface area"
                )
                continue
            thickness = (
                props.thickness
                if props.override_thickness
                else max(volume / max(area * 0.5, EPSILON), settings.min_thickness)
            )
            volume = max(volume, thickness * area * 0.5)
            mass = max(props.density * volume, EPSILON)
            heat_capacity = max(mass * props.specific_heat, EPSILON)
            surface_fraction = clamp(settings.surface_fraction, 0.02, 0.45)
            surface_mass = max(mass * surface_fraction, EPSILON)
            core_mass = max(mass - surface_mass, EPSILON)
            core_heat_capacity = max(core_mass * props.specific_heat, EPSILON)
            surface_heat_capacity = max(surface_mass * props.specific_heat, EPSILON)
            internal_area = max(area * 0.5, EPSILON)
            internal_path = max(thickness * 0.5, settings.min_thickness * 0.5)
            internal_conductance = max(
                props.conductivity * internal_area / max(internal_path, EPSILON), EPSILON
            )
            initial_temp = (
                props.fixed_temperature_value
                if props.fixed_temperature
                else props.initial_temperature
            )
            nodes.append(
                ThermalNode(
                    name=obj.name,
                    obj_name=obj.name,
                    initial_temperature=props.initial_temperature,
                    fixed_temperature=props.fixed_temperature,
                    fixed_temperature_value=props.fixed_temperature_value,
                    internal_heat=object_effective_power(props, settings.load_factor),
                    convection_h=props.convection_h,
                    conductivity=max(props.conductivity, EPSILON),
                    density=props.density,
                    specific_heat=props.specific_heat,
                    emissivity=props.emissivity,
                    area=area,
                    exposed_area=area,
                    volume=volume,
                    mass=mass,
                    heat_capacity=heat_capacity,
                    thickness=max(thickness, settings.min_thickness),
                    core_temperature=initial_temp,
                    surface_temperature=initial_temp,
                    core_heat_capacity=core_heat_capacity,
                    surface_heat_capacity=surface_heat_capacity,
                    internal_conductance=internal_conductance,
                    bbox_min=bbox_min,
                    bbox_max=bbox_max,
                    center=center,
                    face_centers=face_centers,
                    face_normals=face_normals,
                    face_areas=face_areas,
                )
            )

        if len(nodes) == 0:
            self.report(
                {"ERROR"}, "No valid mesh objects were available for simulation"
            )
            return {"CANCELLED"}

        connections = []
        for left_index in range(len(nodes)):
            for right_index in range(left_index + 1, len(nodes)):
                left = nodes[left_index]
                right = nodes[right_index]
                contact_area, _axis = estimate_contact_area(
                    left, right, settings.contact_distance
                )
                if contact_area <= EPSILON:
                    continue
                props_left = bpy.data.objects[left.obj_name].heat_sim
                props_right = bpy.data.objects[right.obj_name].heat_sim
                interface_h = min(props_left.contact_h, props_right.contact_h)
                conductance = contact_area * max(interface_h, EPSILON)
                if conductance <= EPSILON:
                    continue
                connections.append((left_index, right_index, conductance, contact_area))
                left.exposed_area = max(0.0, left.exposed_area - (contact_area * 0.5))
                right.exposed_area = max(0.0, right.exposed_area - (contact_area * 0.5))

        base_dt = settings.timestep
        if settings.auto_stable_timestep:
            max_ratio = 0.0
            ambient_linearized = 4.0 * SIGMA * max((settings.ambient_temperature + 273.15) ** 3, EPSILON)
            for index, node in enumerate(nodes):
                surface_g = (
                    node.convection_h * node.exposed_area
                    + node.emissivity * ambient_linearized * node.exposed_area
                    + node.internal_conductance
                )
                core_g = node.internal_conductance
                for left_idx, right_idx, conductance, _contact_area in connections:
                    if left_idx == index or right_idx == index:
                        surface_g += conductance
                if surface_g > EPSILON:
                    max_ratio = max(max_ratio, surface_g / node.surface_heat_capacity)
                if core_g > EPSILON:
                    max_ratio = max(max_ratio, core_g / node.core_heat_capacity)
            if max_ratio > EPSILON:
                stable_dt = 0.2 / max_ratio
                base_dt = min(base_dt, stable_dt)

        duration = settings.simulation_time
        steps = max(1, math.ceil(duration / max(base_dt, EPSILON)))
        storage_count = min(settings.store_frames, steps + 1)
        storage_stride = max(1, math.floor(steps / max(storage_count - 1, 1)))

        ambient_k = settings.ambient_temperature + 273.15
        frames = []
        global_min = math.inf
        global_max = -math.inf
        peak_core_by_object = [node.core_temperature for node in nodes]
        peak_surface_by_object = [node.surface_temperature for node in nodes]

        def record_frame(step_index, sim_time):
            nonlocal global_min, global_max
            core_temps = [node.core_temperature for node in nodes]
            surface_temps = [node.surface_temperature for node in nodes]
            temps = [max(core, surface) for core, surface in zip(core_temps, surface_temps)]
            global_min = min(global_min, min(temps))
            global_max = max(global_max, max(temps))
            frames.append(
                {
                    "step": step_index,
                    "time": sim_time,
                    "core_temps": core_temps,
                    "surface_temps": surface_temps,
                    "temps": temps,
                }
            )

        record_frame(0, 0.0)
        sim_time = 0.0
        step_index = 0
        while sim_time < duration - EPSILON:
            dt = min(base_dt, duration - sim_time)
            if dt <= 0.0:
                break

            current_core_temps = [node.core_temperature for node in nodes]
            current_surface_temps = [node.surface_temperature for node in nodes]
            while True:
                net_core_heat_0, net_surface_heat_0 = compute_net_heat_for_state(
                    nodes,
                    connections,
                    settings.ambient_temperature,
                    ambient_k,
                    current_core_temps,
                    current_surface_temps,
                )
                predicted_core = []
                predicted_surface = []
                max_change = 0.0
                for index, node in enumerate(nodes):
                    if node.fixed_temperature:
                        predicted_core.append(node.fixed_temperature_value)
                        predicted_surface.append(node.fixed_temperature_value)
                        continue
                    core_delta = (net_core_heat_0[index] * dt) / node.core_heat_capacity
                    surface_delta = (net_surface_heat_0[index] * dt) / node.surface_heat_capacity
                    predicted_core.append(current_core_temps[index] + core_delta)
                    predicted_surface.append(current_surface_temps[index] + surface_delta)
                    max_change = max(
                        max_change,
                        abs(core_delta),
                        abs(surface_delta),
                    )
                if dt <= EPSILON or max_change <= settings.max_temp_step:
                    break
                dt *= 0.5

            net_core_heat_1, net_surface_heat_1 = compute_net_heat_for_state(
                nodes,
                connections,
                settings.ambient_temperature,
                ambient_k,
                predicted_core,
                predicted_surface,
            )
            for index, node in enumerate(nodes):
                if node.fixed_temperature:
                    node.core_temperature = node.fixed_temperature_value
                    node.surface_temperature = node.fixed_temperature_value
                else:
                    core_delta_0 = (net_core_heat_0[index] * dt) / node.core_heat_capacity
                    surface_delta_0 = (net_surface_heat_0[index] * dt) / node.surface_heat_capacity
                    core_delta_1 = (net_core_heat_1[index] * dt) / node.core_heat_capacity
                    surface_delta_1 = (net_surface_heat_1[index] * dt) / node.surface_heat_capacity
                    node.core_temperature = current_core_temps[index] + 0.5 * (
                        core_delta_0 + core_delta_1
                    )
                    node.surface_temperature = current_surface_temps[index] + 0.5 * (
                        surface_delta_0 + surface_delta_1
                    )
                peak_core_by_object[index] = max(
                    peak_core_by_object[index], node.core_temperature
                )
                peak_surface_by_object[index] = max(
                    peak_surface_by_object[index], node.surface_temperature
                )

            sim_time += dt
            step_index += 1
            if step_index == 1 or step_index % storage_stride == 0 or sim_time >= duration - EPSILON:
                if len(frames) < storage_count or sim_time >= duration - EPSILON:
                    record_frame(step_index, sim_time)

        clear_result_rows(scene)
        object_names = []
        summary = []
        for index, node in enumerate(nodes):
            object_names.append(node.obj_name)
            obj = bpy.data.objects.get(node.obj_name)
            final_max_temp = max(node.core_temperature, node.surface_temperature)
            peak_max_temp = max(
                peak_core_by_object[index], peak_surface_by_object[index]
            )
            if obj:
                obj.heat_sim.latest_temperature = node.surface_temperature
                obj.heat_sim.peak_temperature = peak_max_temp
                obj.heat_sim.latest_surface_temperature = node.surface_temperature
                obj.heat_sim.latest_core_temperature = node.core_temperature
                obj.heat_sim.peak_surface_temperature = peak_surface_by_object[index]
                obj.heat_sim.peak_core_temperature = peak_core_by_object[index]
                obj.heat_sim.current_power = node.internal_heat
            row = scene.heat_sim_results.add()
            row.object_name = node.obj_name
            preset_key = bpy.data.objects[node.obj_name].heat_sim.material_preset
            row.material_name = MATERIAL_LIBRARY.get(preset_key, {}).get(
                "label", preset_key
            )
            row.initial_temp = node.initial_temperature
            row.final_temp = final_max_temp
            row.peak_temp = peak_max_temp
            row.core_temp = node.core_temperature
            row.surface_temp = node.surface_temperature
            row.power = node.internal_heat
            row.mass = node.mass
            row.heat_capacity = node.heat_capacity
            summary.append(
                {
                    "object": node.obj_name,
                    "initial_temp": node.initial_temperature,
                    "final_temp": final_max_temp,
                    "peak_temp": peak_max_temp,
                    "core_temp": node.core_temperature,
                    "surface_temp": node.surface_temperature,
                    "power": node.internal_heat,
                    "mass": node.mass,
                    "heat_capacity": node.heat_capacity,
                }
            )

        scene.heat_sim.result_blob = json.dumps(
            {
                "objects": object_names,
                "frames": frames,
                "summary": summary,
                "min_temp": global_min,
                "max_temp": global_max,
            }
        )
        settings.result_frame = len(frames) - 1
        apply_result_frame(context, settings.result_frame)
        set_preferred_viewport(context)
        settings.result_status = (
            f"Solved {len(nodes)} parts, {len(connections)} contacts, "
            f"{len(frames)} stored frames at {settings.load_factor * 100:.0f}% load, "
            f"final range {global_min:.1f}C to {global_max:.1f}C"
        )
        self.report({"INFO"}, settings.result_status)
        return {"FINISHED"}


class HEATSIM_OT_preview_frame(Operator):
    bl_idname = "heatsim.preview_frame"
    bl_label = "Refresh Preview"
    bl_description = "Apply the stored heat-map colors for the current preview frame"
    bl_options = {"REGISTER"}

    def execute(self, context):
        apply_result_frame(context, context.scene.heat_sim.result_frame)
        return {"FINISHED"}


class HEATSIM_OT_prepare_viewport(Operator):
    bl_idname = "heatsim.prepare_viewport"
    bl_label = "Set Preview View"
    bl_description = "Switch 3D viewports to a heat-map friendly preview setup"
    bl_options = {"REGISTER"}

    def execute(self, context):
        set_preferred_viewport(context)
        self.report({"INFO"}, "Viewport set to material preview with object colors")
        return {"FINISHED"}


class HEATSIM_OT_export_csv(Operator, ExportHelper):
    bl_idname = "heatsim.export_csv"
    bl_label = "Export CSV"
    bl_description = "Export the latest heat simulation summary to CSV"

    filename_ext = ".csv"
    filter_glob: StringProperty(default="*.csv", options={"HIDDEN"})

    def execute(self, context):
        results = load_results(context.scene)
        if not results:
            self.report({"WARNING"}, "No simulation results available to export")
            return {"CANCELLED"}
        with open(self.filepath, "w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(
                [
                    "object",
                    "initial_temp_c",
                    "final_temp_c",
                    "peak_temp_c",
                    "core_temp_c",
                    "surface_temp_c",
                    "power_w",
                    "mass_kg",
                    "heat_capacity_j_per_k",
                ]
            )
            for row in results.get("summary", []):
                writer.writerow(
                    [
                        row["object"],
                        row["initial_temp"],
                        row["final_temp"],
                        row["peak_temp"],
                        row.get("core_temp", row["final_temp"]),
                        row.get("surface_temp", row["final_temp"]),
                        row.get("power", 0.0),
                        row["mass"],
                        row["heat_capacity"],
                    ]
                )
        self.report({"INFO"}, f"Exported CSV to {self.filepath}")
        return {"FINISHED"}


class HEATSIM_PT_main_panel(Panel):
    bl_label = "Heat Sim"
    bl_idname = "HEATSIM_PT_main_panel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Heat Sim"

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        settings = scene.heat_sim
        obj = active_mesh_object(context)

        solver_box = layout.box()
        solver_box.label(text="Solver")
        solver_box.prop(settings, "solver_backend")
        if settings.solver_backend == "SFEPY_SERVER":
            solver_box.prop(settings, "external_case_name")
        solver_box.prop(settings, "ambient_temperature")
        solver_box.prop(settings, "load_factor")
        solver_box.prop(settings, "simulation_time")
        solver_box.prop(settings, "timestep")
        solver_box.prop(settings, "contact_distance")
        solver_box.prop(settings, "min_thickness")
        solver_box.prop(settings, "surface_fraction")
        solver_box.prop(settings, "max_temp_step")
        solver_box.prop(settings, "auto_stable_timestep")
        solver_box.prop(settings, "store_frames")
        if settings.solver_backend == "SFEPY_SERVER":
            solver_box.prop(settings, "sfepy_voxel_size")
            row = solver_box.row(align=True)
            row.operator("heatsim.export_sfepy_case", icon="EXPORT")
            row.operator("heatsim.run_sfepy_case", icon="MOD_PHYSICS")
            solver_box.label(text=settings.sfepy_status)
        else:
            solver_box.operator("heatsim.run_simulation", icon="MOD_PHYSICS")
        solver_box.label(text=settings.result_status)

        preview_box = layout.box()
        preview_box.label(text="Preview")
        preview_box.prop(settings, "result_frame")
        preview_box.prop(settings, "color_auto_range")
        preview_box.prop(settings, "color_scope")
        preview_box.prop(settings, "preview_temperature_mode")
        row = preview_box.row(align=True)
        row.enabled = (not settings.color_auto_range) or settings.color_scope == "MANUAL"
        row.prop(settings, "color_min")
        row.prop(settings, "color_max")
        preview_box.label(text=f"Time: {settings.preview_time:.1f} s")
        if settings.hottest_object:
            preview_box.label(
                text=f"Hot: {settings.hottest_object} {settings.hottest_temperature:.1f} C"
            )
        if settings.coolest_object:
            preview_box.label(
                text=f"Cool: {settings.coolest_object} {settings.coolest_temperature:.1f} C"
            )
        preview_box.operator("heatsim.preview_frame", icon="HIDE_OFF")
        preview_box.operator("heatsim.prepare_viewport", icon="SHADING_TEXTURE")
        preview_box.operator("heatsim.export_csv", icon="EXPORT")

        if obj is None:
            layout.label(text="Select a mesh object to edit thermal properties")
            return

        props = obj.heat_sim
        material_box = layout.box()
        material_box.label(text=f"Active Object: {obj.name}")
        material_box.prop(props, "enabled")
        material_box.prop(props, "component_preset")
        row = material_box.row(align=True)
        row.operator("heatsim.sync_active_component", icon="FILE_REFRESH")
        row.operator("heatsim.apply_component_preset", icon="CHECKMARK")
        material_box.prop(props, "material_preset")
        row = material_box.row(align=True)
        row.operator("heatsim.sync_active_material", icon="FILE_REFRESH")
        row.operator("heatsim.apply_material_preset", icon="CHECKMARK")
        material_box.prop(props, "conductivity")
        material_box.prop(props, "density")
        material_box.prop(props, "specific_heat")
        material_box.prop(props, "emissivity")

        source_box = layout.box()
        source_box.label(text="Boundary And Loads")
        source_box.prop(props, "use_load_profile")
        if props.use_load_profile:
            source_box.prop(props, "idle_power")
            source_box.prop(props, "max_power")
            source_box.label(
                text=f"Effective power at current load: {object_effective_power(props, settings.load_factor):.2f} W"
            )
        else:
            source_box.prop(props, "heat_generation")
        source_box.prop(props, "initial_temperature")
        source_box.prop(props, "fixed_temperature")
        temp_row = source_box.row()
        temp_row.enabled = props.fixed_temperature
        temp_row.prop(props, "fixed_temperature_value")
        source_box.prop(props, "convection_h")
        source_box.prop(props, "contact_h")

        geometry_box = layout.box()
        geometry_box.label(text="Geometry Model")
        geometry_box.prop(props, "override_thickness")
        thickness_row = geometry_box.row()
        thickness_row.enabled = props.override_thickness
        thickness_row.prop(props, "thickness")
        geometry_box.label(text=f"Surface: {props.latest_surface_temperature:.2f} C")
        geometry_box.label(text=f"Core: {props.latest_core_temperature:.2f} C")
        geometry_box.label(text=f"Peak Surface: {props.peak_surface_temperature:.2f} C")
        geometry_box.label(text=f"Peak Core: {props.peak_core_temperature:.2f} C")
        geometry_box.label(text=f"Peak Max: {props.peak_temperature:.2f} C")
        geometry_box.label(text=f"Power: {props.current_power:.2f} W")

        if scene.heat_sim_results:
            results_box = layout.box()
            results_box.label(text="Latest Results")
            for index, row in enumerate(scene.heat_sim_results):
                if index >= 8:
                    break
                results_box.label(
                    text=f"{row.object_name}: surf {row.surface_temp:.1f} C, core {row.core_temp:.1f} C"
                )


classes = (
    HeatSimAddonPreferences,
    HeatSimObjectProperties,
    HeatSimResultRow,
    HeatSimSceneProperties,
    HEATSIM_OT_apply_material_preset,
    HEATSIM_OT_apply_component_preset,
    HEATSIM_OT_sync_active_material,
    HEATSIM_OT_sync_active_component,
    HEATSIM_OT_install_server_modules,
    HEATSIM_OT_start_solver_server,
    HEATSIM_OT_check_solver_server,
    HEATSIM_OT_export_sfepy_case,
    HEATSIM_OT_run_sfepy_case,
    HEATSIM_OT_run_simulation,
    HEATSIM_OT_preview_frame,
    HEATSIM_OT_prepare_viewport,
    HEATSIM_OT_export_csv,
    HEATSIM_PT_main_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Object.heat_sim = PointerProperty(type=HeatSimObjectProperties)
    bpy.types.Scene.heat_sim = PointerProperty(type=HeatSimSceneProperties)
    bpy.types.Scene.heat_sim_results = CollectionProperty(type=HeatSimResultRow)


def unregister():
    del bpy.types.Scene.heat_sim_results
    del bpy.types.Scene.heat_sim
    del bpy.types.Object.heat_sim
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
