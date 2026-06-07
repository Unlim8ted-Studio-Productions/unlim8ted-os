// ============================================================
// Compute_Module_Plane.scad
//
// Thin compute-module mounting plate with four raised screw posts.
//
// Rebuilt from the uploaded STL and screenshots.
//
// Units: mm
//
// Orientation:
//   X = plate width
//   Y = plate depth
//   Z = thickness / post height
//
// The lower two standoffs extend partially beyond the plate edge,
// matching the visible model.
// ============================================================

$fn = 96;

// ============================================================
// PLATE DIMENSIONS
// ============================================================

plate_w = 74.2596;
plate_d = 36.4907;
plate_t = 0.796066;

// Plate is a simple rectangular plane with square corners.
plate_x0 = -plate_w / 2;
plate_y0 = -plate_d / 2;

// ============================================================
// STANDOFF / SCREW POST DIMENSIONS
// ============================================================

// Raised height above upper surface of the plate
post_h = 2.10791;

// Outer diameter of cylindrical raised posts,
// extracted approximately from STL geometry.
post_outer_d = 5.81234;

// Through-hole diameter, based on measured hole views.
post_hole_d = 2.80;

// Optional printed-fit clearance
hole_clearance = 0.0;

final_post_hole_d = post_hole_d + hole_clearance;

// ============================================================
// POST LOCATIONS
// ============================================================
//
// Locations are centered relative to the rectangular plate.
//
// Top posts sit inside the plate area.
// Bottom posts extend slightly past the lower plate edge,
// as shown in the model screenshots.
// ============================================================

post_positions = [
    // X,         Y
    [-26.513,   14.356],     // upper-left
    [ 21.441,   14.356],     // upper-right

    [-26.513,  -18.649],     // lower-left, partly beyond plate
    [ 21.441,  -18.690]      // lower-right, partly beyond plate
];

// ============================================================
// OPTIONAL PREVIEW SETTINGS
// ============================================================

show_hole_center_references = false;

// ============================================================
// MAIN FLAT PLATE
// ============================================================

module compute_plane_plate() {
    translate([
        plate_x0,
        plate_y0,
        0
    ])
        cube([
            plate_w,
            plate_d,
            plate_t
        ]);
}

// ============================================================
// ONE RAISED STANDOFF
// ============================================================
//
// Each standoff is unioned to the top of the thin plate.
// The hole is continuous through the standoff and plate.
// ============================================================

module raised_standoff(x, y) {
    translate([
        x,
        y,
        plate_t
    ])
        cylinder(
            h = post_h,
            d = post_outer_d
        );
}

// ============================================================
// ALL STANDOFFS
// ============================================================

module all_standoffs() {
    for (p = post_positions) {
        raised_standoff(p[0], p[1]);
    }
}

// ============================================================
// THROUGH HOLES
// ============================================================

module all_post_holes() {
    for (p = post_positions) {
        translate([
            p[0],
            p[1],
            -0.1
        ])
            cylinder(
                h = plate_t + post_h + 0.2,
                d = final_post_hole_d
            );
    }
}

// ============================================================
// FINAL PRINTED PART
// ============================================================

module compute_module_plane() {
    difference() {
        union() {
            compute_plane_plate();
            all_standoffs();
        }

        all_post_holes();
    }
}

// ============================================================
// PREVIEW-ONLY HOLE REFERENCES
// ============================================================

module hole_center_references() {
    for (p = post_positions) {
        %color("Crimson", 0.5)
            translate([
                p[0],
                p[1],
                plate_t + post_h
            ])
                cylinder(
                    h = 2,
                    d = final_post_hole_d
                );
    }
}

// ============================================================
// OUTPUT
// ============================================================

compute_module_plane();

if (show_hole_center_references)
    hole_center_references();

// ============================================================
// OPTIONAL ORIGINAL STL OVERLAY
// ============================================================
//
// Place "Compute Module Plane.stl" in the same folder.
// The original STL is exported in meter-scale coordinates,
// so it needs scale([1000,1000,1000]).
//
// Uncomment and adjust the translation while comparing:
//
// %translate([17.90, 19.45, -41.9629])
//     scale([1000, 1000, 1000])
//         import("Compute Module Plane.stl", convexity = 10);