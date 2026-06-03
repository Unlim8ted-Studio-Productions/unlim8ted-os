// ============================================================
// Main_Case.scad
// Rebuilt as:
//   1. 1 mm bottom/front bezel frame
//   2. Thin tall U-shaped outer wall on three sides
//   3. Two internal ledges, each with two holes
//
// Units: mm
// ============================================================

$fn = 96;

// ============================================================
// OPTIONAL STL COMPARISON
// ============================================================
// Put Main_Case.stl in the same folder as this .scad file.
// Toggle this true to overlay the original STL.
//
// NOTE: the STL raw geometry is in meter-scale coordinates,
// so it must be scaled by 1000 to compare to this mm model.

show_reference = false;

// Original STL translation after scaling, to place its
// bottom bezel approximately centered at X/Y and resting on Z=0.
reference_shift = [18.21933, -40.20455, -37.30603];

// ============================================================
// MEASURED / EXTRACTED OVERALL DIMENSIONS
// ============================================================

overall_height = 20.5651;

// Full 1 mm bezel/frame at the bottom
bezel_outer_x = 77.0992;
bezel_outer_y = 165.8954;

bezel_inner_x = 67.9170;
bezel_inner_y = 144.3520;

bezel_h = 1.0;

// Estimated from STL profile
bezel_outer_r = 9.0;
bezel_inner_r = 8.0;

// ============================================================
// TALL U-SHAPED WALL
// ============================================================

// Wall rises above the 1 mm bezel
wall_h = overall_height - bezel_h;      // 19.5651 mm

// Outer wall footprint is slightly different from the bezel
wall_outer_x = 77.0992;
wall_outer_y = 166.3964;

// STL indicates a very thin outer shell wall, not a thick frame
wall_t = 1.05;

wall_outer_r = 9.0;
wall_inner_r = wall_outer_r - wall_t;

// The tall wall is slightly shifted toward the closed end
wall_y_shift = -0.2505;

// The tall shell is open at the front.
// This removes the fourth vertical wall while leaving the
// 1 mm bezel frame underneath intact.
wall_front_end_y = 76.0;

// ============================================================
// INTERNAL SIDE LEDGES
// ============================================================

// Each ledge is positioned on one long inside wall.
ledge_length = 40.5665;

// The visible inward projection measured from the inside wall
ledge_inward = 3.33912;

// Small overlap into the thin wall, so the ledge unions cleanly
ledge_overlap = 0.82;

ledge_total_x = ledge_inward + ledge_overlap;

// Extracted from STL vertical tab profile
ledge_h = 1.410;

// Extracted approximate vertical location from bottom of model
ledge_z = 7.810;

// Extracted approximate location along the length.
// Positive Y is the open/front end.
ledge_center_y = 52.61;

// Two holes on each ledge
hole_d = 2.0;

// Interpreting your measured 2.23032 mm as the distance
// from each ledge end to its nearby hole center.
hole_center_from_end = 2.23032;

// ============================================================
// BASIC 2D HELPERS
// ============================================================

module rounded_rect(w, h, r) {
    hull() {
        translate([ w/2 - r,  h/2 - r]) circle(r = r);
        translate([-w/2 + r,  h/2 - r]) circle(r = r);
        translate([ w/2 - r, -h/2 + r]) circle(r = r);
        translate([-w/2 + r, -h/2 + r]) circle(r = r);
    }
}

module rounded_ring_2d(outer_x, outer_y, outer_r, inner_x, inner_y, inner_r) {
    difference() {
        rounded_rect(outer_x, outer_y, outer_r);
        rounded_rect(inner_x, inner_y, inner_r);
    }
}

// ============================================================
// 1 MM FULL BEZEL / FRONT FRAME
// ============================================================

module bottom_bezel_frame() {
    linear_extrude(height = bezel_h)
        rounded_ring_2d(
            bezel_outer_x,
            bezel_outer_y,
            bezel_outer_r,
            bezel_inner_x,
            bezel_inner_y,
            bezel_inner_r
        );
}

// ============================================================
// THIN U-SHAPED VERTICAL WALL
// ============================================================

module u_wall_profile_2d() {
    difference() {
        // First make a thin rounded rectangular wall ring.
        rounded_ring_2d(
            wall_outer_x,
            wall_outer_y,
            wall_outer_r,
            wall_outer_x - wall_t * 2,
            wall_outer_y - wall_t * 2,
            wall_inner_r
        );

        // Then remove the front vertical side entirely,
        // converting the ring into a U-shaped wall.
        translate([
            -(wall_outer_x + 10) / 2,
            wall_front_end_y - wall_y_shift
        ])
            square([wall_outer_x + 10, wall_outer_y]);
    }
}

module tall_u_wall() {
    translate([0, wall_y_shift, bezel_h])
        linear_extrude(height = wall_h)
            u_wall_profile_2d();
}

// ============================================================
// INTERNAL LEDGES
// ============================================================

module one_ledge(side = 1) {

    // Inner surface of thin long wall
    inside_wall_x = wall_outer_x/2 - wall_t;

    // Position ledge so it starts slightly inside the wall
    // and projects inward toward the center opening.
    ledge_center_x =
        side * (
            inside_wall_x
            - ledge_inward/2
            + ledge_overlap/2
        );

    hole_x =
        side * (
            inside_wall_x
            - ledge_inward/2
        );

    difference() {
        translate([
            ledge_center_x - ledge_total_x/2,
            ledge_center_y - ledge_length/2,
            ledge_z
        ])
            cube([
                ledge_total_x,
                ledge_length,
                ledge_h
            ]);

        // Hole nearest the back end
        translate([
            hole_x,
            ledge_center_y - ledge_length/2 + hole_center_from_end,
            ledge_z - 0.5
        ])
            cylinder(h = ledge_h + 1, d = hole_d);

        // Hole nearest the open/front end
        translate([
            hole_x,
            ledge_center_y + ledge_length/2 - hole_center_from_end,
            ledge_z - 0.5
        ])
            cylinder(h = ledge_h + 1, d = hole_d);
    }
}

module internal_ledges() {
    one_ledge(-1);
    one_ledge(1);
}

// ============================================================
// FINAL PART
// ============================================================

module main_case() {
    union() {
        bottom_bezel_frame();
        tall_u_wall();
        internal_ledges();
    }
}

main_case();

// ============================================================
// OPTIONAL ORIGINAL STL OVERLAY
// ============================================================

if (show_reference) {
    %translate(reference_shift)
        scale([1000, 1000, 1000])
            import("Main_Case.stl", convexity = 10);
}