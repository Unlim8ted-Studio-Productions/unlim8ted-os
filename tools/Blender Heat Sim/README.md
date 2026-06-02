# CAD Heat Sim Blender Add-on

Install the `Blender Heat Sim` folder as a Blender add-on zip or copy it into your Blender add-ons directory.

What it does:
- Adds a `Heat Sim` tab to the 3D View sidebar.
- Lets you assign thermal material presets or custom thermal properties per object.
- Simulates transient heating with internal power, fixed-temperature boundaries, object-to-object contact conduction, convection, and radiation.
- Supports component presets with idle-to-max power scaling driven by a scene-wide load control.
- Colors the model by temperature and exports summary CSV data.
- Includes improved preview controls for current-frame contrast, hottest/coolest part readout, and one-click viewport setup.
- Uses a two-node core/surface thermal model per object for better internal-vs-external temperature behavior.
- Uses adaptive predictor-corrector time integration and face-aware contact estimation for higher numerical and geometric fidelity.
- Supports a free `SfePy` server backend that voxelizes the Blender scene and solves a transient thermal FEM case in an external Python environment.

Included presets:
- Metals and structural materials such as aluminum, copper, stainless steel, titanium, glass, silicon, graphite pad, and PCB FR4.
- Printed and enclosure materials such as ABS, PLA, polycarbonate, TPU, and nylon.
- Electronics-oriented presets such as `LiPo Battery`, `CM4 PCB`, `CM4 SoC Package`, `CM4 Module`, and `Waveshare 6.25 DSI Display`.
- Assembly and interface materials such as `Steel Screw`, `Brass`, `Ceramic`, `Thermal Pad`, `Thermal Paste`, `FPC Ribbon Cable`, and `Adhesive Tape`.
- Device presets for `Raspberry Pi CM4 Lite 8GB`, `Waveshare CM4-NANO-C`, `Waveshare 6.25-inch DSI LCD`, `32GB microSD Card`, `Seeed LiPo Rider Plus`, `3.7V 3000mAh LiPo`, `15cm 15-pin DSI Cable`, and `USB Type A to Type C Cable`.

Recommended workflow:
1. Import or model your CAD parts as separate mesh objects with real-world scale in meters.
2. Select an object, choose a component preset when appropriate, and sync it to copy material and power defaults.
3. Set the scene `System Load` slider to represent idle through maximum sustained use.
4. Use load profiles for active components such as compute modules, displays, chargers, and batteries, or manual heat generation for custom parts.
5. Select objects and apply material or component presets to the rest of the assembly as needed.
6. Mark heatsinks, cold plates, or environment-controlled parts as fixed-temperature boundaries when needed.
7. Run the simulation and inspect the final frame or scrub the preview frame slider.

SfePy workflow:
1. In add-on preferences, set `Server Python` to a normal Python installation outside Blender.
2. Use `Install Server Modules` to install `numpy`, `scipy`, `sfepy`, `trimesh`, and `numpy-stl` into that external Python environment.
3. Use `Start Solver Server` once, or keep `Auto Start Server` enabled.
4. In the Heat Sim panel, switch `Backend` to `SfePy Server`.
5. Set `SfePy Cell Size` small enough for the geometry detail you care about.
6. Use `Export SfePy Case` to generate the voxel mesh and solver files, or `Run SfePy Server Solve` to solve through the server.
7. The add-on writes the generated case, compressed voxel mesh data, Python runner, and server log into the configured case folder.

Mesh viewer:
- Use `tools/Blender Heat Sim/mesh_viewer.py` to inspect generated `.mesh` files outside Blender.
- Example:
```powershell
python "O:\unlim8ted-phone\tools\Blender Heat Sim\mesh_viewer.py" "O:\unlim8ted-phone\3d\heat_sim_cases\heat_sim_full_sfepy\heat_sim_full.mesh"
```
- If no path is provided, the viewer opens a file picker.

Preview tips:
- Use `Set Preview View` to switch Blender to a heat-map friendly material preview automatically.
- Use `Color Scope = Whole Run` to compare temperatures across the entire simulation.
- Use `Color Scope = Current Frame` for stronger contrast at the selected preview time.
- Use `Color Scope = Manual` when you want a fixed engineering temperature scale.
- Use `Preview Temp = Surface`, `Core`, or `Max` depending on whether you want touch temperature, internal hotspot temperature, or the worst-case of both.
- Read the `Hot` and `Cool` labels in the preview panel to see the extreme parts at the current frame quickly.

Accuracy notes:
- Keep geometry to real-world scale in meters.
- Lower `Max Temp Step` for higher temporal accuracy at the cost of longer solve time.
- Lower `SfePy Cell Size` for higher spatial fidelity in the SfePy backend.
- Use separate objects for heat sources, boards, pads, shields, batteries, and displays instead of one merged assembly.
- Use manual thickness overrides on thin stacked parts when the automatic estimate is too coarse.

Notes:
- This is a materially aware lumped thermal network solver inside Blender. It is useful for design iteration, comparison, and finding hot spots.
- It is not a substitute for full finite-element thermal analysis when you need certification-grade accuracy or detailed internal gradients inside a single part.
