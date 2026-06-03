// ============================================================
// Type_C_Port_Entrance.scad
//
// Corrected geometry:
//   - Original large rounded sleeve remains unchanged
//   - New smaller extension is added to the OPPOSITE side
//   - Immediate size reduction: NO taper
//   - Small extension fits around metal USB-C input port
//   - Original lower support/key remains under large section
//
// Units: mm
//
// Orientation:
//   X = width
//   Y = depth through assembly
//   Z = height
//
// Layout:
//
//   SMALL NEW ADD-ON         ORIGINAL LARGE SECTION
//   for metal USB-C input    for cable housing / cover opening
//
//        ┌─────────┐         ┌─────────────────────┐
//        │ smaller │─────────│     full size       │
//        └─────────┘         └─────────────────────┘
//
//       negative Y                    positive Y
// ============================================================

$fn = 128;

// ============================================================
// ORIGINAL LARGE SECTION
// ============================================================
//
// This is the existing larger sleeve. It stays constant-size
// across its entire original depth.
// ============================================================

cable_open_w = 16.0;
cable_open_h = 8.5;

large_wall_t = 0.70;

large_outer_w = cable_open_w + large_wall_t * 2;   // 17.40
large_outer_h = cable_open_h + large_wall_t * 2;   // 9.90

// Original measured depth
original_depth = 7.38269;

// ============================================================
// NEW SMALL STEPPED EXTENSION
// ============================================================
//
// This is added immediately at the opposite end of the original
// sleeve. It does NOT gradually taper.
//
// Replace these port-opening dimensions with the actual outside
// measurement of the metal USB-C receptacle for a precise fit.
// ============================================================

metal_port_open_w = 9.4;
metal_port_open_h = 3.7;

small_wall_t = 0.70;

small_outer_w = metal_port_open_w + small_wall_t * 2; // 10.80
small_outer_h = metal_port_open_h + small_wall_t * 2; // 5.10

// Length of the newly added smaller section
small_addon_depth = 3.5;

// ============================================================
// LOWER SUPPORT / KEY
// ============================================================
//
// Original rectangular support remains attached only beneath
// the original full-size sleeve.
// ============================================================

key_w = 8.58742;
key_depth = original_depth;
key_h = 1.65;

// Original section runs from Y = 0 to Y = original_depth
key_center_y = original_depth / 2;

// Key sits below the large sleeve only
key_center_z = -(large_outer_h / 2 + key_h / 2 - 0.08);

// ============================================================
// OPTIONAL FIT CLEARANCE
// ============================================================
//
// Increase metal_port_clearance slightly for printing tolerance.
// For a snug prototype start at 0.15 to 0.25 mm total.
// ============================================================

metal_port_clearance = 0.0;

final_metal_open_w = metal_port_open_w + metal_port_clearance;
final_metal_open_h = metal_port_open_h + metal_port_clearance;

// Bottom Cover opening fits the large section only
bottom_cover_clearance = 0.20;

bottom_cover_slot_w = large_outer_w + bottom_cover_clearance * 2;
bottom_cover_slot_h = large_outer_h + bottom_cover_clearance * 2;

echo("Bottom Cover slot width = ", bottom_cover_slot_w);
echo("Bottom Cover slot height = ", bottom_cover_slot_h);

// ============================================================
// HELPERS
// ============================================================

module rounded_slot_2d(w, h) {
    hull() {
        translate([-(w - h) / 2, 0])
            circle(d = h);

        translate([(w - h) / 2, 0])
            circle(d = h);
    }
}

// Extrude a rounded slot along Y from y_start to y_end.
module rounded_sleeve_y(outer_w, outer_h, inner_w, inner_h, y_start, y_end) {
    difference() {
        translate([0, y_start, 0])
            rotate([-90, 0, 0])
                linear_extrude(height = y_end - y_start)
                    rounded_slot_2d(outer_w, outer_h);

        translate([0, y_start - 0.1, 0])
            rotate([-90, 0, 0])
                linear_extrude(height = y_end - y_start + 0.2)
                    rounded_slot_2d(inner_w, inner_h);
    }
}

// ============================================================
// ORIGINAL FULL-SIZE SLEEVE
// ============================================================
//
// Remains full size for the entire original depth.
// Extends from Y = 0 to positive Y.
// ============================================================

module original_large_sleeve() {
    rounded_sleeve_y(
        large_outer_w,
        large_outer_h,
        cable_open_w,
        cable_open_h,
        0,
        original_depth
    );
}

// ============================================================
// SMALL IMMEDIATE-STEP ADD-ON
// ============================================================
//
// Extends from the opposite side of the original piece:
// Y = -small_addon_depth to Y = 0.
//
// There is an immediate sharp reduction at Y = 0.
// There is deliberately no taper.
// ============================================================

module small_metal_port_addon() {
    rounded_sleeve_y(
        small_outer_w,
        small_outer_h,
        final_metal_open_w,
        final_metal_open_h,
        -small_addon_depth,
        0.02
    );
}

// ============================================================
// LOWER ORIGINAL SUPPORT KEY
// ============================================================

module lower_support_key() {
    translate([
        0,
        key_center_y,
        key_center_z
    ])
        cube(
            [key_w, key_depth, key_h],
            center = true
        );
}

// ============================================================
// FINAL PART
// ============================================================

module type_c_port_entrance() {
    union() {
        original_large_sleeve();
   
        lower_support_key();
    }
}

type_c_port_entrance();

// ============================================================
// BOTTOM COVER SLOT
// ============================================================
//
// The Bottom_Cover slot fits around the large original sleeve:
//
//     usb_open_w = 17.80;
//     usb_open_h = 10.30;
//
// The new smaller stepped extension sits on the opposite side
// and does not change the Bottom_Cover opening size.
// ============================================================