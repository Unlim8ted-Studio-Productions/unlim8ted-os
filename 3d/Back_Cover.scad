// ============================================================
// Back_Cover.scad
// Rebuilt from Back_Cover.stl and measured screenshots
//
// Orientation:
//   X = width
//   Y = length
//   Z = thickness / boss depth
//
// The outside finished face is on top.
// The internal screw bosses extend downward.
// Units: mm
// ============================================================

$fn = 96;

// ============================================================
// MAIN PANEL DIMENSIONS
// ============================================================

plate_x = 76.9374;
plate_y = 166.1777;

// Extracted from STL:
// upper outside surface to underside flat surface
plate_h = 3.2828;

// Rounded corners estimated from STL outer contour
corner_r = 6.0;

// Small perimeter bevel / flare visible on the outside edge
edge_bevel = 0.13;
edge_bevel_h = 0.18;

// ============================================================
// LARGE CAMERA / BUMP OPENING
// ============================================================

camera_hole_d = 15.1144;

// Position relative to center of back plate.
// Negative Y = camera-hole end of the cover.
camera_x = -0.2718;
camera_y = -61.4483;

// ============================================================
// SCREW HOLE / BOSS DIMENSIONS
// ============================================================

// Visible circular recess on finished outside face
counterbore_d = 9.2351;
counterbore_depth = 1.89245;

// Small through-hole inside each recess/boss
screw_hole_d = 2.58313;

// Underside boss outer diameter
boss_d = 6.52951;

// Four shorter bosses
short_boss_h = 3.51307;

// Two taller bosses farthest away from the camera opening
tall_boss_h = 8.33461;

// ============================================================
// BOSS / HOLE POSITIONS
// Extracted from STL cross-sections, centered on the plate.
// Layout shown with camera end at negative Y.
//
//     TL                 TR        <- tall bosses
//
//     ML                 MR        <- short bosses
//
//     BL                 BR        <- short bosses
//
//             CAMERA
// ============================================================

boss_positions = [
    // x,        y,        boss height
    [-22.8128,  55.6865, tall_boss_h],   // top left
    [ 25.8846,  55.5952, tall_boss_h],   // top right

    [-24.5100,  21.0340, short_boss_h],  // middle left
    [ 24.5291,  21.0340, short_boss_h],  // middle right

    [-24.6543, -37.0091, short_boss_h],  // lower left
    [ 24.5291, -37.0091, short_boss_h]   // lower right
];

// ============================================================
// HELPERS
// ============================================================

module rounded_rect(w, h, r) {
    hull() {
        translate([ w/2-r,  h/2-r]) circle(r = r);
        translate([-w/2+r,  h/2-r]) circle(r = r);
        translate([ w/2-r, -h/2+r]) circle(r = r);
        translate([-w/2+r, -h/2+r]) circle(r = r);
    }
}

// ============================================================
// MAIN ROUNDED BACK PANEL
// Slightly beveled around the outside edge.
// Bottom/internal side is at Z = 0.
// Outside finished surface is at Z = plate_h.
// ============================================================

module beveled_panel_blank() {
    hull() {
        // Slightly inset underside edge
        translate([0, 0, 0])
            linear_extrude(height = edge_bevel_h)
                rounded_rect(
                    plate_x - edge_bevel * 2,
                    plate_y - edge_bevel * 2,
                    corner_r - edge_bevel
                );

        // Full-size upper/outside surface
        translate([0, 0, edge_bevel_h])
            linear_extrude(height = plate_h - edge_bevel_h)
                rounded_rect(
                    plate_x,
                    plate_y,
                    corner_r
                );
    }
}

// ============================================================
// HOLES THROUGH THE PANEL
// ============================================================

module camera_opening() {
    translate([camera_x, camera_y, -1])
        cylinder(
            h = plate_h + 2,
            d = camera_hole_d
        );
}

module screw_counterbore_cut(x, y) {
    // Small through-hole
    translate([x, y, -1])
        cylinder(
            h = plate_h + 2,
            d = screw_hole_d
        );

    // Wide recessed pocket on the outside face
    translate([x, y, plate_h - counterbore_depth])
        cylinder(
            h = counterbore_depth + 1,
            d = counterbore_d
        );
}

module all_panel_holes() {
    camera_opening();

    for (p = boss_positions) {
        screw_counterbore_cut(p[0], p[1]);
    }
}

// ============================================================
// UNDERSIDE SCREW BOSSES
// Bosses extend downward from the inside face of the panel.
// ============================================================

module one_boss(x, y, h) {
    difference() {
        translate([x, y, -h])
            cylinder(
                h = h,
                d = boss_d
            );

        translate([x, y, -h - 1])
            cylinder(
                h = h + 2,
                d = screw_hole_d
            );
    }
}

module all_bosses() {
    for (p = boss_positions) {
        one_boss(p[0], p[1], p[2]);
    }
}

// ============================================================
// FINAL BACK COVER
// ============================================================

module back_cover() {
    union() {
        difference() {
            beveled_panel_blank();
            all_panel_holes();
        }

        all_bosses();
    }
}

back_cover();

// ============================================================
// OPTIONAL VIEWS / STL OVERLAY
// ============================================================

// To inspect the internal boss side facing upward, replace:
//
//     back_cover();
//
// with:
//
//     rotate([180, 0, 0]) back_cover();
//
//
// To compare against your original STL, place Back_Cover.stl
// beside this file and uncomment below. The original STL was
// exported in meter-scale coordinates, so it is scaled by 1000.
//
// %translate([18.1105, -40.0639, -56.2831])
//     scale([1000, 1000, 1000])
//         import("Back_Cover.stl", convexity = 10);