import json
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
        handle.write(message + "\n")


def load_stl_bounds(path):
    raw = stl_mesh.Mesh.from_file(path)
    triangles = raw.vectors.reshape((-1, 3))
    mins = triangles.min(axis=0)
    maxs = triangles.max(axis=0)
    return mins, maxs, len(raw.vectors)


case_dir = r"O:/unlim8ted-phone/3d/heat_sim_cases/heat_sim_full_sfepy"
progress_path = os.path.join(case_dir, "heat_sim_full_progress.json")
log_path = os.path.join(case_dir, "heat_sim_full_runner.log")
results_path = os.path.join(case_dir, "heat_sim_full_results.json")

append_log(log_path, "runner started")
with open(r"O:/unlim8ted-phone/3d/heat_sim_cases/heat_sim_full_sfepy/heat_sim_full_manifest.json", "r", encoding="utf-8") as _handle:
    manifest = json.load(_handle)
origin = manifest["bbox_min"]
cell_size = manifest["cell_size"]
requested_pitch = float(cell_size[0])
pitch = max(requested_pitch, 0.004)
parts = manifest["parts"]
occupied = {}

write_progress(
    progress_path,
    stage="startup",
    message="Runner started",
    percent=0.0,
    requested_pitch=requested_pitch,
    effective_pitch=pitch,
)
append_log(log_path, f"requested pitch={requested_pitch}")
append_log(log_path, f"effective pitch={pitch}")

try:
    for index, part in enumerate(parts, start=1):
        write_progress(
            progress_path,
            stage="voxelize",
            message=f"Voxelizing {part['name']}",
            percent=0.05 + 0.55 * (index - 1) / max(len(parts), 1),
            part=part["name"],
            current=index,
            total=len(parts),
        )
        append_log(log_path, f"loading mesh {part['mesh_path']}")
        mesh_min, mesh_max, tri_count = load_stl_bounds(part["mesh_path"])
        append_log(log_path, f"mesh loaded {part['name']} triangles={tri_count}")
        append_log(log_path, f"voxelizing {part['name']} pitch={pitch} using bbox occupancy")
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
        append_log(log_path, f"voxelized {part['name']} bbox_voxels={voxel_count}")

    if not occupied:
        raise RuntimeError("External voxelization produced no finite elements")

    write_progress(
        progress_path,
        stage="mesh_build",
        message="Building SfePy mesh",
        percent=0.7,
        occupied_voxels=len(occupied),
    )
    node_ids = {}
    coors = []
    conn = []
    mat_ids = []
    for build_index, (ix, iy, iz) in enumerate(sorted(occupied.keys()), start=1):
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
        if build_index % 50000 == 0:
            write_progress(
                progress_path,
                stage="mesh_build",
                message="Building SfePy mesh",
                percent=0.7 + 0.15 * build_index / max(len(occupied), 1),
                occupied_voxels=len(occupied),
                cells_built=build_index,
            )

    mesh = Mesh.from_data(
        "heat_sim_full",
        nm.asarray(coors, dtype=nm.float64),
        None,
        [nm.asarray(conn, dtype=nm.int32)],
        [nm.asarray(mat_ids, dtype=nm.int32)],
        ["3_8"],
    )
    mesh_path = os.path.join(case_dir, "heat_sim_full.mesh")
    mesh.write(mesh_path, io="auto")
    append_log(log_path, f"mesh written {mesh_path}")

    write_progress(progress_path, stage="solve", message="Running SfePy solve", percent=0.9)
    append_log(log_path, "calling solve_pde")
    try:
        problem, state = solve_pde(os.path.join(case_dir, "heat_sim_full_sfepy_problem.py"))
    except BaseException as exc:
        append_log(log_path, f"solve_pde exited via {type(exc).__name__}: {exc}")
        append_log(log_path, traceback.format_exc())
        raise
    append_log(
        log_path,
        "solve completed, extracting temperatures "
        f"(problem={type(problem).__name__}, state={'None' if state is None else type(state).__name__})",
    )

    state_parts = state.get_state_parts()
    temperatures = nm.asarray(state_parts.get("T"))
    if temperatures.ndim > 1:
        temperatures = temperatures.reshape(-1)

    region_stats = {}
    for cell_nodes, mat_id in zip(conn, mat_ids):
        mat_id = int(mat_id)
        values = [float(temperatures[node_index]) for node_index in cell_nodes]
        region = region_stats.setdefault(
            mat_id,
            {"sum": 0.0, "count": 0, "min": float("inf"), "max": float("-inf")},
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
            {
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
            }
        )

    with open(results_path, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "case_name": manifest["case_name"],
                "ambient_temperature_c": manifest.get("ambient_temperature_c", 25.0),
                "time_s": manifest.get("duration_s", 0.0),
                "parts": part_results,
            },
            handle,
            indent=2,
        )
    append_log(log_path, f"results written {results_path}")
    write_progress(progress_path, stage="done", message="Solve completed", percent=1.0)
    append_log(log_path, "runner completed")
except BaseException as exc:
    append_log(log_path, f"runner failed: {exc}")
    append_log(log_path, traceback.format_exc())
    write_progress(progress_path, stage="error", message=str(exc), percent=1.0)
    raise
