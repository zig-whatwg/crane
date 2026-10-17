//! Implementation for the LayoutWorkletGlobalScope interface (CSS Layout
//! API): the layout worklet's global scope, whose registerLayout() records a
//! layout definition. Crane lays out nothing (layout is the host's), so no
//! definition is invoked (see html.worklet_host, "Registering classes").

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const callbacks = @import("callbacks");
const engine = @import("engine");
const html = @import("html");
const LayoutWorkletGlobalScope = interfaces.LayoutWorkletGlobalScope;
const worklet_host = html.worklet_host;

pub const State = LayoutWorkletGlobalScope.State;

/// LayoutOptions' members (CSS Layout API): ChildDisplayType and
/// LayoutSizingMode.
const ChildDisplay = enum { block, normal };
const Sizing = enum { block_like, manual };

/// A layout definition, less its class constructor and functions, which
/// nothing invokes.
const LayoutDefinition = struct {
    input_properties: [][]u8,
    child_input_properties: [][]u8,
    child_display: ChildDisplay,
    sizing: Sizing,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The layout definitions map.
    definitions: worklet_host.Definitions(LayoutDefinition) = .{},
};

fn freeDefinition(allocator: std.mem.Allocator, definition: *LayoutDefinition) void {
    worklet_host.freeStrings(allocator, definition.input_properties);
    worklet_host.freeStrings(allocator, definition.child_input_properties);
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

/// registerLayout(name, layoutCtor) - CSS Layout API, "Registering a
/// Layout".
pub fn call_registerLayout(instance: *runtime.Instance, name: runtime.DOMString, layoutCtor: callbacks.VoidFunction) anyerror!void {
    const constructor = engine.takeCallbackFunction(@ptrCast(layoutCtor));
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
    // Steps 4-7: inputProperties, filtered.
    const input_properties = worklet_host.keepSupportedProperties(allocator, try worklet_host.stringSequence(realm, ctor, "inputProperties", allocator));
    errdefer worklet_host.freeStrings(allocator, input_properties);
    // Steps 8-11: childInputProperties, filtered.
    const child_input_properties = worklet_host.keepSupportedProperties(allocator, try worklet_host.stringSequence(realm, ctor, "childInputProperties", allocator));
    errdefer worklet_host.freeStrings(allocator, child_input_properties);
    // Steps 12-13: layoutOptions, converted to LayoutOptions.
    var child_display: ChildDisplay = .block;
    var sizing: Sizing = .block_like;
    try layoutOptions(realm, ctor, allocator, &child_display, &sizing);
    // Steps 14-15: a constructor whose prototype is an Object.
    const prototype = try worklet_host.classPrototype(realm, ctor);
    defer prototype.release();
    // Steps 16-19: its intrinsicSizes and layout functions.
    try worklet_host.requireFunction(realm, prototype.value, "intrinsicSizes");
    try worklet_host.requireFunction(realm, prototype.value, "layout");
    // Steps 20-21: the definition.
    try internal.definitions.put(allocator, name_slice, .{
        .input_properties = input_properties,
        .child_input_properties = child_input_properties,
        .child_display = child_display,
        .sizing = sizing,
    });
    // Step 22 records a document layout definition for layout, which is the
    // host's.
}

/// Get(layoutCtor, "layoutOptions") converted to the dictionary LayoutOptions
/// { ChildDisplayType childDisplay = "block"; LayoutSizingMode sizing =
/// "block-like"; } (WebIDL 3.2.18: members in lexicographic order; an enum
/// value that is none of its strings is a TypeError).
fn layoutOptions(realm: runtime.Context, ctor: runtime.JSValue, allocator: std.mem.Allocator, child_display: *ChildDisplay, sizing: *Sizing) !void {
    const options = try engine.getProperty(realm, ctor, "layoutOptions");
    defer options.release();
    switch (engine.typeOf(realm, options.value)) {
        .undefined, .null => return,
        .object => {},
        else => return error.TypeError,
    }
    if (try enumMember(realm, options.value, "childDisplay", allocator, &.{ "block", "normal" })) |index| {
        child_display.* = @enumFromInt(index);
    }
    if (try enumMember(realm, options.value, "sizing", allocator, &.{ "block-like", "manual" })) |index| {
        sizing.* = @enumFromInt(index);
    }
}

/// A dictionary member of an enumeration type: null when undefined, else
/// the index of its value among `values`, or a TypeError.
fn enumMember(realm: runtime.Context, dictionary: runtime.JSValue, member: []const u8, allocator: std.mem.Allocator, values: []const []const u8) !?usize {
    const value = try engine.getProperty(realm, dictionary, member);
    defer value.release();
    if (engine.typeOf(realm, value.value) == .undefined) return null;
    const string = try engine.convertToDOMString(realm, value.value, allocator);
    defer allocator.free(string);
    for (values, 0..) |candidate, index| {
        if (std.mem.eql(u8, candidate, string)) return index;
    }
    return error.TypeError;
}
