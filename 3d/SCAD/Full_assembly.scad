// Combined phone assembly + internal components
// Keep this file in the same folder as:
// - Case_assembly.scad
// - components.scad

// -------------------------
// Global display controls
// -------------------------

show_case = true;
show_components = true;

// Move / rotate the whole finished assembly here if needed
assembly_offset = [0, 0, 0];
assembly_rotation = [0, 0, 0];

// Optional visual separation while checking fit
components_offset = [0, 0, 0];
components_rotation = [0, 0, 0];

case_offset = [0, 0, 0];
case_rotation = [0, 0, 0];

// -------------------------
// Bring in the two files
// -------------------------

use <Case_assembly.scad>
use <components.scad>

// -------------------------
// Safe module wrappers
// -------------------------
//
// These assume:
//   Case_assembly.scad has module all_case_parts()
//   components.scad has module all_components()
//
// If your files use different final module names, change only these two wrappers.

module case_assembly_part() {
  all_case_parts();
}

module components_part() {
  all_components();
}

// -------------------------
// Combined assembly
// -------------------------

module phone_complete_assembly() {
  translate(assembly_offset)
  rotate(assembly_rotation)
  union() {
    if (show_case) {
      translate(case_offset)
      rotate(case_rotation)
      case_assembly_part();
    }

    if (show_components) {
      translate(components_offset)
      rotate(components_rotation)
      components_part();
    }
  }
}

// -------------------------
// Render
// -------------------------

phone_complete_assembly();