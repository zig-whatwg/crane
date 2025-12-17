//! Implementation for DOMQuad interface
//!
//! Geometry Interfaces Module Level 1 - DOMQuad
//! Spec: https://drafts.fxtf.org/geometry-1/#domquad
//!
//! A DOMQuad represents an arbitrary quadrilateral defined by four DOMPoint vertices.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DOMQuad = interfaces.DOMQuad;
const DOMPoint = interfaces.DOMPoint;
const DOMRect = interfaces.DOMRect;
const DOMRectImpl = @import("DOMRect.zig");

pub const State = DOMQuad.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Get state from instance
fn getState(instance: *runtime.Instance) *State {
    return instance.getState(State);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Create a DOMPoint instance with specified coordinates
/// Per spec, default values are (x=0, y=0, z=0, w=1)
fn createDOMPoint(ctx: runtime.Context, point_init: ?dictionaries.DOMPointInit) !*runtime.Instance {
    // Create DOMPoint through its constructor interface
    const x_opt = webidl.Opt(f64){
        .was_passed = true,
        .value = if (point_init) |p| p.x orelse 0 else 0,
    };
    const y_opt = webidl.Opt(f64){
        .was_passed = true,
        .value = if (point_init) |p| p.y orelse 0 else 0,
    };
    const z_opt = webidl.Opt(f64){
        .was_passed = true,
        .value = if (point_init) |p| p.z orelse 0 else 0,
    };
    const w_opt = webidl.Opt(f64){
        .was_passed = true,
        .value = if (point_init) |p| p.w orelse 1 else 1,
    };

    return DOMPoint.call_constructor(ctx, x_opt, y_opt, z_opt, w_opt);
}

/// Initialize with DOMPointInit parameters
pub fn initWithPoints(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    p1_init: ?dictionaries.DOMPointInit,
    p2_init: ?dictionaries.DOMPointInit,
    p3_init: ?dictionaries.DOMPointInit,
    p4_init: ?dictionaries.DOMPointInit,
) !*runtime.Instance {
    const instance = try init(allocator, State, &DOMQuad.vtable, ctx);
    errdefer deinit(instance);

    const state = getState(instance);

    // Create the four DOMPoint instances
    state.own.p1 = try createDOMPoint(ctx, p1_init);
    errdefer DOMPoint.deinit(state.own.p1);

    state.own.p2 = try createDOMPoint(ctx, p2_init);
    errdefer DOMPoint.deinit(state.own.p2);

    state.own.p3 = try createDOMPoint(ctx, p3_init);
    errdefer DOMPoint.deinit(state.own.p3);

    state.own.p4 = try createDOMPoint(ctx, p4_init);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Note: GC handles cleanup. The DOMPoint instances stored in p1-p4
    // will be collected by the garbage collector. We don't manually deinit
    // them here because they may still be referenced by JavaScript.
    _ = instance;
}

/// Constructor implementation
/// Spec: https://drafts.fxtf.org/geometry-1/#dom-domquad-domquad
/// Creates a DOMQuad with four vertices from DOMPointInit dictionaries
pub fn call_constructor(ctx: runtime.Context, p1: webidl.Opt(dictionaries.DOMPointInit), p2: webidl.Opt(dictionaries.DOMPointInit), p3: webidl.Opt(dictionaries.DOMPointInit), p4: webidl.Opt(dictionaries.DOMPointInit)) !*runtime.Instance {
    const p1_init = if (p1.was_passed) p1.value else null;
    const p2_init = if (p2.was_passed) p2.value else null;
    const p3_init = if (p3.was_passed) p3.value else null;
    const p4_init = if (p4.was_passed) p4.value else null;

    return initWithPoints(ctx.allocator, ctx, p1_init, p2_init, p3_init, p4_init);
}

/// Getter for p1
/// Spec: [SameObject] readonly attribute DOMPoint p1
pub fn get_p1(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = getState(instance);
    return state.own.p1;
}

/// Getter for p2
/// Spec: [SameObject] readonly attribute DOMPoint p2
pub fn get_p2(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = getState(instance);
    return state.own.p2;
}

/// Getter for p3
/// Spec: [SameObject] readonly attribute DOMPoint p3
pub fn get_p3(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = getState(instance);
    return state.own.p3;
}

/// Getter for p4
/// Spec: [SameObject] readonly attribute DOMPoint p4
pub fn get_p4(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = getState(instance);
    return state.own.p4;
}

/// Helper to get x coordinate from a DOMPoint instance
fn getPointX(point: *runtime.Instance) f64 {
    const point_state = point.getState(DOMPoint.State);
    return point_state.own.x;
}

/// Helper to get y coordinate from a DOMPoint instance
fn getPointY(point: *runtime.Instance) f64 {
    const point_state = point.getState(DOMPoint.State);
    return point_state.own.y;
}

/// Operation: getBounds
/// Spec: https://drafts.fxtf.org/geometry-1/#dom-domquad-getbounds
/// Returns a DOMRect that bounds the quad
pub fn call_getBounds(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = getState(instance);

    // Get x,y coordinates from all four points
    const x1 = getPointX(state.own.p1);
    const y1 = getPointY(state.own.p1);
    const x2 = getPointX(state.own.p2);
    const y2 = getPointY(state.own.p2);
    const x3 = getPointX(state.own.p3);
    const y3 = getPointY(state.own.p3);
    const x4 = getPointX(state.own.p4);
    const y4 = getPointY(state.own.p4);

    // Calculate bounding box
    const min_x = @min(@min(x1, x2), @min(x3, x4));
    const max_x = @max(@max(x1, x2), @max(x3, x4));
    const min_y = @min(@min(y1, y2), @min(y3, y4));
    const max_y = @max(@max(y1, y2), @max(y3, y4));

    const width = max_x - min_x;
    const height = max_y - min_y;

    // Create and return a new DOMRect
    return DOMRectImpl.initWithDimensions(std.heap.page_allocator, instance.ctx, min_x, min_y, width, height);
}

/// Operation: fromRect (static)
/// Spec: https://drafts.fxtf.org/geometry-1/#dom-domquad-fromrect
/// Creates a DOMQuad from a DOMRectInit (rectangle corners)
pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;

    // Extract rectangle values with defaults
    var x: f64 = 0;
    var y: f64 = 0;
    var width: f64 = 0;
    var height: f64 = 0;

    if (other.was_passed) {
        x = other.value.x orelse 0;
        y = other.value.y orelse 0;
        width = other.value.width orelse 0;
        height = other.value.height orelse 0;
    }

    // Create four corner points from rectangle
    const p1_init = dictionaries.DOMPointInit{ .x = x, .y = y, .z = 0, .w = 1 };
    const p2_init = dictionaries.DOMPointInit{ .x = x + width, .y = y, .z = 0, .w = 1 };
    const p3_init = dictionaries.DOMPointInit{ .x = x + width, .y = y + height, .z = 0, .w = 1 };
    const p4_init = dictionaries.DOMPointInit{ .x = x, .y = y + height, .z = 0, .w = 1 };

    return initWithPoints(std.heap.page_allocator, ctx, p1_init, p2_init, p3_init, p4_init);
}

/// Operation: fromQuad (static)
/// Spec: https://drafts.fxtf.org/geometry-1/#dom-domquad-fromquad
/// Creates a DOMQuad from a DOMQuadInit
pub fn call_static_fromQuad(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMQuadInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;

    // Extract point values (or use defaults)
    var p1_init: ?dictionaries.DOMPointInit = null;
    var p2_init: ?dictionaries.DOMPointInit = null;
    var p3_init: ?dictionaries.DOMPointInit = null;
    var p4_init: ?dictionaries.DOMPointInit = null;

    if (other.was_passed) {
        p1_init = other.value.p1;
        p2_init = other.value.p2;
        p3_init = other.value.p3;
        p4_init = other.value.p4;
    }

    return initWithPoints(std.heap.page_allocator, ctx, p1_init, p2_init, p3_init, p4_init);
}

/// toJSON operation
/// Spec: https://drafts.fxtf.org/geometry-1/#dom-domquad-tojson
/// Per WebIDL spec, [Default] toJSON returns an object with all exposed attributes.
/// For DOMQuad, this serializes p1-p4 as DOMPoint instances.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.DOMQuad.DOMQuadToJSON {
    const state = getState(instance);
    // Return the DOMPoint instances - they will be converted to JS objects
    // with proper prototype chains by the V8 toV8Value conversion layer
    return .{
        .p1 = state.own.p1,
        .p2 = state.own.p2,
        .p3 = state.own.p3,
        .p4 = state.own.p4,
    };
}

/// Duplicate static methods for non-static calls (legacy API pattern)
pub fn call_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    return call_static_fromRect(instance, other);
}

pub fn call_fromQuad(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMQuadInit)) anyerror!*runtime.Instance {
    return call_static_fromQuad(instance, other);
}
