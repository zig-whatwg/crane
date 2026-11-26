//! Implementation for CanvasRenderingContext2D interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CanvasRenderingContext2D = interfaces.CanvasRenderingContext2D;
const engine = @import("engine");
const dom = @import("dom");
const same_object = @import("dom").same_object;

pub const State = CanvasRenderingContext2D.State;

pub const ImplError = error{
    NotImplemented,
};

/// A CanvasRenderingContext2D's state: its output bitmap and drawing state
/// (dom.canvas_2d.Context2D, which the mixins it includes read and write)
/// and the canvas it was made for.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The output bitmap (HTML 4.12.5.1.2, which its canvas shares) and the
    /// drawing state.
    context: dom.canvas_2d.Context2D,
    /// The canvas this context was made for (the 2D context creation
    /// algorithm step 3), kept for as long as the context's wrapper lives:
    /// `context.canvas` keeps answering it (Blink's
    /// CanvasRenderingContext::Trace visits host_).
    canvas: ?same_object.Link = null,
    canvas_edge: same_object.Traced = .{ .slot = .{ .name = "canvas" } },
};

const Registry = runtime.InstanceRegistry(.canvas_rendering_context_2d, InternalState);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

fn getOrCreateInternal(instance: *runtime.Instance) !*InternalState {
    if (Registry.get(instance)) |internal| {
        return internal;
    }
    // Create new internal state
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{
        .allocator = allocator,
        .context = dom.canvas_2d.Context2D.init(allocator),
    };
    try Registry.set(instance, internal);
    return internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state if it exists
    if (Registry.get(instance)) |internal| {
        // The edge to the canvas goes with this context; the canvas itself
        // is not touched (the collector may have freed it first).
        internal.canvas_edge.release(instance);
        internal.context.deinit();
        internal.allocator.destroy(internal);
    }
    Registry.remove(instance);
}

/// The hooks this type owns: its state, which the mixins it includes reach
/// (dom.canvas_2d), and the creation and resizing steps its canvas runs
/// (dom.image_sources).
pub fn installHooks() void {
    dom.canvas_2d.installElementContext(contextState);
    dom.image_sources.installContext2D(attachContext, setBitmapDimensions);
}

fn contextState(instance: *runtime.Instance) ?*dom.canvas_2d.Context2D {
    const internal = getInternal(instance) orelse return null;
    return &internal.context;
}

/// The 2D context creation algorithm, steps 3 and 5, for `canvas`.
fn attachContext(instance: *runtime.Instance, canvas: *runtime.Instance, width: u32, height: u32) anyerror!void {
    const internal = try getOrCreateInternal(instance);
    // 3. "Initialize context's canvas attribute to point to target."
    internal.canvas = same_object.Link.to(canvas);
    internal.canvas_edge.hold(instance, canvas);
    // 5. "Set bitmap dimensions to the numeric values of target's width and
    //    height content attributes."
    try setBitmapDimensions(instance, width, height);
}

/// "Set bitmap dimensions", steps 1 and 2 (steps 4 and 5 set the canvas's
/// attributes only when they differ from `width` and `height`, which they
/// never do here: both come from them).
fn setBitmapDimensions(instance: *runtime.Instance, width: u32, height: u32) anyerror!void {
    const internal = try getOrCreateInternal(instance);
    // 1. Reset the rendering context to its default state.
    internal.context.reset();
    // 2. Resize the output bitmap to the new width and height (transparent
    //    black).
    if (@as(u64, width) * height > dom.canvas_2d.max_bitmap_pixels) return internal.context.bitmap.resize(0, 0);
    try internal.context.bitmap.resize(width, height);
}

/// Getter for canvas: "the value it was initialized to when the object was
/// created".
pub fn get_canvas(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const canvas = internal.canvas orelse return error.InvalidStateError;
    if (!canvas.isLive()) return error.InvalidStateError;
    return canvas.instance;
}
