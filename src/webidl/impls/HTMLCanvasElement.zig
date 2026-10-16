//! Implementation for HTMLCanvasElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLCanvasElement = interfaces.HTMLCanvasElement;
const engine = @import("engine");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const reflection = @import("dom").reflection;

pub const State = HTMLCanvasElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTML 4.12.5: the canvas context mode (placeholder, bitmaprenderer,
/// webgl, webgl2 and webgpu are not modelled: getContext answers null for
/// them).
const ContextMode = enum { none, @"2d" };

/// A canvas's context mode and its rendering context. Its bitmap is the
/// context's output bitmap ("they are shared", the 2D context creation
/// algorithm step 4); with no context it is transparent black of the
/// width and height attributes' size, which nothing stores.
///
/// A block of the Browser's runtime arena, made with the element: it owns
/// nothing beyond itself (the context is a child its wrapper keeps), so a
/// canvas removed from its tree while nothing wrapped it - an orphan nothing
/// deinits - leaves its block to the arena's end. A block of its own leaked
/// once per orphaned canvas (lane orphanleak, crane/cl-orphan-canvas.html;
/// dom.orphan_states).
pub const InternalState = struct {
    mode: ContextMode = .none,
    /// The 2D context, made once and handed out by every getContext("2d").
    context: ?*runtime.Instance = null,
    /// The canvas keeps its context for as long as its wrapper lives (a
    /// traced edge: same_object.KeptChild), as Blink's
    /// HTMLCanvasElement::Trace visits context_.
    context_kept: same_object.KeptChild = .{},
};

fn internalOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The context's edge from its canvas.
const context_slot: engine.TracedSlot = .{ .name = "getContext" };

/// The width and height content attributes' numeric values: the rules for
/// parsing non-negative integers, with the defaults 300 and 150 for a
/// missing or erroneous value - as their reflection reads them (a value
/// above 2147483647 is the default too).
fn bitmapSize(instance: *runtime.Instance) struct { u32, u32 } {
    const width = reflection.get(u32, instance, .{ .name = "width", .default = 300 }) catch 300;
    const height = reflection.get(u32, instance, .{ .name = "height", .default = 150 }) catch 150;
    return .{ width, height };
}

/// HTMLCanvasElement's own construction steps: the generated chain runs
/// HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    _ = allocator;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

/// HTMLCanvasElement's own teardown: the generated chain runs HTMLElement's
/// after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (instance.stateAs(State)) |state| if (state.own._internal) |internal| {
        // The context, if it is still the one this canvas made, loses its
        // state: script that still holds it gets InvalidStateError.
        if (internal.context) |context| internal.context_kept.release(context, interfaces.CanvasRenderingContext2D.deinit);
        state.own._internal = null;
        runtime.arenaOf(instance).destroy(InternalState, internal);
    };
}

/// The hooks this type owns: its width and height attributes' change steps
/// (they set the bitmap dimensions), and its bitmap as a 2D context's image
/// source.
pub fn installHooks() void {
    dom.attribute_change_steps.install("canvas", &attributeChangeSteps);
    dom.image_sources.installCanvasElement(canvasUsability);
}

/// "Whenever the width and height content attributes are set, removed,
/// changed, or redundantly set to the value they already have": in the 2d
/// context mode, set bitmap dimensions to their numeric values; in none, do
/// nothing.
fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = .{ old_value, value };
    if (namespace != null) return;
    if (!std.mem.eql(u8, local_name, "width") and !std.mem.eql(u8, local_name, "height")) return;
    const internal = internalOf(element) orelse return;
    if (internal.mode != .@"2d") return;
    const context = internal.context orelse return;
    const width, const height = bitmapSize(element);
    dom.image_sources.setBitmapDimensions(context, width, height) catch {};
}

/// HTML "check the usability of the image argument" for a canvas: a zero
/// dimension is an InvalidStateError; otherwise its bitmap.
fn canvasUsability(instance: *runtime.Instance) dom.image_sources.Usability {
    const width, const height = bitmapSize(instance);
    if (width == 0 or height == 0) return .invalid_state;
    const internal = internalOf(instance) orelse return .bad;
    if (internal.mode == .@"2d") if (internal.context) |context| if (dom.image_sources.outputBitmap(context)) |bitmap| {
        return .{ .good = .{
            .width = bitmap.width,
            .height = bitmap.height,
            .pixels = bitmap.pixels,
            .alpha = .premultiplied,
            .origin_clean = bitmap.origin_clean,
        } };
    };
    // No context: a transparent black bitmap, whose drawing changes no
    // pixel and keeps the target origin-clean - nothing to draw.
    return .bad;
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLCanvasElement.init(ctx.allocator, ctx);
    errdefer HTMLCanvasElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for width: it reflects the width content attribute, default 300.
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    return bitmapSize(instance)[0];
}

/// Getter for height: it reflects the height content attribute, default 150.
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    return bitmapSize(instance)[1];
}

/// Setter for width: reflection of an unsigned long with the default 300 -
/// a value above 2147483647 sets the default. The attribute's change steps
/// set the bitmap dimensions.
pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
    try reflection.set(u32, instance, .{ .name = "width", .default = 300 }, value);
}

/// Setter for height: as width's, with the default 150.
pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
    try reflection.set(u32, instance, .{ .name = "height", .default = 150 }, value);
}

/// Operation: captureStream
pub fn call_captureStream(instance: *runtime.Instance, frameRequestRate: webidl.Opt(f64)) anyerror!*runtime.Instance {
    _ = instance;
    _ = frameRequestRate;
    return error.NotImplemented;
}

/// Operation: getContext
/// Returns a rendering context for the canvas, or null if the contextId is not supported.
/// Per HTML spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-getcontext
///
/// Not modelled, stated: `options` (the CanvasRenderingContext2DSettings:
/// alpha, colorSpace, colorType, willReadFrequently - a context is an opaque-
/// capable sRGB unorm8 one), and the other context types, which answer null
/// as an unsupported value does.
pub fn call_getContext(instance: *runtime.Instance, contextId: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!?typedefs.RenderingContext {
    _ = options;
    const internal = internalOf(instance) orelse return error.InvalidStateError;
    if (!std.mem.eql(u8, contextId.asSlice(), "2d")) return null;
    switch (internal.mode) {
        // "2d" in the none mode: the 2D context creation algorithm, then the
        // mode is 2d.
        .none => {
            const context = try interfaces.CanvasRenderingContext2D.init(instance.ctx.allocator, instance.ctx);
            errdefer interfaces.CanvasRenderingContext2D.deinit(context);
            const width, const height = bitmapSize(instance);
            try dom.image_sources.attachContext(context, instance, width, height);
            internal.context = context;
            internal.context_kept.made(context);
            internal.mode = .@"2d";
        },
        // "Return the same object as was returned the last time the method
        // was invoked with this same first argument."
        .@"2d" => {},
    }
    const context = internal.context orelse return null;
    internal.context_kept.handOut(instance, context, context_slot);
    return typedefs.RenderingContext{ .canvas_rendering_context2d = context };
}

/// Operation: toDataURL
pub fn call_toDataURL(instance: *runtime.Instance, @"type": webidl.Opt(runtime.DOMString), quality: webidl.Opt(runtime.JSValue)) anyerror!runtime.USVString {
    _ = instance;
    _ = @"type";
    _ = quality;
    return error.NotImplemented;
}

/// Operation: toBlob
pub fn call_toBlob(instance: *runtime.Instance, _callback: callbacks.BlobCallback, @"type": webidl.Opt(runtime.DOMString), quality: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = instance;
    _ = _callback;
    _ = @"type";
    _ = quality;
    return error.NotImplemented;
}

/// Operation: transferControlToOffscreen
pub fn call_transferControlToOffscreen(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}
