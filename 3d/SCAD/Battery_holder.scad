// ============================================================
// Battery_Holder.scad (Cleaned & Compacted)
// ============================================================

$fn = 96;

// HOLDER & POCKET DIMENSIONS
overall_w = 61.2827;  overall_d = 64.1609;  overall_h = 5.9252;
floor_t   = 0.44385;  wall_h    = 5.18313;  flange_t  = 0.765216;
tray_wall_t = 1.0;    flange_z  = overall_h - flange_t;

original_pocket_w = 49.0;
original_pocket_d = 58.0;
original_pocket_x0 = -original_pocket_w / 2;
original_pocket_x1 =  original_pocket_w / 2;
original_pocket_y0 = -original_pocket_d / 2;
original_pocket_y1 =  original_pocket_d / 2;

pocket_wall_push_out = 1.60;
short_opening_side_wall_move = 16.0;
opposite_big_opening_x_extension = 0.427618;
big_opening_x_extension = 4.3;

pocket_x0 = original_pocket_x0 - pocket_wall_push_out;
pocket_x1 = original_pocket_x1 + pocket_wall_push_out;
pocket_y0 = (original_pocket_y0 - pocket_wall_push_out) - opposite_big_opening_x_extension;
pocket_y1 = (original_pocket_y1 + pocket_wall_push_out) - short_opening_side_wall_move + big_opening_x_extension;

pocket_w = pocket_x1 - pocket_x0;
pocket_d = pocket_y1 - pocket_y0;

// HARDWARE & HOLES
hole_pitch_x = 58.0;  hole_pitch_y = 49.0;  hole_d = 2.41639;
underside_hardware_d = 5.4;  hardware_reference_h = 6.0;
hardware_r = underside_hardware_d / 2;
opening_to_hardware_gap = 0.20;

hole_x = hole_pitch_x / 2;
hole_y = hole_pitch_y / 2;
hole_positions = [[-hole_x, -hole_y], [hole_x, -hole_y], [-hole_x, hole_y], [hole_x, hole_y]];

// CUT PLACEMENT EDITOR CONTROLS
small_opening_shift_along_edge = 0.0;
large_opening_shift_along_edge = 0.0;
small_opening_into_pocket = 1.25;
large_opening_into_pocket = 1.25;

final_overall_w = overall_d;
final_overall_d = overall_w;

// SMALL BOTTOM OPENING
small_final_opening_w = 9.17705;
small_final_opening_right = hole_x - hardware_r - opening_to_hardware_gap + small_opening_shift_along_edge - 5;
small_final_opening_left  = small_final_opening_right - small_final_opening_w;
small_final_opening_bottom = -final_overall_d / 2 - 0.10;
small_final_opening_top    = -hole_y + hardware_r + opening_to_hardware_gap + tray_wall_t + small_opening_into_pocket;

small_opening_x0 = small_final_opening_bottom;
small_opening_y0 = -small_final_opening_right;
small_opening_w  = small_final_opening_top - small_final_opening_bottom;
small_opening_d  = small_final_opening_right - small_final_opening_left;

// LARGE LEFT OPENING
large_final_opening_d = 11.9299;
large_final_opening_top    = hole_y - hardware_r - opening_to_hardware_gap + large_opening_shift_along_edge;
large_final_opening_bottom = large_final_opening_top - large_final_opening_d;
large_final_opening_left   = -final_overall_w / 2 - 0.10;
large_final_opening_right  = -hole_x + hardware_r + opening_to_hardware_gap + tray_wall_t + large_opening_into_pocket + 10;

large_opening_x0 = large_final_opening_bottom;
large_opening_y0 = -large_final_opening_right;
large_opening_w  = large_final_opening_top - large_final_opening_bottom;
large_opening_d  = large_final_opening_right - large_final_opening_left;

// CUTTERS
module small_access_opening_cut(z_start = floor_t, cut_h = overall_h + 1) {
    translate([small_opening_x0, small_opening_y0, z_start])
        cube([small_opening_w, small_opening_d, cut_h]);
}

module large_side_opening_cut(z_start = floor_t, cut_h = overall_h + 1) {
    translate([large_opening_x0, large_opening_y0, z_start])
        cube([large_opening_w, large_opening_d, cut_h]);
}

module hardware_references_unrotated() {
    for (pos = hole_positions) {
        translate([pos[0], pos[1], flange_z - hardware_reference_h])
            cylinder(h = hardware_reference_h, d = underside_hardware_d);
    }
}

// COMPONENTS
module battery_floor() {
    translate([pocket_x0, pocket_y0, 0])
        cube([pocket_w, pocket_d, floor_t]);
}

module tray_walls() {
    difference() {
        // Outer wall boundary
        translate([pocket_x0 - tray_wall_t, pocket_y0 - tray_wall_t, 0])
            cube([pocket_w + tray_wall_t * 2, pocket_d + tray_wall_t * 2, wall_h]);
        // Inner pocket clearing
        translate([pocket_x0, pocket_y0, floor_t])
            cube([pocket_w, pocket_d, wall_h + 1]);
        // Openings
        small_access_opening_cut();
        large_side_opening_cut();
    }
}

module top_flange() {
    difference() {
        translate([-overall_w / 2, -overall_d / 2, flange_z])
            cube([overall_w, overall_d, flange_t]);
        translate([pocket_x0, pocket_y0, flange_z - 0.1])
            cube([pocket_w, pocket_d, flange_t + 0.3]);
        
        small_access_opening_cut(flange_z - 0.1, flange_t + 0.3);
        large_side_opening_cut(flange_z - 0.1, flange_t + 0.3);

        for (pos = hole_positions) {
            translate([pos[0], pos[1], flange_z - 0.1])
                cylinder(h = flange_t + 0.3, d = hole_d);
        }
    }
}

// MAIN ASSEMBLY
rotate([0, 0, 90]) {
    difference() {
        union() {
            battery_floor();
            tray_walls();
            top_flange();
        }
        hardware_references_unrotated();
    }
}