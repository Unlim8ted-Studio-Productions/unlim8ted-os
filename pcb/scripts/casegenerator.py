# "D:\KiCAD\bin\python.exe" casegenerator.py phone.kicad_pcb phone_case.scad --bottom_clearance 4 --top_clearance 12 --wall 2.5 --boss_radius 3.5
"""
Generate a simple 3D-printable case (OpenSCAD) from a KiCad .kicad_pcb file.

- Uses pcbnew to parse the board.
- Detects overall board bounding box.
- Finds mounting holes and creates bosses + screw pockets.
- Outputs an OpenSCAD .scad file with:
    - bottom_case()
    - top_case()
    - assembly() (top + bottom aligned)

You can then:
    1. Open the .scad in OpenSCAD,
    2. Render, and
    3. Export STL for 3D printing.

Run (inside KiCad’s Python or with pcbnew available):

    python kicad_case_generator.py path/to/board.kicad_pcb case_output.scad
"""

import sys
import argparse
from pathlib import Path

try:
    import pcbnew
except ImportError:
    print(
        "Error: pcbnew module not found. Run this from KiCad's Python or a Python environment with KiCad installed."
    )
    sys.exit(1)


NM_PER_MM = 1_000_000.0  # KiCad internal units: nanometers


def nm_to_mm(v):
    return float(v) / NM_PER_MM


def get_board_info(board):
    """
    Extract basic board info:
    - bounding box (min_x, min_y, width, height) in mm
    - thickness in mm
    """
    bbox = board.GetBoardEdgesBoundingBox()
    min_x = nm_to_mm(bbox.GetX())
    min_y = nm_to_mm(bbox.GetY())
    width = nm_to_mm(bbox.GetWidth())
    height = nm_to_mm(bbox.GetHeight())
    thickness = nm_to_mm(board.GetDesignSettings().GetBoardThickness())

    return {
        "min_x": min_x,
        "min_y": min_y,
        "width": width,
        "height": height,
        "thickness": thickness,
    }


def find_mounting_holes(board, min_diameter_mm=2.2, max_diameter_mm=5.0):
    """
    Very simple heuristic to find mounting holes:
    - Pads with a drill size in [min_diameter_mm, max_diameter_mm]
    - NPTH or regular TH pads that look like mechanical holes.

    Returns list of dicts: {x, y, drill_diam}
    All coordinates in mm.
    """
    holes = []

    # KiCad 6/7/8: GetFootprints()
    # KiCad 5: GetModules()
    try:
        footprints = board.GetFootprints()
    except AttributeError:
        footprints = board.GetModules()  # older KiCad fallback

    for fp in footprints:
        for pad in fp.Pads():
            drill = pad.GetDrillSize()
            # Some pads have no drill (SMD)
            if drill.x <= 0:
                continue

            drill_diam_mm = nm_to_mm(drill.x)

            if not (min_diameter_mm <= drill_diam_mm <= max_diameter_mm):
                continue

            pos = pad.GetPosition()
            x = nm_to_mm(pos.x)
            y = nm_to_mm(pos.y)

            holes.append(
                {
                    "x": x,
                    "y": y,
                    "drill": drill_diam_mm,
                }
            )

    return holes


def generate_openscad(board_info, holes, params):
    """
    Generate an OpenSCAD string implementing top and bottom cases.
    """
    bx = board_info["width"]
    by = board_info["height"]
    bt = board_info["thickness"]

    # Case parameters
    margin = params["margin"]  # extra space around board
    wall = params["wall_thickness"]
    clearance_xy = params["clearance_xy"]
    bottom_clearance = params["bottom_clearance"]
    top_clearance = params["top_clearance"]
    lip_height = params["lip_height"]
    lip_clearance = params["lip_clearance"]
    boss_radius = params["boss_radius"]
    screw_clearance = params["screw_clearance"]
    screw_head_diam = params["screw_head_diam"]
    screw_head_depth = params["screw_head_depth"]

    # Outer dimensions
    inner_x = bx + 2 * clearance_xy
    inner_y = by + 2 * clearance_xy

    outer_x = inner_x + 2 * wall
    outer_y = inner_y + 2 * wall

    # Heights
    bottom_shell_height = bottom_clearance + bt / 2.0
    top_shell_height = top_clearance + bt / 2.0

    # Z positions
    board_z = bottom_clearance  # distance from bottom outer surface to bottom of board

    scad = []

    scad.append("// Auto-generated enclosure from KiCad board")
    scad.append("// Board size: %.2f x %.2f mm, thickness: %.2f mm" % (bx, by, bt))
    scad.append("// Inner XY:   %.2f x %.2f mm" % (inner_x, inner_y))
    scad.append("// Outer XY:   %.2f x %.2f mm" % (outer_x, outer_y))
    scad.append("")

    # Helper modules
    scad.append(
        """
////////////////////
// PARAMETERS
////////////////////
outer_x = %.3f;
outer_y = %.3f;

inner_x = %.3f;
inner_y = %.3f;

wall      = %.3f;
bottom_h  = %.3f;
top_h     = %.3f;

lip_h         = %.3f;
lip_clearance = %.3f;

boss_r          = %.3f;
screw_clearance = %.3f;
screw_head_d    = %.3f;
screw_head_h    = %.3f;

// Board offset inside the case (so it's centered)
board_offset_x = wall + %.3f;
board_offset_y = wall + %.3f;
board_z        = %.3f;
"""
        % (
            outer_x,
            outer_y,
            inner_x,
            inner_y,
            wall,
            bottom_shell_height,
            top_shell_height,
            lip_height,
            lip_clearance,
            boss_radius,
            screw_clearance,
            screw_head_diam,
            screw_head_depth,
            clearance_xy,
            clearance_xy,
            board_z,
        )
    )

    # Bottom case module
    scad.append(
        """
////////////////////
// BOTTOM CASE
////////////////////
module bottom_case() {
    difference() {
        // Outer shell
        cube([outer_x, outer_y, bottom_h], center=false);

        // Inner cavity for board + air
        translate([wall, wall, wall])
            cube([inner_x, inner_y, bottom_h], center=false);

        // Recessed pockets for screw heads (from inside bottom)
"""
    )

    for h in holes:
        # Transform board coordinates (global) to local case coordinates (board origin at min_x/min_y)
        local_x = (h["x"] - board_info["min_x"]) + (wall + clearance_xy)
        local_y = (h["y"] - board_info["min_y"]) + (wall + clearance_xy)

        scad.append(
            "        // Screw head pocket for hole at (%.2f, %.2f)\n"
            "        translate([%.3f, %.3f, 0])\n"
            "            cylinder(d=screw_head_d, h=screw_head_h, $fn=32);\n"
            % (h["x"], h["y"], local_x, local_y)
        )

        scad.append(
            "        // Through hole for screw shaft\n"
            "        translate([%.3f, %.3f, 0])\n"
            "            cylinder(d=screw_clearance, h=bottom_h + 0.5, $fn=24);\n"
            % (local_x, local_y)
        )

    scad.append("    }\n\n")

    # Bosses (standoffs) that mate with the top case
    scad.append("    // Bosses around mounting holes\n")
    for h in holes:
        local_x = (h["x"] - board_info["min_x"]) + (wall + clearance_xy)
        local_y = (h["y"] - board_info["min_y"]) + (wall + clearance_xy)

        scad.append(
            "    translate([%.3f, %.3f, board_z])\n"
            "        cylinder(r=boss_r, h=bottom_h - board_z, $fn=32);\n"
            % (local_x, local_y)
        )

    scad.append("}\n")

    # Top case module
    scad.append(
        """
////////////////////
// TOP CASE
////////////////////
module top_case() {
    // The top is flipped in Z when assembled, but we model it upright.
    difference() {
        // Outer shell
        cube([outer_x, outer_y, top_h], center=false);

        // Inner cavity for board + air + lip
        translate([wall, wall, 0])
            cube([inner_x, inner_y, top_h - wall], center=false);

        // Lip clearance, so it mates with bottom lip
        translate([wall + lip_clearance,
                   wall + lip_clearance,
                   0])
            cube([inner_x - 2*lip_clearance,
                  inner_y - 2*lip_clearance,
                  lip_h], center=false);
    }

    // Mating bosses: small holes for screws / inserts that align with bottom bosses.
"""
    )

    for h in holes:
        local_x = (h["x"] - board_info["min_x"]) + (wall + clearance_xy)
        local_y = (h["y"] - board_info["min_y"]) + (wall + clearance_xy)

        scad.append(
            "    // Boss hole in top for screw tip or insert\n"
            "    translate([%.3f, %.3f, 0])\n"
            "        cylinder(d=screw_clearance, h=top_h, $fn=24);\n"
            % (local_x, local_y)
        )

    scad.append("}\n")

    # Assembly view
    scad.append(
        """
////////////////////
// ASSEMBLY VIEW
////////////////////
module assembly() {
    // Bottom at Z=0
    bottom_case();

    // Top translated above bottom by a small gap
    translate([0, 0, bottom_h + 0.5])
        top_case();
}

// Uncomment one of the following to preview/export in OpenSCAD:
// bottom_case();
// top_case();
assembly();
"""
    )

    return "\n".join(scad)


def main():
    parser = argparse.ArgumentParser(
        description="Generate a 3D-printable case (OpenSCAD) from a KiCad .kicad_pcb."
    )
    parser.add_argument("kicad_pcb", help="Path to the .kicad_pcb file")
    parser.add_argument("output_scad", help="Path to output .scad file")
    parser.add_argument(
        "--margin", type=float, default=3.0, help="Extra margin around board (mm)"
    )
    parser.add_argument("--wall", type=float, default=2.0, help="Wall thickness (mm)")
    parser.add_argument(
        "--clearance_xy",
        type=float,
        default=0.5,
        help="XY clearance between board and inner walls (mm)",
    )
    parser.add_argument(
        "--bottom_clearance",
        type=float,
        default=3.0,
        help="Clearance below board bottom (mm)",
    )
    parser.add_argument(
        "--top_clearance",
        type=float,
        default=10.0,
        help="Clearance above board top (mm)",
    )
    parser.add_argument(
        "--lip_height", type=float, default=1.0, help="Height of mating lip (mm)"
    )
    parser.add_argument(
        "--lip_clearance",
        type=float,
        default=0.2,
        help="Side clearance for snap fit (mm)",
    )
    parser.add_argument(
        "--boss_radius", type=float, default=3.0, help="Radius of mounting bosses (mm)"
    )
    parser.add_argument(
        "--screw_clearance", type=float, default=2.6, help="Screw shaft clearance (mm)"
    )
    parser.add_argument(
        "--screw_head_diam",
        type=float,
        default=5.0,
        help="Screw head pocket diameter (mm)",
    )
    parser.add_argument(
        "--screw_head_depth",
        type=float,
        default=2.5,
        help="Screw head pocket depth (mm)",
    )

    args = parser.parse_args()

    board_path = Path(args.kicad_pcb)
    if not board_path.is_file():
        print(f"Error: {board_path} does not exist.")
        sys.exit(1)

    board = pcbnew.LoadBoard(str(board_path))
    board_info = get_board_info(board)
    holes = find_mounting_holes(board)

    if not holes:
        print(
            "Warning: No mounting holes detected with current thresholds; case will not have bosses."
        )

    params = {
        "margin": args.margin,
        "wall_thickness": args.wall,
        "clearance_xy": args.clearance_xy,
        "bottom_clearance": args.bottom_clearance,
        "top_clearance": args.top_clearance,
        "lip_height": args.lip_height,
        "lip_clearance": args.lip_clearance,
        "boss_radius": args.boss_radius,
        "screw_clearance": args.screw_clearance,
        "screw_head_diam": args.screw_head_diam,
        "screw_head_depth": args.screw_head_depth,
    }

    scad_str = generate_openscad(board_info, holes, params)

    out_path = Path(args.output_scad)
    out_path.write_text(scad_str, encoding="utf-8")
    print(f"Generated OpenSCAD file: {out_path}")


if __name__ == "__main__":
    main()
