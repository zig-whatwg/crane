//! Implementation for HTMLProgressElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLProgressElement = interfaces.HTMLProgressElement;
const form_associated = @import("html").form_associated;

pub const State = HTMLProgressElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Created only when labels is read, from the element's arena.
pub const InternalState = struct {
    labels: form_associated.LabelsCache = .{},
};

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.labels.deinit(instance);
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLProgressElement.init(ctx.allocator, ctx);
    errdefer HTMLProgressElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for position
pub fn get_position(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for labels
pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    if (state.own._internal == null) {
        const internal = try runtime.arenaOf(instance).create(InternalState);
        internal.* = .{};
        state.own._internal = internal;
    }
    return state.own._internal.?.labels.get(instance);
}
