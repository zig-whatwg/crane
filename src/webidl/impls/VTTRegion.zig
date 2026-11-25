//! WebVTT 9.2: the VTTRegion interface - a WebVTT region (3.4), made by
//! script or by the WebVTT parser for a REGION block (6.1, region creation).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const VTTRegion = interfaces.VTTRegion;

pub const State = VTTRegion.State;

/// A WebVTT region's settings (WebVTT 3.4).
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// WebVTT region identifier.
    identifier: runtime.DOMString = .initEmpty(),
    /// WebVTT region width, a percentage of the video width.
    width: f64 = 100,
    /// WebVTT region lines.
    lines: u32 = 3,
    /// WebVTT region anchor (X, Y), percentages of the region.
    anchor_x: f64 = 0,
    anchor_y: f64 = 100,
    /// WebVTT region viewport anchor (X, Y), percentages of the video.
    viewport_anchor_x: f64 = 0,
    viewport_anchor_y: f64 = 100,
    /// WebVTT region scroll: none ("") or up.
    scroll: enums.ScrollSetting = .__,
};

/// The region's own construction steps (the constructor's 2-9 are
/// InternalState's defaults).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        state.own._internal = null;
        internal.identifier.deinit(internal.allocator);
        internal.allocator.destroy(internal);
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return (instance.stateAs(State) orelse return error.InvalidStateError).own._internal orelse error.InvalidStateError;
}

/// The VTTRegion() constructor: 1. a new WebVTT region; 2-9. its identifier
/// the empty string, width 100, lines 3, region anchor (0, 100), viewport
/// anchor (0, 100), scroll none (`InternalState`); 10. return it.
pub fn call_constructor(instance: *runtime.Instance) !void {
    // The generated constructor made it (WebIDL 3.7.1 step 1.8): no steps.
    _ = instance;
}

/// WebVTT 9.2: "set to the new value" when it is not negative or more than
/// 100; an IndexSizeError otherwise.
fn percentage(value: f64) !f64 {
    if (value < 0 or value > 100) return error.IndexSizeError;
    return value;
}

pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    return internal.identifier.clone(instance.ctx.allocator);
}

pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = try internalOf(instance);
    const copy = try value.clone(internal.allocator);
    internal.identifier.deinit(internal.allocator);
    internal.identifier = copy;
}

pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).width;
}

pub fn set_width(instance: *runtime.Instance, value: f64) anyerror!void {
    (try internalOf(instance)).width = try percentage(value);
}

pub fn get_lines(instance: *runtime.Instance) anyerror!u32 {
    return (try internalOf(instance)).lines;
}

/// "On setting, the WebVTT region lines must be set to the new value" - an
/// unsigned long, so the WebIDL conversion has already made it one.
pub fn set_lines(instance: *runtime.Instance, value: u32) anyerror!void {
    (try internalOf(instance)).lines = value;
}

pub fn get_regionAnchorX(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).anchor_x;
}

pub fn set_regionAnchorX(instance: *runtime.Instance, value: f64) anyerror!void {
    (try internalOf(instance)).anchor_x = try percentage(value);
}

pub fn get_regionAnchorY(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).anchor_y;
}

pub fn set_regionAnchorY(instance: *runtime.Instance, value: f64) anyerror!void {
    (try internalOf(instance)).anchor_y = try percentage(value);
}

pub fn get_viewportAnchorX(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).viewport_anchor_x;
}

pub fn set_viewportAnchorX(instance: *runtime.Instance, value: f64) anyerror!void {
    (try internalOf(instance)).viewport_anchor_x = try percentage(value);
}

pub fn get_viewportAnchorY(instance: *runtime.Instance) anyerror!f64 {
    return (try internalOf(instance)).viewport_anchor_y;
}

pub fn set_viewportAnchorY(instance: *runtime.Instance, value: f64) anyerror!void {
    (try internalOf(instance)).viewport_anchor_y = try percentage(value);
}

pub fn get_scroll(instance: *runtime.Instance) anyerror!enums.ScrollSetting {
    return (try internalOf(instance)).scroll;
}

/// An enumeration attribute: a value that is not "" or "up" never reaches
/// here (WebIDL 3.7.6, an invalid enumeration value assigned to an attribute
/// is ignored by the binding).
pub fn set_scroll(instance: *runtime.Instance, value: enums.ScrollSetting) anyerror!void {
    (try internalOf(instance)).scroll = value;
}
