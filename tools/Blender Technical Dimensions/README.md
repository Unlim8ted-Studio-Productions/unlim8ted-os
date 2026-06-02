# Technical Dimensions Blender Add-on

Install the `Blender Technical Dimensions` folder as a Blender add-on zip or copy it into your Blender add-ons directory.

What it does:
- Adds a `Dimensions` tab to the 3D View sidebar.
- Creates drafting-style dimension lines with slash ticks and text labels.
- Supports two workflows:
  - `Dimension Selected Vertices`: in mesh edit mode, select exactly two vertices.
  - `Dimension Active Mesh Bounds`: in object mode, create overall size dimensions for the active mesh.
- Works in `XY`, `XZ`, or `YZ` planes.

Notes:
- This is a lightweight technical-dimension helper, not a full drawing-document generator.
- Dimensions are created as normal Blender objects inside a `Dimensions` collection.
- The text uses scene units when enabled, otherwise it shows values in meters.

Suggested use:
1. Set the dimension plane that matches your view or section.
2. Adjust `Offset`, `Tick Size`, and `Text Size` to match your model scale.
3. In edit mode, select two vertices and run `Dimension Selected Vertices`.
4. In object mode, run `Dimension Active Mesh Bounds` for quick overall size callouts.
