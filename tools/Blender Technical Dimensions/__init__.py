bl_info = {
    "name": "Technical Dimensions",
    "author": "Unlim8ted Studios",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Dimensions",
    "description": "Add drafting-style dimension lines and text for mesh geometry",
    "category": "Object",
}

import bmesh
import bpy
from bpy.props import BoolProperty, EnumProperty, FloatProperty, IntProperty, PointerProperty
from bpy.types import Operator, Panel, PropertyGroup
from mathutils import Matrix, Vector


PLANE_ITEMS = [
    ("XY", "XY", "Draw dimensions in the XY plane"),
    ("XZ", "XZ", "Draw dimensions in the XZ plane"),
    ("YZ", "YZ", "Draw dimensions in the YZ plane"),
]

AXIS_ITEMS = [
    ("AUTO", "Auto", "Use the dominant axis in the selected plane"),
    ("X", "X", "Measure horizontal X distance"),
    ("Y", "Y", "Measure horizontal Y distance"),
    ("Z", "Z", "Measure vertical Z distance"),
]


def plane_basis(plane):
    if plane == "XY":
        return Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    if plane == "XZ":
        return Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
    return Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))


def plane_axes(plane):
    if plane == "XY":
        return ("X", "Y")
    if plane == "XZ":
        return ("X", "Z")
    return ("Y", "Z")


def format_length(scene, value, decimals, use_scene_units):
    if use_scene_units:
        try:
            return bpy.utils.units.to_string(
                scene.unit_settings.system or "NONE",
                "LENGTH",
                value,
                precision=decimals,
            )
        except Exception:
            pass
    return f"{value:.{decimals}f} m"


def ensure_dimensions_collection(scene):
    collection = bpy.data.collections.get("Dimensions")
    if collection is None:
        collection = bpy.data.collections.new("Dimensions")
        scene.collection.children.link(collection)
    return collection


def link_to_collection(obj, collection):
    for existing in obj.users_collection:
        if existing != collection:
            existing.objects.unlink(obj)
    if collection not in obj.users_collection:
        collection.objects.link(obj)


def axis_for_points(plane, axis, point_a, point_b):
    valid_axes = plane_axes(plane)
    if axis in valid_axes:
        return axis
    if axis != "AUTO":
        raise ValueError(f"Axis {axis} is not available in plane {plane}")
    deltas = {
        "X": abs(point_b.x - point_a.x),
        "Y": abs(point_b.y - point_a.y),
        "Z": abs(point_b.z - point_a.z),
    }
    return max(valid_axes, key=lambda item: deltas[item])


def world_to_plane(point, u_axis, v_axis, n_axis):
    return Vector((point.dot(u_axis), point.dot(v_axis), point.dot(n_axis)))


def plane_matrix(u_axis, v_axis, n_axis, plane_height):
    matrix = Matrix.Identity(4)
    matrix.col[0].xyz = u_axis
    matrix.col[1].xyz = v_axis
    matrix.col[2].xyz = n_axis
    matrix.translation = n_axis * plane_height
    return matrix


def build_horizontal_dimension(x0, y0, x1, y1, line_y, settings):
    sign = 1.0 if line_y >= max(y0, y1) else -1.0
    extension_tip = line_y + sign * settings.extension
    tick = settings.tick_size
    tick_dx = tick * 0.5
    tick_dy = tick * 0.5 * sign
    segments = [
        ((x0, y0, 0.0), (x0, extension_tip, 0.0)),
        ((x1, y1, 0.0), (x1, extension_tip, 0.0)),
        ((x0, line_y, 0.0), (x1, line_y, 0.0)),
        ((x0 - tick_dx, line_y - tick_dy, 0.0), (x0 + tick_dx, line_y + tick_dy, 0.0)),
        ((x1 - tick_dx, line_y - tick_dy, 0.0), (x1 + tick_dx, line_y + tick_dy, 0.0)),
    ]
    text_pos = Vector(((x0 + x1) * 0.5, line_y + sign * settings.text_gap, 0.0))
    return segments, text_pos


def build_vertical_dimension(x0, y0, x1, y1, line_x, settings):
    sign = 1.0 if line_x >= max(x0, x1) else -1.0
    extension_tip = line_x + sign * settings.extension
    tick = settings.tick_size
    tick_dx = tick * 0.5 * sign
    tick_dy = tick * 0.5
    segments = [
        ((x0, y0, 0.0), (extension_tip, y0, 0.0)),
        ((x1, y1, 0.0), (extension_tip, y1, 0.0)),
        ((line_x, y0, 0.0), (line_x, y1, 0.0)),
        ((line_x - tick_dx, y0 - tick_dy, 0.0), (line_x + tick_dx, y0 + tick_dy, 0.0)),
        ((line_x - tick_dx, y1 - tick_dy, 0.0), (line_x + tick_dx, y1 + tick_dy, 0.0)),
    ]
    text_pos = Vector((line_x + sign * settings.text_gap, (y0 + y1) * 0.5, 0.0))
    return segments, text_pos


def build_dimension_segments(x0, y0, x1, y1, settings):
    sign = 1.0 if settings.offset >= 0.0 else -1.0
    line_y = max(y0, y1) + settings.offset
    extension_tip = line_y + sign * settings.extension
    tick = settings.tick_size
    tick_dx = tick * 0.5
    tick_dy = tick * 0.5 * sign
    segments = [
        ((x0 - tick_dx, extension_tip - tick_dy, 0.0), (x0 + tick_dx, extension_tip + tick_dy, 0.0)),
        ((x1 - tick_dx, extension_tip - tick_dy, 0.0), (x1 + tick_dx, extension_tip + tick_dy, 0.0)),
    ]
    text_pos = Vector(((x0 + x1) * 0.5, line_y + sign * settings.text_gap, 0.0))
    return segments, text_pos


def create_curve_object(name, parent, segments, settings):
    curve_data = bpy.data.curves.new(name=name, type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = settings.line_depth
    curve_data.bevel_resolution = 0
    for start, end in segments:
        spline = curve_data.splines.new("POLY")
        spline.points.add(1)
        spline.points[0].co = (*start, 1.0)
        spline.points[1].co = (*end, 1.0)
    curve_obj = bpy.data.objects.new(name, curve_data)
    curve_obj.parent = parent
    curve_obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return curve_obj


def create_text_object(name, parent, text, location, settings):
    text_data = bpy.data.curves.new(name=name, type="FONT")
    text_data.body = text
    text_data.size = settings.text_size
    text_data.align_x = "CENTER"
    text_data.align_y = "CENTER"
    text_obj = bpy.data.objects.new(name, text_data)
    text_obj.parent = parent
    text_obj.matrix_parent_inverse = parent.matrix_world.inverted()
    text_obj.location = location
    return text_obj


def make_dimension_group(context, title, plane, segments, text, text_pos, plane_height):
    scene = context.scene
    settings = scene.tech_dims
    collection = ensure_dimensions_collection(scene)
    u_axis, v_axis, n_axis = plane_basis(plane)
    root = bpy.data.objects.new(title, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = max(settings.tick_size * 0.75, 0.001)
    root.matrix_world = plane_matrix(u_axis, v_axis, n_axis, plane_height)
    line_obj = create_curve_object(f"{title}_Lines", root, segments, settings)
    text_obj = create_text_object(f"{title}_Text", root, text, text_pos, settings)
    link_to_collection(root, collection)
    link_to_collection(line_obj, collection)
    link_to_collection(text_obj, collection)
    return root


def create_dimension_from_points(context, point_a, point_b, plane, axis, label_prefix="DIM"):
    scene = context.scene
    settings = scene.tech_dims
    used_axis = axis_for_points(plane, axis, point_a, point_b)
    u_axis, v_axis, n_axis = plane_basis(plane)
    pa = world_to_plane(point_a, u_axis, v_axis, n_axis)
    pb = world_to_plane(point_b, u_axis, v_axis, n_axis)
    plane_height = (pa.z + pb.z) * 0.5

    if used_axis == plane_axes(plane)[0]:
        line_y = max(pa.y, pb.y) + settings.offset
        segments, text_pos = build_horizontal_dimension(pa.x, pa.y, pb.x, pb.y, line_y, settings)
        value = abs(pb.x - pa.x)
    else:
        sign = 1.0 if settings.offset >= 0.0 else -1.0
        source_x = max(pa.x, pb.x) if sign > 0 else min(pa.x, pb.x)
        line_x = source_x + settings.offset
        segments, text_pos = build_vertical_dimension(pa.x, pa.y, pb.x, pb.y, line_x, settings)
        value = abs(pb.y - pa.y)

    text = format_length(scene, value, settings.decimals, settings.use_scene_units)
    title = f"{label_prefix}_{used_axis}"
    return make_dimension_group(context, title, plane, segments, text, text_pos, plane_height)


def selected_vertex_positions(context):
    obj = context.edit_object
    if obj is None or obj.type != "MESH":
        raise RuntimeError("Enter mesh edit mode and select exactly two vertices")
    bm = bmesh.from_edit_mesh(obj.data)
    selected = [vert for vert in bm.verts if vert.select]
    if len(selected) != 2:
        raise RuntimeError("Select exactly two vertices")
    world = obj.matrix_world
    return world @ selected[0].co, world @ selected[1].co


def object_bounds_points(obj):
    return [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]


def min_max_on_axis(points, axis_index):
    values = [point[axis_index] for point in points]
    return min(values), max(values)


def create_bounds_dimensions(context, obj):
    settings = context.scene.tech_dims
    plane = settings.plane
    valid_axes = plane_axes(plane)
    points = object_bounds_points(obj)
    u_axis, v_axis, n_axis = plane_basis(plane)
    plane_points = [world_to_plane(point, u_axis, v_axis, n_axis) for point in points]
    plane_height = sum(point.z for point in plane_points) / max(len(plane_points), 1)
    xs = [point.x for point in plane_points]
    ys = [point.y for point in plane_points]
    x_min, x_max = min(xs), max(xs)
    y_min, y_max = min(ys), max(ys)

    created = []
    if valid_axes[0] in {"X", "Y"}:
        line_y = y_max + settings.offset
        segments, text_pos = build_horizontal_dimension(x_min, y_max, x_max, y_max, line_y, settings)
        text = format_length(context.scene, abs(x_max - x_min), settings.decimals, settings.use_scene_units)
        created.append(make_dimension_group(context, f"DIM_{obj.name}_{valid_axes[0]}", plane, segments, text, text_pos, plane_height))

    line_x = x_min - abs(settings.offset)
    segments, text_pos = build_vertical_dimension(x_min, y_min, x_min, y_max, line_x, settings)
    text = format_length(context.scene, abs(y_max - y_min), settings.decimals, settings.use_scene_units)
    created.append(make_dimension_group(context, f"DIM_{obj.name}_{valid_axes[1]}", plane, segments, text, text_pos, plane_height))
    return created


class TechnicalDimensionSettings(PropertyGroup):
    plane: EnumProperty(name="Plane", items=PLANE_ITEMS, default="XZ")
    axis: EnumProperty(name="Axis", items=AXIS_ITEMS, default="AUTO")
    offset: FloatProperty(
        name="Offset",
        description="Distance from the measured geometry to the dimension line",
        default=0.005,
        subtype="DISTANCE",
    )
    extension: FloatProperty(
        name="Extension",
        description="How far extension lines pass the dimension line",
        default=0.0015,
        subtype="DISTANCE",
        min=0.0,
    )
    tick_size: FloatProperty(
        name="Tick Size",
        default=0.0015,
        subtype="DISTANCE",
        min=0.0001,
    )
    text_gap: FloatProperty(
        name="Text Gap",
        default=0.0015,
        subtype="DISTANCE",
        min=0.0,
    )
    text_size: FloatProperty(
        name="Text Size",
        default=0.003,
        subtype="DISTANCE",
        min=0.0005,
    )
    line_depth: FloatProperty(
        name="Line Depth",
        default=0.00015,
        subtype="DISTANCE",
        min=0.00001,
    )
    decimals: IntProperty(name="Decimals", default=2, min=0, max=5)
    use_scene_units: BoolProperty(name="Use Scene Units", default=True)


class TECHDIMS_OT_add_vertex_dimension(Operator):
    bl_idname = "techdims.add_vertex_dimension"
    bl_label = "Dimension Selected Vertices"
    bl_description = "Create a drafting-style dimension from exactly two selected mesh vertices"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        try:
            point_a, point_b = selected_vertex_positions(context)
            create_dimension_from_points(
                context,
                point_a,
                point_b,
                context.scene.tech_dims.plane,
                context.scene.tech_dims.axis,
                label_prefix="DIM_VERT",
            )
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}
        return {"FINISHED"}


class TECHDIMS_OT_add_bounds_dimensions(Operator):
    bl_idname = "techdims.add_bounds_dimensions"
    bl_label = "Dimension Active Mesh Bounds"
    bl_description = "Create quick overall dimensions around the active mesh object"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        if obj is None or obj.type != "MESH":
            self.report({"ERROR"}, "Active object must be a mesh")
            return {"CANCELLED"}
        try:
            create_bounds_dimensions(context, obj)
        except Exception as exc:
            self.report({"ERROR"}, str(exc))
            return {"CANCELLED"}
        return {"FINISHED"}


class TECHDIMS_PT_main(Panel):
    bl_label = "Dimensions"
    bl_idname = "TECHDIMS_PT_main"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Dimensions"

    def draw(self, context):
        layout = self.layout
        settings = context.scene.tech_dims

        box = layout.box()
        box.label(text="Dimension Style")
        box.prop(settings, "plane")
        box.prop(settings, "axis")
        box.prop(settings, "offset")
        box.prop(settings, "extension")
        box.prop(settings, "tick_size")
        box.prop(settings, "text_gap")
        box.prop(settings, "text_size")
        box.prop(settings, "line_depth")
        box.prop(settings, "decimals")
        box.prop(settings, "use_scene_units")

        actions = layout.box()
        actions.label(text="Actions")
        actions.operator("techdims.add_vertex_dimension", icon="DRIVER_DISTANCE")
        actions.operator("techdims.add_bounds_dimensions", icon="SHADING_BBOX")
        actions.label(text="Edit mode: select exactly two verts")
        actions.label(text="Object mode: dimension active mesh bounds")


classes = (
    TechnicalDimensionSettings,
    TECHDIMS_OT_add_vertex_dimension,
    TECHDIMS_OT_add_bounds_dimensions,
    TECHDIMS_PT_main,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.tech_dims = PointerProperty(type=TechnicalDimensionSettings)


def unregister():
    del bpy.types.Scene.tech_dims
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
