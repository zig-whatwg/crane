//! Implementation for OffscreenCanvasRenderingContext2D interface
//!
//! HTML 4.12.5.3.1: a 2D rendering context for an OffscreenCanvas's bitmap,
//! made by its getContext("2d") (the offscreen 2D context creation
//! algorithm, whose facts arrive as `construction_args`). The members it
//! includes are the mixins' (dom.canvas_2d holds the state they share with
//! the canvas element's context).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const OffscreenCanvasRenderingContext2D = interfaces.OffscreenCanvasRenderingContext2D;
const dom = @import("dom");
const same_object = dom.same_object;

pub const State = OffscreenCanvasRenderingContext2D.State;

pub const ImplError = error{
    NotImplemented,
};

/// The offscreen 2D context creation algorithm's facts (HTML 4.12.5.3.1):
/// the associated OffscreenCanvas object (step 4) and its bitmap's width
/// and height (step 6).
pub const construction_args = .{ "offscreen_canvas", "width", "height" };

/// An OffscreenCanvasRenderingContext2D's state: its output bitmap and
/// drawing state (dom.canvas_2d.Context2D, which the mixins it includes
/// read and write) and its associated OffscreenCanvas object.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The output bitmap - the OffscreenCanvas's bitmap: "set target's
    /// bitmap to the same bitmap (so that they are shared)" - and the
    /// drawing state.
    context: dom.canvas_2d.Context2D,
    /// The associated OffscreenCanvas object, kept for as long as this
    /// context's wrapper lives (`canvas` keeps answering it), as the canvas
    /// element's 2D context keeps its canvas.
    canvas: ?same_object.Link = null,
    canvas_edge: same_object.Traced = .{ .slot = .{ .name = "canvas" } },
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The offscreen 2D context creation algorithm, steps 3-7, for the context
/// `instance` being made (OffscreenCanvas's getContext gives the facts):
/// its associated OffscreenCanvas (4) and an output bitmap of the canvas's
/// dimensions, transparent black (6-7: the alpha flag is true - the
/// settings' alpha is not modelled, stated).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .context = dom.canvas_2d.Context2D.init(allocator) };
    errdefer internal.context.deinit();
    if (comptime @hasField(@TypeOf(args), "width") and @hasField(@TypeOf(args), "height")) {
        try setBitmapDimensions(&internal.context, args.width, args.height);
    }
    instance.getState(State).own._internal = internal;
    if (comptime @hasField(@TypeOf(args), "offscreen_canvas")) {
        internal.canvas = same_object.Link.to(args.offscreen_canvas);
        internal.canvas_edge.hold(instance, args.offscreen_canvas);
    }
}

/// Resize `context`'s output bitmap to `width` x `height` of transparent
/// black, after resetting its drawing state: the OffscreenCanvas's width
/// and height setters' steps for a 2d context ("reset the rendering context
/// to its default state and resize the OffscreenCanvas object's bitmap").
/// A bitmap past dom.canvas_2d.max_bitmap_pixels gets no pixels, as the
/// canvas element's.
fn setBitmapDimensions(context: *dom.canvas_2d.Context2D, width: u64, height: u64) !void {
    context.reset();
    const fits = width <= std.math.maxInt(u32) and height <= std.math.maxInt(u32) and
        (std.math.mul(u64, width, height) catch std.math.maxInt(u64)) <= dom.canvas_2d.max_bitmap_pixels;
    if (!fits) return context.bitmap.resize(0, 0);
    try context.bitmap.resize(@intCast(width), @intCast(height));
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    // The edge to the canvas goes with this context; the canvas itself is
    // not touched (the collector may have freed it first).
    internal.canvas_edge.release(instance);
    internal.context.deinit();
    internal.allocator.destroy(internal);
}

/// The hooks this type owns: its state, which the mixins it includes reach
/// (dom.canvas_2d), and the resizing step its OffscreenCanvas runs.
pub fn installHooks() void {
    dom.canvas_2d.installOffscreenContext(.{ .state_of = contextState, .set_bitmap_dimensions = resize });
}

fn contextState(instance: *runtime.Instance) ?*dom.canvas_2d.Context2D {
    const internal = getInternal(instance) orelse return null;
    return &internal.context;
}

fn resize(instance: *runtime.Instance, width: u64, height: u64) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try setBitmapDimensions(&internal.context, width, height);
}

/// Getter for canvas: "the associated OffscreenCanvas object".
pub fn get_canvas(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const canvas = internal.canvas orelse return error.InvalidStateError;
    if (!canvas.isLive()) return error.InvalidStateError;
    return canvas.instance;
}

/// Operation: rect
pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: ellipse
pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radiusX;
    _ = radiusY;
    _ = rotation;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
    return error.NotImplemented;
}

/// Operation: arc
pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radius;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
    return error.NotImplemented;
}

/// Operation: closePath
pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: roundRect
pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(typedefs.UnrestrictedDoubleOrDOMPointInitOrSequenceOfUnrestrictedDoubleOrDOMPointInit)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    _ = radii;
    return error.NotImplemented;
}

/// Operation: lineTo
pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: arcTo
pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
    _ = instance;
    _ = x1;
    _ = y1;
    _ = x2;
    _ = y2;
    _ = radius;
    return error.NotImplemented;
}

/// Operation: moveTo
pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: quadraticCurveTo
pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = cpx;
    _ = cpy;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: bezierCurveTo
pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = cp1x;
    _ = cp1y;
    _ = cp2x;
    _ = cp2y;
    _ = x;
    _ = y;
    return error.NotImplemented;
}
