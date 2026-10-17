//! Implementation for the PaintWorkletGlobalScope interface (CSS Painting
//! API 3): the paint worklet's global scope, whose registerPaint() records a
//! paint definition. Crane paints nothing, so no definition is invoked (see
//! html.worklet_host, "Registering classes").

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const engine = @import("engine");
const html = @import("html");
const PaintWorkletGlobalScope = interfaces.PaintWorkletGlobalScope;
const worklet_host = html.worklet_host;

pub const State = PaintWorkletGlobalScope.State;

/// A paint definition (CSS Painting API 3), less its class constructor and
/// paint function, which nothing invokes.
const PaintDefinition = struct {
    input_properties: [][]u8,
    input_arguments: [][]u8,
    /// Its PaintRenderingContext2DSettings' alpha.
    alpha: bool,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The paint definitions map (CSS Painting API 4).
    definitions: worklet_host.Definitions(PaintDefinition) = .{},
};

fn freeDefinition(allocator: std.mem.Allocator, definition: *PaintDefinition) void {
    worklet_host.freeStrings(allocator, definition.input_properties);
    worklet_host.freeStrings(allocator, definition.input_arguments);
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.getState(State);
    if (state.own._internal) |internal| return internal;
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    state.own._internal = internal;
    return internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.definitions.deinit(internal.allocator, freeDefinition);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for devicePixelRatio: the owning Window's (not modelled: nothing
/// paints).
pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// registerPaint(name, paintCtor) - CSS Painting API 4.
pub fn call_registerPaint(instance: *runtime.Instance, name: runtime.DOMString, paintCtor: callbacks.VoidFunction) anyerror!void {
    const constructor = engine.takeCallbackFunction(@ptrCast(paintCtor));
    defer constructor.release();
    const realm = instance.ctx;
    const ctor = constructor.function.value;
    const name_slice = name.asSlice();

    // Step 1: an empty name throws a TypeError.
    if (name_slice.len == 0) return error.TypeError;
    // Steps 2-3: a name already defined throws an InvalidModificationError.
    const internal = try internalOf(instance);
    const allocator = internal.allocator;
    if (internal.definitions.contains(name_slice)) return error.InvalidModificationError;
    // Steps 4-7: inputProperties, filtered to supported and custom properties.
    const input_properties = worklet_host.keepSupportedProperties(allocator, try worklet_host.stringSequence(realm, ctor, "inputProperties", allocator));
    errdefer worklet_host.freeStrings(allocator, input_properties);
    // Steps 8-10: inputArguments.
    const input_arguments = try worklet_host.stringSequence(realm, ctor, "inputArguments", allocator);
    errdefer worklet_host.freeStrings(allocator, input_arguments);
    // Steps 11-12 consume a syntax definition (CSS Properties and Values API)
    // from each argument: Crane has no syntax-definition parser yet, so
    // they are not checked (TODO: with @property's syntax descriptor).
    // Steps 13-14: contextOptions, converted to PaintRenderingContext2DSettings.
    const alpha = try contextAlpha(realm, ctor);
    // Steps 15-17: a constructor whose prototype is an Object.
    const prototype = try worklet_host.classPrototype(realm, ctor);
    defer prototype.release();
    // Steps 18-19: its paint function.
    try worklet_host.requireFunction(realm, prototype.value, "paint");
    // Steps 20-21: the definition.
    try internal.definitions.put(allocator, name_slice, .{ .input_properties = input_properties, .input_arguments = input_arguments, .alpha = alpha });
    // Step 22 records a document paint definition for painting, which Crane
    // does not do.
}

/// Get(paintCtor, "contextOptions") converted to the dictionary
/// PaintRenderingContext2DSettings { boolean alpha = true; } (WebIDL 3.2.18):
/// undefined or null is the defaults, any other non-object a TypeError.
fn contextAlpha(realm: runtime.Context, ctor: runtime.JSValue) !bool {
    const options = try engine.getProperty(realm, ctor, "contextOptions");
    defer options.release();
    switch (engine.typeOf(realm, options.value)) {
        .undefined, .null => return true,
        .object => {},
        else => return error.TypeError,
    }
    const alpha = try engine.getProperty(realm, options.value, "alpha");
    defer alpha.release();
    if (engine.typeOf(realm, alpha.value) == .undefined) return true;
    return engine.toBoolean(realm, alpha.value);
}
