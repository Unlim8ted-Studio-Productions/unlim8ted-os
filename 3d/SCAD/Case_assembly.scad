// ============================================================
// phoneV14_offsets_assembly.scad
// Generated from phoneV14.glb
//
// Coordinate conversion used:
//   GLB world in millimeters: [X, Y_thickness, Z_length]
//   OpenSCAD build axes:     [X, Y_length,   Z_height]
//   Conversion: build = [glb_x, -glb_z, glb_y]
//
// The object named "Plane" in phoneV14.glb is treated as:
//   Compute_module_holder.scad / compute_module_plane()
//
// Put this file in the same folder as the uploaded .scad parts.
// ============================================================

$fn = 96;

// View toggles
show_main_case = true;
show_back_cover = true;
show_camera_bump = true;
show_bottom_cover = true;
show_type_c_entrance = true;
show_battery_holder = true;
show_battery_controller_holder = true;
show_compute_module_holder = true;
show_internal_components_low_poly = false; // optional: uses components_low_poly_bounding_boxes(1).scad

// ------------------------------------------------------------
// Load modules from the source SCAD files.
// use<> prevents each file's top-level preview call from rendering.
// Battery_holder.scad has no root module, so it is included inside
// a wrapper module lower down.
// ------------------------------------------------------------

use <main_case.scad>
use <Back_cover.scad>
use <Bottom_cover.scad>
use <Battery_controller_holder.scad>
use <Compute_module_holder.scad>
use <Camera_bump.scad>
use <TypeC_entrance.scad>
use <Battery_holder.scad>
use <components_low_poly_bounding_boxes(1).scad>

// ------------------------------------------------------------
// Extracted offsets from phoneV14.glb
// All values are millimeters in the OpenSCAD build coordinate system.
// target_center = converted GLB object center
// local_center  = estimated center/reference point of the SCAD module
// placement     = target_center - local_center
// ------------------------------------------------------------

// Main Case
//   GLB node: Main Case
//   GLB center mm:        [-18.219, 47.589, -39.955]
//   Converted center mm:  [-18.219, 39.955, 47.589]
//   Converted extents mm: [77.099, 166.396, 20.565]
//   GLB node Main Case; SCAD origin is centered in X/Y with bottom at Z=0.
main_case_target_center = [-18.219, 39.955, 47.589];
main_case_local_center  = [0.000, 0.000, 10.283];
main_case_placement     = [-18.219, 39.955, 37.306];

// Back Cover
//   GLB node: Back Cover
//   GLB center mm:        [-18.111, 57.925, -40.064]
//   Converted center mm:  [-18.111, 40.064, 57.925]
//   Converted extents mm: [76.937, 166.178, 0.000]
//   GLB node is a flat back-cover plane; using local Z=0 as the cover reference plane.
back_cover_target_center = [-18.111, 40.064, 57.925];
back_cover_local_center  = [0.000, 0.000, 0.000];
back_cover_placement     = [-18.111, 40.064, 57.925];

// Back Cover Camera Bump
//   GLB node: Back Cover Camera Bump
//   GLB center mm:        [-18.337, 63.825, 21.381]
//   Converted center mm:  [-18.337, -21.381, 63.825]
//   Converted extents mm: [32.155, 32.155, 10.162]
//   GLB camera bump center converted to SCAD build axes.
back_cover_camera_bump_target_center = [-18.337, -21.381, 63.825];
back_cover_camera_bump_local_center  = [0.000, 0.000, 5.081];
back_cover_camera_bump_placement     = [-18.337, -21.381, 58.744];

// Bottom Cover
//   GLB node: Bottom Cover
//   GLB center mm:        [-18.219, 48.086, -118.695]
//   Converted center mm:  [-18.219, 118.695, 48.086]
//   Converted extents mm: [77.112, 10.543, 19.571]
//   Bottom cover profile starts at Y=0 and extrudes upward from Z=0.
bottom_cover_target_center = [-18.219, 118.695, 48.086];
bottom_cover_local_center  = [0.000, 5.272, 9.786];
bottom_cover_placement     = [-18.219, 113.423, 38.300];

// Type C Port Entrance
//   GLB node: Type C Port Entrance
//   GLB center mm:        [-19.860, 51.303, -119.871]
//   Converted center mm:  [-19.860, 119.871, 51.303]
//   Converted extents mm: [13.101, 7.441, 6.846]
//   Type-C SCAD large sleeve runs Y=0..original_depth; Z is around the rounded-slot center with lower key.
type_c_port_entrance_target_center = [-19.860, 119.871, 51.303];
type_c_port_entrance_local_center  = [0.000, 3.691, -0.875];
type_c_port_entrance_placement     = [-19.860, 116.179, 52.178];

// Battery Holder
//   GLB node: Battery Holder
//   GLB center mm:        [-15.905, 49.785, -31.718]
//   Converted center mm:  [-15.905, 31.718, 49.785]
//   Converted extents mm: [61.283, 64.161, 5.925]
//   This file has top-level geometry instead of a root module, so it is wrapped in battery_holder_source().
battery_holder_target_center = [-15.905, 31.718, 49.785];
battery_holder_local_center  = [0.000, 0.000, 2.963];
battery_holder_placement     = [-15.905, 31.718, 46.823];

// Battery Controller Holder
//   GLB node: Battery Controller Holder
//   GLB center mm:        [-18.212, 47.211, -98.354]
//   Converted center mm:  [-18.212, 98.354, 47.211]
//   Converted extents mm: [74.786, 49.628, 1.273]
//   Placed from GLB node Battery Controller Holder.
battery_controller_holder_target_center = [-18.212, 98.354, 47.211];
battery_controller_holder_local_center  = [0.000, 0.000, 0.626];
battery_controller_holder_placement     = [-18.212, 98.354, 46.585];

// Compute Module Holder
//   GLB node: Plane
//   GLB center mm:        [-17.907, 42.349, 21.724]
//   Converted center mm:  [-17.907, -21.724, 42.349]
//   Converted extents mm: [74.274, 41.035, 0.772]
//   User note: the object named Plane in the GLB is the compute module holder.
compute_module_holder_target_center = [-17.907, -21.724, 42.349];
compute_module_holder_local_center  = [0.000, 0.000, 0.398];
compute_module_holder_placement     = [-17.907, -21.724, 41.951];

// ------------------------------------------------------------
// Source wrappers
// ------------------------------------------------------------

// Battery_holder.scad does not define a final root module, so this
// wrapper recreates the file's final top-level assembly call using
// the modules from Battery_holder.scad.
module battery_holder_source() {
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
}

// Optional electronics/components file from the earlier GLB conversion.
// That file is already in GLB axes, so rotate([90,0,0]) converts it to
// the same OpenSCAD build axes used here.
module internal_components_low_poly_build_axes() {
    rotate([90, 0, 0])
        all_components();
}

// ------------------------------------------------------------
// Placement helpers
// ------------------------------------------------------------

module placed(name, placement) {
    echo(str(name, " placement = ", placement));
    translate(placement)
        children();
}

module placed_main_case() {
    placed("Main Case", main_case_placement)
        main_case();
}

module placed_back_cover() {
    placed("Back Cover", back_cover_placement)
        back_cover();
}

module placed_camera_bump() {
    placed("Back Cover Camera Bump", back_cover_camera_bump_placement)
        back_cover_camera_bump();
}

module placed_bottom_cover() {
    placed("Bottom Cover", bottom_cover_placement)
        bottom_cover();
}

module placed_type_c_entrance() {
    placed("Type C Port Entrance", type_c_port_entrance_placement)
        type_c_port_entrance();
}

module placed_battery_holder() {
    placed("Battery Holder", battery_holder_placement)
        battery_holder_source();
}

module placed_battery_controller_holder() {
    placed("Battery Controller Holder", battery_controller_holder_placement)
        battery_controller_holder();
}

module placed_compute_module_holder() {
    placed("Compute Module Holder / Plane", compute_module_holder_placement)
        compute_module_plane();
}

// ------------------------------------------------------------
// Final assembly
// ------------------------------------------------------------

module all_case_parts() {
    if (show_main_case)
        color([0.22, 0.24, 0.28, 0.55]) placed_main_case();

    if (show_back_cover)
        color([0.22, 0.22, 0.24, 0.45]) placed_back_cover();

    if (show_camera_bump)
        color([0.18, 0.18, 0.20, 0.65]) placed_camera_bump();

    if (show_bottom_cover)
        color([0.30, 0.30, 0.34, 0.70]) placed_bottom_cover();

    if (show_type_c_entrance)
        color([0.45, 0.45, 0.50, 0.85]) placed_type_c_entrance();

    if (show_battery_holder)
        color([0.10, 0.55, 0.32, 0.70]) placed_battery_holder();

    if (show_battery_controller_holder)
        color([0.08, 0.28, 0.55, 0.75]) placed_battery_controller_holder();

    if (show_compute_module_holder)
        color([0.10, 0.36, 0.65, 0.75]) placed_compute_module_holder();

    if (show_internal_components_low_poly)
        internal_components_low_poly_build_axes();
}

all_case_parts();

