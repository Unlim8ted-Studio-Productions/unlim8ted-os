// Auto-generated enclosure from KiCad board
// Board size: 75.75 x 167.50 mm, thickness: 1.60 mm
// Inner XY:   76.75 x 168.50 mm
// Outer XY:   81.75 x 173.50 mm


////////////////////
// PARAMETERS
////////////////////
outer_x = 81.750;
outer_y = 173.500;

inner_x = 76.750;
inner_y = 168.500;

wall      = 2.500;
bottom_h  = 4.800;
top_h     = 12.800;

lip_h         = 1.000;
lip_clearance = 0.200;

boss_r          = 3.500;
screw_clearance = 2.600;
screw_head_d    = 5.000;
screw_head_h    = 2.500;

// Board offset inside the case (so it's centered)
board_offset_x = wall + 0.500;
board_offset_y = wall + 0.500;
board_z        = 4.000;


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

        // Screw head pocket for hole at (22.20, 59.40)
        translate([7.250, 45.700, 0])
            cylinder(d=screw_head_d, h=screw_head_h, $fn=32);

        // Through hole for screw shaft
        translate([7.250, 45.700, 0])
            cylinder(d=screw_clearance, h=bottom_h + 0.5, $fn=24);

        // Screw head pocket for hole at (89.35, 144.95)
        translate([74.400, 131.250, 0])
            cylinder(d=screw_head_d, h=screw_head_h, $fn=32);

        // Through hole for screw shaft
        translate([74.400, 131.250, 0])
            cylinder(d=screw_clearance, h=bottom_h + 0.5, $fn=24);

        // Screw head pocket for hole at (22.20, 107.35)
        translate([7.250, 93.650, 0])
            cylinder(d=screw_head_d, h=screw_head_h, $fn=32);

        // Through hole for screw shaft
        translate([7.250, 93.650, 0])
            cylinder(d=screw_clearance, h=bottom_h + 0.5, $fn=24);

        // Screw head pocket for hole at (89.35, 107.35)
        translate([74.400, 93.650, 0])
            cylinder(d=screw_head_d, h=screw_head_h, $fn=32);

        // Through hole for screw shaft
        translate([74.400, 93.650, 0])
            cylinder(d=screw_clearance, h=bottom_h + 0.5, $fn=24);

    }


    // Bosses around mounting holes

    translate([7.250, 45.700, board_z])
        cylinder(r=boss_r, h=bottom_h - board_z, $fn=32);

    translate([74.400, 131.250, board_z])
        cylinder(r=boss_r, h=bottom_h - board_z, $fn=32);

    translate([7.250, 93.650, board_z])
        cylinder(r=boss_r, h=bottom_h - board_z, $fn=32);

    translate([74.400, 93.650, board_z])
        cylinder(r=boss_r, h=bottom_h - board_z, $fn=32);

}


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

    // Boss hole in top for screw tip or insert
    translate([7.250, 45.700, 0])
        cylinder(d=screw_clearance, h=top_h, $fn=24);

    // Boss hole in top for screw tip or insert
    translate([74.400, 131.250, 0])
        cylinder(d=screw_clearance, h=top_h, $fn=24);

    // Boss hole in top for screw tip or insert
    translate([7.250, 93.650, 0])
        cylinder(d=screw_clearance, h=top_h, $fn=24);

    // Boss hole in top for screw tip or insert
    translate([74.400, 93.650, 0])
        cylinder(d=screw_clearance, h=top_h, $fn=24);

}


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
