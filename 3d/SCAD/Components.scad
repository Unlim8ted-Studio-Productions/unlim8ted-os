// Low-poly bounding-box OpenSCAD approximation generated from Components.glb
// Units: millimeters. Each logical object is translated to its original scene offset.
// This is intentionally simplified: grouped submeshes become boxes; curved/wire/screw-like parts use low-$fn cylinders where practical.

$fn = 10;

module box_at(pos, size) {
  translate(pos) cube(size, center = true);
}

module cyl_x(pos, h, r) { translate(pos) rotate([0, 90, 0]) cylinder(h = h, r = r, center = true); }
module cyl_y(pos, h, r) { translate(pos) rotate([90, 0, 0]) cylinder(h = h, r = r, center = true); }
module cyl_z(pos, h, r) { translate(pos) cylinder(h = h, r = r, center = true); }

module rounded_box_xz(pos, size, r = 2) {
  translate(pos)
  hull() {
    for (sx = [-1, 1], sz = [-1, 1])
      translate([sx * max(size[0] / 2 - r, 0), 0, sz * max(size[2] / 2 - r, 0)])
        rotate([90, 0, 0]) cylinder(h = size[1], r = r, center = true);
  }
}

// Object: 3mm.001
// Scene offset / object center: [-24.129, 48.872, -104.88]
// Overall bounds size: [5, 4.5, 5]
// Source mesh nodes: 1; SCAD primitives: 1; Approximation: submesh bounding primitives
module obj_3mm_001() {
  translate([-24.129, 48.872, -104.88])
  color([0.35, 0.38, 0.44, 0.72])
  union() {
    // 3mm.001
    cyl_y([0, 0, 0], 4.5, 2.5);
  }
}

// Object: 3mm.002
// Scene offset / object center: [-3.568, 48.872, -104.878]
// Overall bounds size: [5, 4.5, 5]
// Source mesh nodes: 1; SCAD primitives: 1; Approximation: submesh bounding primitives
module obj_3mm_002() {
  translate([-3.568, 48.872, -104.878])
  color([0.38, 0.28, 0.52, 0.72])
  union() {
    // 3mm.002
    cyl_y([0, 0, 0], 4.5, 2.5);
  }
}

// Object: Lipo ChargerBooster
// Scene offset / object center: [-13.773, 52.553, -94.986]
// Overall bounds size: [26.473, 7.804, 43.015]
// Source mesh nodes: 33; SCAD primitives: 33; Approximation: submesh bounding primitives
module Lipo_ChargerBooster() {
  translate([-13.773, 52.553, -94.986])
  color([0.18, 0.26, 0.45, 0.82])
  union() {
    // Lipo ChargerBooster_276ccf
    box_at([2.738, 0.336, 12.578], [20.996, 6.533, 16.094]);
    // Lipo ChargerBooster_6f977b
    box_at([-0.37, 0.75, 16.486], [16.5, 6.304, 10.043]);
    // Lipo ChargerBooster_5b1451
    cyl_y([-0.372, -0.056, 14.652], 4.69, 4.275);
    // Lipo ChargerBooster_847761
    box_at([-5.651, -1.712, -1.953], [13.115, 1.234, 24.295]);
    // Lipo ChargerBooster_cbc7d0
    box_at([-5.651, -1.712, -1.953], [13.136, 1.245, 24.511]);
    // Lipo ChargerBooster_ca6104
    box_at([0.916, -1.668, -1.555], [20.101, 1.362, 20.666]);
    // Lipo ChargerBooster_e20abf
    box_at([-0.893, -1.528, -0.796], [16.483, 1.55, 21.894]);
    // Lipo ChargerBooster_937206
    box_at([0.779, -1.539, 1.164], [15.215, 1.566, 17.331]);
    // Lipo ChargerBooster_cdaa85
    box_at([-5.323, -2.077, -8.494], [4.44, 0.54, 3.199]);
    // Lipo ChargerBooster_d05c2a
    box_at([-5.323, -2.077, -8.494], [4.5, 0.6, 3.201]);
    // Lipo ChargerBooster_1dd595
    box_at([-5.317, -1.767, -8.547], [3.347, 0.25, 1.254]);
    // Lipo ChargerBooster_836930
    box_at([-5.323, -1.787, -8.494], [3.5, 0.25, 3.201]);
    // Lipo ChargerBooster_626a7b
    box_at([10.433, -2.337, -2.883], [1.064, 0.25, 9.436]);
    // Lipo ChargerBooster_3de926
    box_at([10.408, -2.337, -2.883], [0.263, 0.25, 9.436]);
    // Lipo ChargerBooster_223cb1
    box_at([10.433, -2.092, -2.883], [0.365, 0.25, 9.236]);
    // Lipo ChargerBooster_e7907c
    box_at([-2.021, -2.162, -1.572], [14.229, 0.354, 20.701]);
    // Lipo ChargerBooster_b4a1c6
    box_at([-2.91, -1.997, -0.112], [3.85, 0.7, 0.651]);
    // Lipo ChargerBooster_9d62a3
    box_at([-2.91, -1.622, -0.112], [2.85, 1.25, 1.7]);
    // Lipo ChargerBooster_8fa787
    box_at([-3.418, -1.897, 3.19], [3, 0.9, 3]);
    // Lipo ChargerBooster_5280fe
    box_at([-3.418, -2.297, 3.19], [3, 0.25, 2.401]);
    // Lipo ChargerBooster_778d13
    box_at([5.472, -0.447, -15.26], [9, 3.802, 10.2]);
    // Lipo ChargerBooster_8fd84f
    box_at([5.472, 0.653, -5.772], [9.999, 6, 29.175]);
    // Lipo ChargerBooster_099a77
    cyl_y([5.472, -1.047, 0.015], 1.601, 1.55);
    // Lipo ChargerBooster_d129c8
    box_at([5.472, -1.047, 0.015], [4.5, 2.601, 3.201]);
    // Lipo ChargerBooster_ecd3a2
    box_at([3.855, -1.962, 3.683], [3, 0.86, 3]);
    // Lipo ChargerBooster_f40a36
    box_at([3.855, -1.727, 3.683], [1.75, 1.25, 3]);
    // Lipo ChargerBooster_c2d7a2
    box_at([-6.243, -1.772, 5.592], [2.2, 1.05, 1.35]);
    // Lipo ChargerBooster_0d2728
    box_at([-6.243, -1.947, 5.592], [1.6, 0.8, 2.4]);
    // Lipo ChargerBooster_ae8964
    box_at([8.894, -1.634, 7.862], [3.69, 1.422, 7.975]);
    // Lipo ChargerBooster_f8ab82
    box_at([-5.958, -1.207, -17.458], [8.34, 3.589, 6.499]);
    // Lipo ChargerBooster_c11426
    box_at([-5.958, -1.332, -17.208], [7.101, 1.98, 7.2]);
    // Lipo ChargerBooster_ac6f19
    box_at([-5.958, -1.212, -17.859], [8.94, 4.201, 7.298]);
    // Lipo ChargerBooster_dd8da6
    box_at([-0.497, -3.124, -0.247], [25.479, 1.557, 40.876]);
  }
}

// Object: JST Lipo Connector
// Scene offset / object center: [-26.493, 49.271, -85.756]
// Overall bounds size: [43.207, 9.739, 67.445]
// Source mesh nodes: 1; SCAD primitives: 49; Approximation: voxel surface boxes
module JST_Lipo_Connector() {
  translate([-26.493, 49.271, -85.756])
  color([0.85, 0.32, 0.12, 0.82])
  union() {
    // JST Lipo Connector
    box_at([-19.496, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -27.399], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -23.184], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -18.969], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -14.753], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -10.538], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -6.323], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, -2.108], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 2.108], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 6.323], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 10.538], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 14.753], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 18.969], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, -2.762, 23.184], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, 1.453, 18.969], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, 1.453, 23.184], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, 1.453, 27.399], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-19.496, 1.453, 31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-15.28, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-15.28, 1.453, 31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-11.065, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-11.065, 1.453, 31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-11.065, 1.453, 33.722], [4.215, 4.215, 0.35]);
    // JST Lipo Connector
    box_at([-6.85, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-6.85, 1.453, 31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([-2.634, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([1.581, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([5.796, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([10.011, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([14.227, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 1.453, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 1.453, -27.399], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 1.453, -23.184], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 4.215, -31.615], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 4.215, -27.399], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([14.227, 4.215, -23.184], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([18.442, -2.762, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 1.453, -31.615], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 1.453, -27.399], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 1.453, -23.184], [4.215, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 4.215, -31.615], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 4.215, -27.399], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([18.442, 4.215, -23.184], [4.215, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 1.453, -31.615], [1.054, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 1.453, -27.399], [1.054, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 1.453, -23.184], [1.054, 4.215, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 4.215, -31.615], [1.054, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 4.215, -27.399], [1.054, 1.309, 4.215]);
    // JST Lipo Connector
    box_at([21.076, 4.215, -23.184], [1.054, 1.309, 4.215]);
  }
}

// Object: 3mm.003
// Scene offset / object center: [-3.589, 48.872, -77.342]
// Overall bounds size: [5, 4.5, 5]
// Source mesh nodes: 1; SCAD primitives: 1; Approximation: submesh bounding primitives
module obj_3mm_003() {
  translate([-3.589, 48.872, -77.342])
  color([0.36, 0.36, 0.36, 0.72])
  union() {
    // 3mm.003
    cyl_y([0, 0, 0], 4.5, 2.5);
  }
}

// Object: 3mm
// Scene offset / object center: [-23.984, 48.872, -77.303]
// Overall bounds size: [5, 4.5, 5]
// Source mesh nodes: 1; SCAD primitives: 1; Approximation: submesh bounding primitives
module obj_3mm() {
  translate([-23.984, 48.872, -77.303])
  color([0.35, 0.38, 0.44, 0.72])
  union() {
    // 3mm
    cyl_y([0, 0, 0], 4.5, 2.5);
  }
}

// Object: Display
// Scene offset / object center: [-18.158, 45.383, -43.555]
// Overall bounds size: [74.727, 14.111, 159.18]
// Source mesh nodes: 34; SCAD primitives: 34; Approximation: submesh bounding primitives
module Display() {
  translate([-18.158, 45.383, -43.555])
  color([0.06, 0.08, 0.12, 0.82])
  union() {
    // Display_1a2bcf
    box_at([0.001, -0.195, 39.625], [22, 2.503, 6.749]);
    // Display_5f02a1
    box_at([0.001, -0.245, 41.751], [22, 2.396, 2.492]);
    // Display_93deb5
    box_at([0.001, 0.855, 38.614], [21.278, 0.25, 1.829]);
    // Display_1eb1da
    box_at([-17.459, -0.226, 16.158], [10.454, 4.056, 57.684]);
    // Display_f3c910
    box_at([0.001, 1.725, 11.5], [54.504, 9.647, 63.5]);
    // Display_6bfed3
    box_at([-20.56, 0.705, -8.618], [4.49, 0.3, 2]);
    // Display_21c11e
    box_at([-24.499, 2.005, 31.82], [4.741, 10.1, 4.741]);
    // Display_a15543
    box_at([0, -2.995, 0], [74.727, 8.084, 159.18]);
    // Display_1f5354
    box_at([-22.499, 1.405, 19], [8, 5.698, 13.5]);
    // Display_0b5edd
    box_at([-20.799, -0.445, -34.8], [7.1, 2.098, 6.4]);
    // Display_b60c53
    box_at([-0.044, -1.02, 28.189], [4, 0.85, 2.499]);
    // Display_f38c0d
    box_at([-0.044, -1.445, 28.189], [4, 0.25, 2.499]);
    // Display_f8f212
    box_at([8.715, -0.44, -8.724], [29.805, 1.997, 58.436]);
    // Display_f1c833
    box_at([-11.245, -1.045, -34.448], [0.7, 0.4, 1]);
    // Display_fd4330
    box_at([-11.245, -1.446, -34.448], [0.8, 0.25, 0.4]);
    // Display_134a31
    box_at([-11.245, -1.345, -34.448], [0.8, 0.25, 1.6]);
    // Display_b7cff7
    box_at([-9.694, -0.592, 25.749], [2.489, 1.704, 3.2]);
    // Display_89aaea
    box_at([0, -3.68, -2.162], [68.714, 4.118, 150.6]);
    // Display_f2db55
    box_at([0.097, -2.915, -62.883], [23.993, 0.25, 1.465]);
    // Display_5b71e6
    box_at([0, -6.395, 0], [74.727, 1.321, 159.18]);
    // Display_96cbb3
    box_at([-3.451, -1.626, -46.493], [38.295, 1.907, 23.235]);
    // Display_71dcf6
    box_at([1.645, -0.743, -3.534], [53.095, 2.207, 76.483]);
    // Display_329bcb
    box_at([-8.992, -1.072, -2.132], [7.798, 0.659, 43.625]);
    // Display_d68c2f
    box_at([0, -2.243, -0.003], [56.018, 1.591, 87.996]);
    // Display_856316
    box_at([-9.022, -0.432, -2.195], [12.183, 1.962, 35.324]);
    // Display_752e1e
    box_at([-3.416, -1.207, -0.28], [42.943, 0.409, 69.935]);
    // Display_e4a61d
    box_at([-18.035, -0.296, -20.956], [13.422, 2.306, 30.864]);
    // Display_a984dc
    box_at([-11.296, -0.296, -3.549], [26.384, 2.284, 65.882]);
    // Display_03968a
    box_at([-10.062, -0.202, -0.963], [30.807, 2.476, 71.51]);
    // Display_9d512f
    box_at([-20.561, -0.293, -8.617], [6.212, 2.298, 6.202]);
    // Display_bc9025
    box_at([-9.693, -0.594, 25.749], [2.488, 1.701, 4.001]);
    // Display_2369cc
    box_at([-11.245, -1.347, -34.449], [0.805, 0.25, 0.799]);
    // Display_dc1f7f
    box_at([-0.186, -3.315, 38.036], [54.554, 0.506, 8.421]);
    // Display_685ce2
    box_at([-0.618, -3.316, -37.051], [52.32, 0.51, 10.835]);
  }
}

// Object: Battery
// Scene offset / object center: [-11.634, 51.927, -32.073]
// Overall bounds size: [48.802, 9, 51.002]
// Source mesh nodes: 2; SCAD primitives: 2; Approximation: submesh bounding primitives
module Battery() {
  translate([-11.634, 51.927, -32.073])
  color([0.1, 0.6, 0.35, 0.82])
  union() {
    // Battery_6a4a33
    rounded_box_xz([0, 0, 4], [48.802, 9, 43.003], 3.44);
    // Battery_b397bd
    rounded_box_xz([0, 0, -21.453], [48.802, 9, 8.097], 1);
  }
}

// Object: Display Power GND
// Scene offset / object center: [-27.023, 51.977, -5.347]
// Overall bounds size: [55.431, 9.613, 36.838]
// Source mesh nodes: 1; SCAD primitives: 36; Approximation: voxel surface boxes
module Display_Power_GND() {
  translate([-27.023, 51.977, -5.347])
  color([0.08, 0.08, 0.08, 0.78])
  union() {
    // Display Power GND
    box_at([-25.983, -3.074, -13.222], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, -3.074, -9.758], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, -3.074, -6.293], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, -3.074, -2.829], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, -3.074, 0.635], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, 0.39, -2.829], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-25.983, 0.39, 0.635], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-22.519, -3.074, -16.687], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-22.519, -3.074, -13.222], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-22.519, 0.39, 0.635], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-22.519, 0.39, 4.1], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-19.054, -3.074, -16.687], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-19.054, 0.39, 4.1], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-19.054, 3.464, 4.1], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-15.59, -3.074, -16.687], [3.464, 3.464, 3.464]);
    // Display Power GND
    box_at([-15.59, 3.464, 4.1], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-15.59, 3.464, 7.564], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-12.126, 3.464, 7.564], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-8.661, 3.464, 7.564], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-5.197, 3.464, 7.564], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-5.197, 3.464, 11.029], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([-1.732, 3.464, 11.029], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([1.732, 3.464, 11.029], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([5.197, 3.464, 11.029], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([5.197, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([8.661, 3.464, 11.029], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([8.661, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([12.126, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([15.59, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([19.054, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([22.519, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([22.519, 3.464, 17.322], [3.464, 2.684, 2.194]);
    // Display Power GND
    box_at([25.983, 0.39, 17.322], [3.464, 3.464, 2.194]);
    // Display Power GND
    box_at([25.983, 3.464, 14.493], [3.464, 2.684, 3.464]);
    // Display Power GND
    box_at([25.983, 3.464, 17.322], [3.464, 2.684, 2.194]);
    // Display Power GND
    box_at([27.716, 0.39, 17.322], [0.35, 3.464, 2.194]);
  }
}

// Object: Display Power 5v
// Scene offset / object center: [-27.414, 52.227, -3.628]
// Overall bounds size: [57.962, 10.556, 36.123]
// Source mesh nodes: 1; SCAD primitives: 38; Approximation: voxel surface boxes
module Display_Power_5v() {
  translate([-27.414, 52.227, -3.628])
  color([0.8, 0.12, 0.1, 0.78])
  union() {
    // Display Power 5v
    box_at([-27.17, -3.467, -16.25], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-27.17, -3.467, -12.627], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-27.17, -3.467, -9.005], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-27.17, -3.467, -5.382], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-27.17, -3.467, -1.76], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-27.17, 0.156, -1.76], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-23.547, -3.467, -16.25], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-23.547, -3.467, -12.627], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-23.547, -3.467, -1.76], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-23.547, 0.156, -1.76], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-23.547, 0.156, 1.863], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-19.924, -3.467, -16.25], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-19.924, 0.156, 1.863], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-19.924, 0.156, 5.486], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-16.302, -3.467, -16.25], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-16.302, 0.156, 1.863], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-16.302, 0.156, 5.486], [3.623, 3.623, 3.623]);
    // Display Power 5v
    box_at([-16.302, 3.623, 1.863], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-16.302, 3.623, 5.486], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-12.679, 3.623, 5.486], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-9.057, 3.623, 5.486], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-9.057, 3.623, 9.108], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-5.434, 3.623, 9.108], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([-1.811, 3.623, 9.108], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([1.811, 3.623, 9.108], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([1.811, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([5.434, 3.623, 9.108], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([5.434, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([9.057, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([12.679, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([16.302, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([19.924, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([19.924, 3.623, 16.302], [3.623, 3.311, 3.519]);
    // Display Power 5v
    box_at([23.547, 3.623, 12.731], [3.623, 3.311, 3.623]);
    // Display Power 5v
    box_at([23.547, 3.623, 16.302], [3.623, 3.311, 3.519]);
    // Display Power 5v
    box_at([27.17, 0.156, 16.302], [3.623, 3.623, 3.519]);
    // Display Power 5v
    box_at([27.17, 3.623, 16.302], [3.623, 3.311, 3.519]);
    // Display Power 5v
    box_at([28.981, 0.156, 16.302], [0.35, 3.623, 3.519]);
  }
}

// Object: DSI Cable
// Scene offset / object center: [-18.793, 47.37, 20.374]
// Overall bounds size: [11.378, 13.474, 46.48]
// Source mesh nodes: 1; SCAD primitives: 104; Approximation: voxel surface boxes
module DSI_Cable() {
  translate([-18.793, 47.37, 20.374])
  color([0.85, 0.72, 0.18, 0.72])
  union() {
    // DSI Cable
    box_at([-4.237, -5.285, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, -15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, 7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, 10.167], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, 13.072], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, 15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -5.285, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -2.38, -21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -2.38, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, -2.38, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, 0.525, -21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, 0.525, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, 3.43, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, 3.43, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-4.237, 5.81, 15.977], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([-4.237, 5.81, 18.882], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([-4.237, 5.81, 21.787], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -13.072], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -10.167], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, -1.452], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 1.452], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 10.167], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 13.072], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -5.285, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -2.38, -21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -2.38, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, -2.38, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, 0.525, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, 3.43, 15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, 3.43, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, 3.43, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([-1.332, 5.81, 15.977], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([-1.332, 5.81, 18.882], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([-1.332, 5.81, 21.787], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -13.072], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -10.167], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, -1.452], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 1.452], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 10.167], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 13.072], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 15.977], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -5.285, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, -21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, -18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, -4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, 1.452], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, 4.357], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, 7.262], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, -2.38, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, 0.525, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, 3.43, 18.882], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, 3.43, 21.787], [2.905, 2.905, 2.905]);
    // DSI Cable
    box_at([1.573, 5.81, 18.882], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([1.573, 5.81, 21.787], [2.905, 1.855, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -18.882], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -15.977], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -13.072], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -10.167], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -7.262], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -4.357], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, -1.452], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 1.452], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 4.357], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 7.262], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 10.167], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 13.072], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -5.285, 15.977], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -21.787], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -18.882], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -15.977], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -13.072], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -10.167], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -7.262], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -4.357], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, -1.452], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 1.452], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 4.357], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 7.262], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 10.167], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 13.072], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 15.977], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 18.882], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, -2.38, 21.787], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, 0.525, 21.787], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, 0.525, 23.24], [2.664, 2.905, 0.35]);
    // DSI Cable
    box_at([4.357, 3.43, 18.882], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, 3.43, 21.787], [2.664, 2.905, 2.905]);
    // DSI Cable
    box_at([4.357, 5.81, 18.882], [2.664, 1.855, 2.905]);
    // DSI Cable
    box_at([4.357, 5.81, 21.787], [2.664, 1.855, 2.905]);
  }
}

// Object: Baseboard
// Scene offset / object center: [-20.265, 57.845, 20.87]
// Overall bounds size: [55.017, 22.554, 41.458]
// Source mesh nodes: 39; SCAD primitives: 39; Approximation: submesh bounding primitives
module Baseboard() {
  translate([-20.265, 57.845, 20.87])
  color([0.05, 0.36, 0.22, 0.82])
  union() {
    // Baseboard_cb1e25
    box_at([19.176, -5.596, -16.875], [9.58, 4.161, 7.708]);
    // Baseboard_27641b
    box_at([0.04, -6.008, -9.482], [49.367, 5.906, 3.64]);
    // Baseboard_ac6e91
    box_at([0.029, -6.215, -9.464], [50.582, 1.111, 4.866]);
    // Baseboard_534a4b
    box_at([-2.336, -5.765, -0.929], [44.265, 1.989, 9.211]);
    // Baseboard_ed4344
    box_at([-9.743, -6.275, 1.853], [2.65, 0.979, 8.218]);
    // Baseboard_ca14a4
    box_at([-9.908, -6.34, 1.86], [2.979, 0.85, 5.764]);
    // Baseboard_f91696
    box_at([19.998, -6.24, 16.779], [11.2, 5.449, 7.901]);
    // Baseboard_562122
    box_at([19.998, -5.09, 16.329], [7.35, 0.25, 4.801]);
    // Baseboard_0dcd62
    box_at([19.998, -5.315, 16.08], [11.25, 2.902, 5.501]);
    // Baseboard_0f1383
    box_at([-17.906, -3.865, 15.527], [12.499, 6.002, 9.447]);
    // Baseboard_9ac2d1
    cyl_y([-17.906, -4.787, 13.754], 4.006, 3.887);
    // Baseboard_4f7033
    box_at([-1.782, -7.572, -2.058], [42.672, 2.375, 32.626]);
    // Baseboard_19aa47
    box_at([2.493, -9.828, 0.698], [22.61, 2.898, 37.326]);
    // Baseboard_99e75e
    box_at([1.141, -7.571, -4.574], [42.74, 2.776, 26.936]);
    // Baseboard_6bcb4b
    box_at([-14.618, -6.24, -4.301], [3.2, 1.05, 2.5]);
    // Baseboard_732f29
    box_at([19.176, -5.596, -16.725], [8.34, 3.561, 7.407]);
    // Baseboard_a13625
    box_at([20.183, -5.761, -16.311], [2.765, 2.028, 6.58]);
    // Baseboard_8ab1ef
    box_at([20.201, -5.99, -16.411], [0.801, 1.57, 6.78]);
    // Baseboard_97c71d
    box_at([19.701, -5.761, -16.411], [1.799, 2.03, 6.78]);
    // Baseboard_6db775
    box_at([18.168, -5.761, -16.311], [2.765, 2.028, 6.58]);
    // Baseboard_3fe839
    box_at([17.75, -6.105, -0.13], [11.25, 1.319, 11.35]);
    // Baseboard_60b3ff
    box_at([15.075, -6.765, -5.58], [0.6, 0.25, 0.45]);
    // Baseboard_f7819a
    box_at([16.925, -6.155, -0.13], [9.301, 1.117, 11.05]);
    // Baseboard_fc0257
    box_at([-14.618, -6.34, -4.301], [3.2, 0.85, 2.5]);
    // Baseboard_eb36ab
    cyl_z([-1.488, 2.33, 0.603], 14.002, 9.621);
    // Baseboard_04778e
    box_at([1.817, 10.85, 0.603], [8.315, 0.85, 8.327]);
    // Baseboard_b3c4c1
    box_at([-2.965, -7.571, -6.344], [36.85, 2.536, 24.882]);
    // Baseboard_468e1a
    box_at([-6.269, -7.647, 1.756], [29.734, 2.861, 9.15]);
    // Baseboard_c336b8
    box_at([0, -7.573, 0.604], [55.017, 1.615, 40.021]);
    // Baseboard_1f5772
    box_at([-24.265, -5.751, 5.878], [4.003, 1.973, 4.397]);
    // Baseboard_a86008
    box_at([-0.495, -7.572, -7.735], [31.863, 2.508, 22.046]);
    // Baseboard_c994de
    box_at([1.142, -6.723, 0.959], [42.786, 4.516, 38.625]);
    // Baseboard_117cdf
    box_at([-6.676, -5.613, 0.576], [35.58, 3.696, 39.239]);
    // Baseboard_723ecd
    box_at([-4.575, -6.296, 0.799], [45.588, 6.256, 38.998]);
    // Baseboard_86cbd2
    box_at([-24.469, -5.765, -1.21], [5.801, 1.998, 8.65]);
    // Baseboard_90dead
    box_at([-17.906, -4.615, 15.704], [14.3, 9.299, 9.996]);
    // Baseboard_0f831f
    box_at([-14.618, -6.291, -4.302], [3.201, 0.951, 2.502]);
    // Baseboard_c5b3f8
    box_at([20.001, -5.761, -16.586], [5.401, 2.031, 7.129]);
    // Baseboard_89a858
    box_at([18.349, -5.759, -16.585], [5.398, 2.028, 7.128]);
  }
}

// Object: CM4
// Scene offset / object center: [-20.413, 44.701, 21.606]
// Overall bounds size: [55, 4.787, 40.007]
// Source mesh nodes: 31; SCAD primitives: 31; Approximation: submesh bounding primitives
module CM4() {
  translate([-20.413, 44.701, 21.606])
  color([0.06, 0.24, 0.16, 0.82])
  union() {
    // CM4_003b59
    box_at([0.59, 0.669, -0.301], [52.785, 1.134, 37.984]);
    // CM4_7f2054
    box_at([-13.98, 0.083, -13.94], [7, 0.25, 7]);
    // CM4_70183a
    box_at([0.581, 0.669, -1.169], [52.737, 2.833, 33.262]);
    // CM4_d3375e
    box_at([0.581, 0.669, -1.239], [52.717, 2.806, 33.095]);
    // CM4_1bf603
    box_at([-3.49, 0.819, -2.434], [27.918, 2.456, 31.433]);
    // CM4_3ad15f
    box_at([24.933, -0.517, -11], [3.1, 1.249, 3]);
    // CM4_70c101
    box_at([24.933, -0.092, -11], [2.6, 0.3, 2.6]);
    // CM4_ff095b
    box_at([-20.036, -0.091, 3.025], [9.113, 0.314, 13.962]);
    // CM4_8cf098
    box_at([-0.282, 0.726, -2.587], [51.361, 2.408, 33.899]);
    // CM4_09cf51
    box_at([-14.142, -0.592, -14.128], [5.526, 1.4, 5.575]);
    // CM4_eb4cac
    box_at([-3.118, 0.338, 0.005], [43.836, 4.11, 36.962]);
    // CM4_82a296
    box_at([-0.741, 0.669, -1.651], [49.056, 1.437, 32.09]);
    // CM4_631df7
    box_at([-0.691, 0.669, -1.601], [48.955, 1.434, 32.001]);
    // CM4_7604c4
    box_at([-0.731, 0.669, -1.641], [49.036, 1.413, 32.077]);
    // CM4_ed6d71
    box_at([-3.495, 0.814, -2.434], [27.876, 2.423, 31.403]);
    // CM4_29ce63
    box_at([0, 0.669, 0], [55, 1.047, 40.007]);
    // CM4_f1faa1
    box_at([5.143, 0.669, 11.208], [16.478, 1.883, 1.561]);
    // CM4_3453df
    box_at([-0.823, 0.659, -1.738], [47.35, 1.549, 24.729]);
    // CM4_f06c6d
    box_at([2.261, -0.293, -0.369], [46.933, 0.71, 24.785]);
    // CM4_21ca35
    box_at([2.005, -0.492, -0.113], [47.801, 1.214, 25.664]);
    // CM4_30ef55
    box_at([2.001, -0.014, -0.109], [47.553, 0.255, 25.415]);
    // CM4_24bc33
    box_at([-4.306, 1.855, -6.913], [21.388, 0.25, 17.021]);
    // CM4_88204d
    box_at([-4.294, 1.73, -6.925], [21.662, 0.25, 17.303]);
    // CM4_6a9ce5
    box_at([8.836, 0.435, 6.242], [12.627, 2.763, 8.186]);
    // CM4_e6417c
    box_at([2.176, 0.435, 3.025], [28.327, 2.767, 15.001]);
    // CM4_be4e75
    box_at([2.373, 0.613, 3.025], [27.738, 1.693, 14.012]);
    // CM4_584fc0
    box_at([0, 0.669, 0], [55, 1.155, 40.007]);
    // CM4_40d0c8
    box_at([-13.98, -0.616, -13.94], [7, 1.347, 7]);
    // CM4_c5a6cb
    box_at([-4.488, -1.72, 3.025], [14.6, 1.347, 14.6]);
    // CM4_68e806
    cyl_x([22.493, -0.682, 10.263], 0.25, 0.125);
    // CM4_972a49
    box_at([20.343, -0.322, 8.113], [5.01, 0.781, 5.01]);
  }
}

module all_components_raw() {
  obj_3mm_001();
  obj_3mm_002();
  Lipo_ChargerBooster();
  JST_Lipo_Connector();
  obj_3mm_003();
  obj_3mm();
  Display();
  Battery();
  Display_Power_GND();
  Display_Power_5v();
  DSI_Cable();
  Baseboard();
  CM4();
}

scene_rotate = [90, 0, 0];
scene_offset = [0, 0, 0];

module all_components() {
  translate(scene_offset)
  rotate(scene_rotate)
  all_components_raw();
}

all_components();

// Manifest
// - 3mm.001: module obj_3mm_001, offset [-24.129, 48.872, -104.88], size [5, 4.5, 5], source_nodes 1, primitives 1, submesh bounding primitives
// - 3mm.002: module obj_3mm_002, offset [-3.568, 48.872, -104.878], size [5, 4.5, 5], source_nodes 1, primitives 1, submesh bounding primitives
// - Lipo ChargerBooster: module Lipo_ChargerBooster, offset [-13.773, 52.553, -94.986], size [26.473, 7.804, 43.015], source_nodes 33, primitives 33, submesh bounding primitives
// - JST Lipo Connector: module JST_Lipo_Connector, offset [-26.493, 49.271, -85.756], size [43.207, 9.739, 67.445], source_nodes 1, primitives 49, voxel surface boxes
// - 3mm.003: module obj_3mm_003, offset [-3.589, 48.872, -77.342], size [5, 4.5, 5], source_nodes 1, primitives 1, submesh bounding primitives
// - 3mm: module obj_3mm, offset [-23.984, 48.872, -77.303], size [5, 4.5, 5], source_nodes 1, primitives 1, submesh bounding primitives
// - Display: module Display, offset [-18.158, 45.383, -43.555], size [74.727, 14.111, 159.18], source_nodes 34, primitives 34, submesh bounding primitives
// - Battery: module Battery, offset [-11.634, 51.927, -32.073], size [48.802, 9, 51.002], source_nodes 2, primitives 2, submesh bounding primitives
// - Display Power GND: module Display_Power_GND, offset [-27.023, 51.977, -5.347], size [55.431, 9.613, 36.838], source_nodes 1, primitives 36, voxel surface boxes
// - Display Power 5v: module Display_Power_5v, offset [-27.414, 52.227, -3.628], size [57.962, 10.556, 36.123], source_nodes 1, primitives 38, voxel surface boxes
// - DSI Cable: module DSI_Cable, offset [-18.793, 47.37, 20.374], size [11.378, 13.474, 46.48], source_nodes 1, primitives 104, voxel surface boxes
// - Baseboard: module Baseboard, offset [-20.265, 57.845, 20.87], size [55.017, 22.554, 41.458], source_nodes 39, primitives 39, submesh bounding primitives
// - CM4: module CM4, offset [-20.413, 44.701, 21.606], size [55, 4.787, 40.007], source_nodes 31, primitives 31, submesh bounding primitives