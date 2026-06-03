// ============================================================
// Battery_Controller_Holder.scad
//
// Flat controller mounting plate that slides onto the Main_Case
// overhang and fits against the Bottom_Cover.
//
// Corrected:
//   - Includes all 10 visible through holes
//
// Units: mm
// ============================================================

$fn = 96;

// ============================================================
// OVERALL PLATE DIMENSIONS
// ============================================================

plate_w = 75.77920;
plate_d = 49.61260;
plate_t = 1.25191;

// Rounded corners on the upper side.
// Lower side remains square as in the previous version.
top_corner_r = 6.0;

// ============================================================
// THROUGH HOLES
// ============================================================

hole_d = 2.58313;

// Optional extra clearance for printing
hole_clearance = 0.0;

final_hole_d = hole_d + hole_clearance;

// ============================================================
// HOLE LOCATIONS
// ============================================================
//
// Orientation:
//
//              ROUNDED / TOP SIDE
//
//       o          o       o          o
//
//              o                   o
//
//       o          o       o          o
//
//              SQUARE / BOTTOM SIDE
//
// X = left/right across wide plate
// Y = bottom/top along short plate depth
//
// Positions are centered relative to the plate.
// ============================================================

hole_positions = [

    // Far-left outer column
    [-35.4335,  11.2380],     // upper-left outer
    [-35.4335, -22.5160],     // lower-left outer   ADDED

    // Left-middle hole
    [-22.7505,  -2.8060],

    // Inner upper pair
    [ -5.8955,   6.5120],
    [ 14.6195,   6.5120],

    // Inner lower pair
    [ -5.6835, -21.0880],
    [ 14.6195, -21.0880],

    // Right-middle hole
    [ 25.8846,  -2.8060],     // ADDED

    // Far-right outer column
    [ 35.4375,  11.2380],     // upper-right outer
    [ 35.4375, -22.5160]      // lower-right outer
];

// ============================================================
// OPTIONAL PREVIEW SETTINGS
// ============================================================

// Set true to show the edge expected to sit against Bottom_Cover.
show_bottom_cover_edge_reference = false;

// Set true to show hole centers above the plate in preview.
show_hole_reference_posts = false;

// ============================================================
// PLATE PROFILE
// ============================================================
//
// Produces:
//   - square lower-left corner
//   - square lower-right corner
//   - rounded upper-left corner
//   - rounded upper-right corner
// ============================================================

module controller_plate_profile_2d() {

    union() {

        // Full-width lower rectangular body
        translate([
            -plate_w / 2,
            -plate_d / 2
        ])
            square([
                plate_w,
                plate_d - top_corner_r
            ]);

        // Central section extending to upper edge
        translate([
            -plate_w / 2 + top_corner_r,
            -plate_d / 2
        ])
            square([
                plate_w - top_corner_r * 2,
                plate_d
            ]);

        // Upper-left rounded corner
        translate([
            -plate_w / 2 + top_corner_r,
             plate_d / 2 - top_corner_r
        ])
            circle(r = top_corner_r);

        // Upper-right rounded corner
        translate([
             plate_w / 2 - top_corner_r,
             plate_d / 2 - top_corner_r
        ])
            circle(r = top_corner_r);
    }
}

// ============================================================
// HOLE CUTTERS
// ============================================================

module all_hole_cuts() {
    for (p = hole_positions) {
        translate([
            p[0],
            p[1],
            -0.1
        ])
            cylinder(
                h = plate_t + 0.2,
                d = final_hole_d
            );
    }
}

// ============================================================
// PRINTED PART
// ============================================================

module battery_controller_holder() {
    difference() {

        linear_extrude(height = plate_t)
            controller_plate_profile_2d();

        all_hole_cuts();
    }
}

// ============================================================
// PREVIEW-ONLY REFERENCES
// ============================================================

module bottom_cover_edge_reference() {
    %color("DodgerBlue", 0.45)
        translate([
            -plate_w / 2,
            -plate_d / 2 - 0.5,
            0
        ])
            cube([
                plate_w,
                0.35,
                plate_t
            ]);
}

module hole_reference_posts() {
    for (p = hole_positions) {
        %color("Crimson", 0.50)
            translate([
                p[0],
                p[1],
                plate_t
            ])
                cylinder(
                    h = 2,
                    d = final_hole_d
                );
    }
}

// ============================================================
// OUTPUT
// ============================================================

battery_controller_holder();

if (show_bottom_cover_edge_reference)
    bottom_cover_edge_reference();

if (show_hole_reference_posts)
    hole_reference_posts();