// ============================================================
// Back_Cover_Camera_Bump.scad
//
// Camera bump with:
//   - flat, sharply cut-off underside
//   - rounded square upper base
//   - tapered circular raised ring
//   - center hole matching Back_Cover opening
//
// Units: mm
// ============================================================

$fn = 128;

// ============================================================
// MEASURED DIMENSIONS
// ============================================================

// Rounded square base
base_x = 30.4471;
base_y = 30.3821;
base_h = 6.0917;

// Corner radius of square footprint
base_corner_r = 4.6;

// Top outer edge rounding only
top_round_h = 1.15;
top_round_inset = 0.95;

// Circular raised camera ring
ring_outer_d = 24.0419;

// Center hole matches Back_Cover camera opening
hole_d = 15.1144;

// Raised ring height above the square base
ring_h = 4.07;

// Optional print clearance.
// Keep at 0 for exact modeled dimensions.
hole_clearance = 0;

final_hole_d = hole_d + hole_clearance;

// ============================================================
// HELPERS
// ============================================================

module rounded_rect_2d(w, h, r) {
    hull() {
        translate([ w/2-r,  h/2-r]) circle(r = r);
        translate([-w/2+r,  h/2-r]) circle(r = r);
        translate([ w/2-r, -h/2+r]) circle(r = r);
        translate([-w/2+r, -h/2+r]) circle(r = r);
    }
}

// ============================================================
// FLAT-BOTTOM ROUNDED SQUARE BASE
// ============================================================
//
// Important change:
// The bottom begins directly at Z = 0 with the full footprint.
// Nothing curves under the part.
//
// The upper edge tapers inward very slightly to create the
// rounded-looking top transition visible in the reference.
// ============================================================

module flat_bottom_base() {
    hull() {
        // Sharp, flat bottom with full outer dimensions
        linear_extrude(height = 0.02)
            rounded_rect_2d(
                base_x,
                base_y,
                base_corner_r
            );

        // Vertical side body
        translate([0, 0, base_h - top_round_h])
            linear_extrude(height = 0.02)
                rounded_rect_2d(
                    base_x,
                    base_y,
                    base_corner_r
                );

        // Slightly inset upper face to round only the top edge
        translate([0, 0, base_h])
            linear_extrude(height = 0.02)
                rounded_rect_2d(
                    base_x - top_round_inset * 2,
                    base_y - top_round_inset * 2,
                    base_corner_r - top_round_inset
                );
    }
}

// ============================================================
// TAPERED CIRCULAR CAMERA RING
// ============================================================
//
// This is a tapered raised collar sitting on top of the base.
// Its underside is also sharply terminated where it meets the
// square base.
// ============================================================

module tapered_camera_ring() {
    inner_r = final_hole_d / 2;
    outer_r = ring_outer_d / 2;

    translate([0, 0, base_h])
        rotate_extrude(convexity = 10)
            polygon(points = [
                // Sharp bottom outside edge
                [outer_r,         0],

                // Sloped/soft outside rise
                [outer_r - 0.10,  0.18],
                [outer_r - 0.45,  0.75],
                [inner_r + 3.35,  1.70],
                [inner_r + 2.20,  2.70],
                [inner_r + 1.10,  3.55],
                [inner_r + 0.35,  ring_h - 0.12],

                // Top opening edge
                [inner_r,         ring_h],

                // Vertical inside hole surface
                [inner_r,         0]
            ]);
}

// ============================================================
// CENTER HOLE
// ============================================================

module center_hole() {
    translate([0, 0, -0.1])
        cylinder(
            h = base_h + ring_h + 0.3,
            d = final_hole_d
        );
}

// ============================================================
// FINAL PART
// ============================================================

module back_cover_camera_bump() {
    difference() {
        union() {
            flat_bottom_base();
            tapered_camera_ring();
        }

        center_hole();
    }
}

back_cover_camera_bump();