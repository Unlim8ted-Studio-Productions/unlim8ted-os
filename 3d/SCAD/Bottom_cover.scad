// ============================================================
// Bottom_Cover.scad
//
// Thin U-shaped bottom/end cover
// Corrected using measured wall thickness: 0.7 mm
//
// Units: mm
//
// Orientation:
//   X = overall width
//   Y = return/wrap depth
//   Z = vertical height
// ============================================================

$fn = 128;

// ============================================================
// MEASURED BODY DIMENSIONS
// ============================================================

outer_w = 77.1122;
cover_h = 19.5713;
return_depth = 10.5435;

// Corrected material thickness
wall_t = 0.70;

// Measured straight front span between corner curves
straight_span = 64.9267;

// Corner radius inferred from width and straight span
outer_corner_r = (outer_w - straight_span) / 2;   // 6.09275 mm
inner_corner_r = outer_corner_r - wall_t;

// ============================================================
// USB-C CABLE OPENING
// ============================================================
//
// This opening is larger than a bare USB-C metal connector so
// the thicker molded plastic/rubber cable end can pass through.
//
// For an exact fit, measure your actual cable housing and add
// approximately 0.4 to 0.8 mm total clearance in each direction.
// ============================================================

usb_open_w = 16.0;
usb_open_h = 8.5;
usb_open_r = usb_open_h / 2;

usb_x = 0;
usb_z = cover_h / 2;

// ============================================================
// HELPERS
// ============================================================

module rounded_slot_2d(w, h) {
    hull() {
        translate([-(w-h)/2, 0])
            circle(d = h);

        translate([(w-h)/2, 0])
            circle(d = h);
    }
}

// ============================================================
// U-SHAPED PLAN PROFILE
// ============================================================
//
// The cover is created as three connected thin walls:
//
//   - one long flat front wall
//   - one curved return at the left end
//   - one curved return at the right end
//
// It is intentionally open on the rear side.
// ============================================================

module front_wall_profile() {
    translate([-outer_w/2 + outer_corner_r, 0])
        square([
            outer_w - outer_corner_r*2,
            wall_t
        ]);
}

module left_return_profile() {
    translate([-outer_w/2 + outer_corner_r, outer_corner_r])
    difference() {
        // Outer quarter-round corner plus straight return
        union() {
            intersection() {
                circle(r = outer_corner_r);

                translate([-outer_corner_r, -outer_corner_r])
                    square([outer_corner_r, outer_corner_r]);
            }

            translate([-outer_corner_r, 0])
                square([
                    wall_t,
                    return_depth - outer_corner_r
                ]);
        }

        // Remove inner curve, maintaining thin wall thickness
        intersection() {
            circle(r = inner_corner_r);

            translate([-inner_corner_r, -inner_corner_r])
                square([inner_corner_r, inner_corner_r]);
        }
    }
}

module right_return_profile() {
    mirror([1, 0, 0])
        left_return_profile();
}

module bottom_cover_profile_2d() {
    union() {
        front_wall_profile();
        left_return_profile();
        right_return_profile();
    }
}

// ============================================================
// BODY
// ============================================================

module cover_body() {
    linear_extrude(height = cover_h)
        bottom_cover_profile_2d();
}

// ============================================================
// USB-C OPENING
// ============================================================

module usb_opening() {
    translate([
        usb_x,
        wall_t + 0.5,
        usb_z
    ])
    rotate([90, 0, 0])
    linear_extrude(height = wall_t + 1.0)
        rounded_slot_2d(
            usb_open_w,
            usb_open_h
        );
}

// ============================================================
// FINAL PART
// ============================================================

module bottom_cover() {
    difference() {
        cover_body();
        usb_opening();
    }
}

bottom_cover();

// ============================================================
// OPTIONAL STL OVERLAY
// ============================================================
//
// Place Bottom_Cover.stl in the same folder as this file.
// Uncomment and position as needed for comparison:
//
// %scale([1000, 1000, 1000])
//     import("Bottom_Cover.stl", convexity = 10);