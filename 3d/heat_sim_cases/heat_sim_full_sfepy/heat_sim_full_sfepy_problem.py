import os

T0 = 25.0
filename_mesh = r"O:/unlim8ted-phone/3d/heat_sim_cases/heat_sim_full_sfepy/heat_sim_full.mesh"

materials = {
    'back_cover': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_back_cover': ({'val': 0.0},),
    'back_cover_camera_bump': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_back_cover_camera_bump': ({'val': 0.0},),
    'baseboard': ({'lam': 0.30000001192092896, 'rho_cp': 2220000.0},),
    'src_baseboard': ({'val': 67601.367389795},),
    'cm4': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_cm4': ({'val': 0.0},),
    'battery_holder': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_battery_holder': ({'val': 0.0},),
    'part6_3mm_004': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_part6_3mm_004': ({'val': 0.0},),
    'part7_3mm_005': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_part7_3mm_005': ({'val': 0.0},),
    'part8_3mm_006': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_part8_3mm_006': ({'val': 0.0},),
    'part9_3mm_007': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_part9_3mm_007': ({'val': 0.0},),
    'battery': ({'lam': 167.0, 'rho_cp': 2419200.0},),
    'src_battery': ({'val': 0.0},),
    'bottom_cover': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_bottom_cover': ({'val': 0.0},),
    'bttery_holder_001': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_bttery_holder_001': ({'val': 0.0},),
    'display': ({'lam': 3.200000047683716, 'rho_cp': 2160000.0},),
    'src_display': ({'val': 49990.06358060943},),
    'display_power_5v': ({'lam': 0.800000011920929, 'rho_cp': 1595000.0},),
    'src_display_power_5v': ({'val': 6385293.211077198},),
    'display_power_gnd': ({'lam': 0.800000011920929, 'rho_cp': 1595000.0},),
    'src_display_power_gnd': ({'val': 6287809.470563104},),
    'dsi_cable': ({'lam': 0.800000011920929, 'rho_cp': 1595000.0},),
    'src_dsi_cable': ({'val': 2940888.956451708},),
    'jst_lipo_connector': ({'lam': 0.800000011920929, 'rho_cp': 1595000.0},),
    'src_jst_lipo_connector': ({'val': 384664.6849851066},),
    'lipo_chargerbooster': ({'lam': 0.30000001192092896, 'rho_cp': 2220000.0},),
    'src_lipo_chargerbooster': ({'val': 341054.772258501},),
    'main_case': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_main_case': ({'val': 0.0},),
    'plane': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_plane': ({'val': 0.0},),
    'part21_3mm': ({'lam': 16.200000762939453, 'rho_cp': 3846500.0},),
    'src_part21_3mm': ({'val': 0.0},),
    'part22_3mm_001': ({'lam': 16.200000762939453, 'rho_cp': 3846500.0},),
    'src_part22_3mm_001': ({'val': 0.0},),
    'part23_3mm_002': ({'lam': 16.200000762939453, 'rho_cp': 3846500.0},),
    'src_part23_3mm_002': ({'val': 0.0},),
    'part24_3mm_003': ({'lam': 16.200000762939453, 'rho_cp': 3846500.0},),
    'src_part24_3mm_003': ({'val': 0.0},),
    'type_c_port_entrance': ({'lam': 0.12999999523162842, 'rho_cp': 2232000.0},),
    'src_type_c_port_entrance': ({'val': 0.0},),
    'typea_c_power_only_cable': ({'lam': 0.800000011920929, 'rho_cp': 1595000.0},),
    'src_typea_c_power_only_cable': ({'val': 101997.52840135548},),
    'env': ({'h': -8.0, 'T_inf': T0},),
}

regions = {
    'Omega': 'all',
    'Gamma_Exterior': ('vertices of surface *v r.Omega', 'facet'),
    'Omega_back_cover': 'cells of group 1',
    'Omega_back_cover_camera_bump': 'cells of group 2',
    'Omega_baseboard': 'cells of group 3',
    'Omega_cm4': 'cells of group 4',
    'Omega_battery_holder': 'cells of group 5',
    'Omega_part6_3mm_004': 'cells of group 6',
    'Omega_part7_3mm_005': 'cells of group 7',
    'Omega_part8_3mm_006': 'cells of group 8',
    'Omega_part9_3mm_007': 'cells of group 9',
    'Omega_battery': 'cells of group 10',
    'Omega_bottom_cover': 'cells of group 11',
    'Omega_bttery_holder_001': 'cells of group 12',
    'Omega_display': 'cells of group 13',
    'Omega_display_power_5v': 'cells of group 14',
    'Omega_display_power_gnd': 'cells of group 15',
    'Omega_dsi_cable': 'cells of group 16',
    'Omega_jst_lipo_connector': 'cells of group 17',
    'Omega_lipo_chargerbooster': 'cells of group 18',
    'Omega_main_case': 'cells of group 19',
    'Omega_plane': 'cells of group 20',
    'Omega_part21_3mm': 'cells of group 21',
    'Omega_part22_3mm_001': 'cells of group 22',
    'Omega_part23_3mm_002': 'cells of group 23',
    'Omega_part24_3mm_003': 'cells of group 24',
    'Omega_type_c_port_entrance': 'cells of group 25',
    'Omega_typea_c_power_only_cable': 'cells of group 26',
}

fields = {
    'temperature': ('real', 1, 'Omega', 1),
}

variables = {
    'T': ('unknown field', 'temperature', 1, 1),
    's': ('test field', 'temperature', 'T'),
}

integrals = {
    'i': 2,
}

equations = {
    'Temperature': """
        dw_dot.i.Omega_back_cover(back_cover.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_back_cover(back_cover.lam, s, T) \
        + dw_dot.i.Omega_back_cover_camera_bump(back_cover_camera_bump.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_back_cover_camera_bump(back_cover_camera_bump.lam, s, T) \
        + dw_dot.i.Omega_baseboard(baseboard.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_baseboard(baseboard.lam, s, T) \
        + dw_dot.i.Omega_cm4(cm4.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_cm4(cm4.lam, s, T) \
        + dw_dot.i.Omega_battery_holder(battery_holder.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_battery_holder(battery_holder.lam, s, T) \
        + dw_dot.i.Omega_part6_3mm_004(part6_3mm_004.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part6_3mm_004(part6_3mm_004.lam, s, T) \
        + dw_dot.i.Omega_part7_3mm_005(part7_3mm_005.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part7_3mm_005(part7_3mm_005.lam, s, T) \
        + dw_dot.i.Omega_part8_3mm_006(part8_3mm_006.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part8_3mm_006(part8_3mm_006.lam, s, T) \
        + dw_dot.i.Omega_part9_3mm_007(part9_3mm_007.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part9_3mm_007(part9_3mm_007.lam, s, T) \
        + dw_dot.i.Omega_battery(battery.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_battery(battery.lam, s, T) \
        + dw_dot.i.Omega_bottom_cover(bottom_cover.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_bottom_cover(bottom_cover.lam, s, T) \
        + dw_dot.i.Omega_bttery_holder_001(bttery_holder_001.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_bttery_holder_001(bttery_holder_001.lam, s, T) \
        + dw_dot.i.Omega_display(display.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_display(display.lam, s, T) \
        + dw_dot.i.Omega_display_power_5v(display_power_5v.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_display_power_5v(display_power_5v.lam, s, T) \
        + dw_dot.i.Omega_display_power_gnd(display_power_gnd.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_display_power_gnd(display_power_gnd.lam, s, T) \
        + dw_dot.i.Omega_dsi_cable(dsi_cable.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_dsi_cable(dsi_cable.lam, s, T) \
        + dw_dot.i.Omega_jst_lipo_connector(jst_lipo_connector.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_jst_lipo_connector(jst_lipo_connector.lam, s, T) \
        + dw_dot.i.Omega_lipo_chargerbooster(lipo_chargerbooster.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_lipo_chargerbooster(lipo_chargerbooster.lam, s, T) \
        + dw_dot.i.Omega_main_case(main_case.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_main_case(main_case.lam, s, T) \
        + dw_dot.i.Omega_plane(plane.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_plane(plane.lam, s, T) \
        + dw_dot.i.Omega_part21_3mm(part21_3mm.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part21_3mm(part21_3mm.lam, s, T) \
        + dw_dot.i.Omega_part22_3mm_001(part22_3mm_001.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part22_3mm_001(part22_3mm_001.lam, s, T) \
        + dw_dot.i.Omega_part23_3mm_002(part23_3mm_002.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part23_3mm_002(part23_3mm_002.lam, s, T) \
        + dw_dot.i.Omega_part24_3mm_003(part24_3mm_003.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_part24_3mm_003(part24_3mm_003.lam, s, T) \
        + dw_dot.i.Omega_type_c_port_entrance(type_c_port_entrance.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_type_c_port_entrance(type_c_port_entrance.lam, s, T) \
        + dw_dot.i.Omega_typea_c_power_only_cable(typea_c_power_only_cable.rho_cp, s, dT/dt ) + dw_laplace.i.Omega_typea_c_power_only_cable(typea_c_power_only_cable.lam, s, T)
        = dw_bc_newton.i.Gamma_Exterior(env.h, env.T_inf, s, T) \
        + dw_volume_lvf.i.Omega_baseboard(src_baseboard.val, s) \
        + dw_volume_lvf.i.Omega_display(src_display.val, s) \
        + dw_volume_lvf.i.Omega_display_power_5v(src_display_power_5v.val, s) \
        + dw_volume_lvf.i.Omega_display_power_gnd(src_display_power_gnd.val, s) \
        + dw_volume_lvf.i.Omega_dsi_cable(src_dsi_cable.val, s) \
        + dw_volume_lvf.i.Omega_jst_lipo_connector(src_jst_lipo_connector.val, s) \
        + dw_volume_lvf.i.Omega_lipo_chargerbooster(src_lipo_chargerbooster.val, s) \
        + dw_volume_lvf.i.Omega_typea_c_power_only_cable(src_typea_c_power_only_cable.val, s)
    """
}

ics = {
    'ic_back_cover': ('Omega_back_cover', {'T.0': 25.0}),
    'ic_back_cover_camera_bump': ('Omega_back_cover_camera_bump', {'T.0': 25.0}),
    'ic_baseboard': ('Omega_baseboard', {'T.0': 25.0}),
    'ic_cm4': ('Omega_cm4', {'T.0': 25.0}),
    'ic_battery_holder': ('Omega_battery_holder', {'T.0': 25.0}),
    'ic_part6_3mm_004': ('Omega_part6_3mm_004', {'T.0': 25.0}),
    'ic_part7_3mm_005': ('Omega_part7_3mm_005', {'T.0': 25.0}),
    'ic_part8_3mm_006': ('Omega_part8_3mm_006', {'T.0': 25.0}),
    'ic_part9_3mm_007': ('Omega_part9_3mm_007', {'T.0': 25.0}),
    'ic_battery': ('Omega_battery', {'T.0': 25.0}),
    'ic_bottom_cover': ('Omega_bottom_cover', {'T.0': 25.0}),
    'ic_bttery_holder_001': ('Omega_bttery_holder_001', {'T.0': 25.0}),
    'ic_display': ('Omega_display', {'T.0': 25.0}),
    'ic_display_power_5v': ('Omega_display_power_5v', {'T.0': 25.0}),
    'ic_display_power_gnd': ('Omega_display_power_gnd', {'T.0': 25.0}),
    'ic_dsi_cable': ('Omega_dsi_cable', {'T.0': 25.0}),
    'ic_jst_lipo_connector': ('Omega_jst_lipo_connector', {'T.0': 25.0}),
    'ic_lipo_chargerbooster': ('Omega_lipo_chargerbooster', {'T.0': 25.0}),
    'ic_main_case': ('Omega_main_case', {'T.0': 25.0}),
    'ic_plane': ('Omega_plane', {'T.0': 25.0}),
    'ic_part21_3mm': ('Omega_part21_3mm', {'T.0': 25.0}),
    'ic_part22_3mm_001': ('Omega_part22_3mm_001', {'T.0': 25.0}),
    'ic_part23_3mm_002': ('Omega_part23_3mm_002', {'T.0': 25.0}),
    'ic_part24_3mm_003': ('Omega_part24_3mm_003', {'T.0': 25.0}),
    'ic_type_c_port_entrance': ('Omega_type_c_port_entrance', {'T.0': 25.0}),
    'ic_typea_c_power_only_cable': ('Omega_typea_c_power_only_cable', {'T.0': 25.0}),
}

ebcs = {
}

solvers = {
    'ls': ('ls.auto_direct', {
        'use_presolve': True,
        'use_mtx_digest': False,
    }),
    'newton': ('nls.newton', {
        'i_max': 1,
        'eps_a': 1e-8,
        'is_linear': True,
    }),
    'ts': ('ts.simple', {
        't0': 0.0,
        't1': 120.0,
        'dt': None,
        'n_step': 241,
        'verbose': True,
        'is_linear': True,
    }),
}

options = {
    'output_dir': r"O:/unlim8ted-phone/3d/heat_sim_cases/heat_sim_full_sfepy",
    'output_format': 'vtk',
    'save_results': True,
}
