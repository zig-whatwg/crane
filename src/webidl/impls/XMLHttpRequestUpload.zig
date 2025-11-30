//! Implementation for XMLHttpRequestUpload interface
//!
//! XMLHttpRequestUpload inherits from XMLHttpRequestEventTarget, which provides
//! the event handler properties (onloadstart, onprogress, etc.).
//!
//! Since the state is flattened via FlattenedState, inherited event handler
//! properties are accessed through state.base.own.* (XMLHttpRequestEventTarget's own fields).
//!
//! Spec: https://xhr.spec.whatwg.org/#xmlhttprequestupload

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLHttpRequestUpload = interfaces.XMLHttpRequestUpload;

pub const State = XMLHttpRequestUpload.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize inherited XMLHttpRequestEventTarget event handler fields
    const state = instance.getState(StateType);
    state.base.own.onloadstart = null;
    state.base.own.onprogress = null;
    state.base.own.onabort = null;
    state.base.own.onerror = null;
    state.base.own.onload = null;
    state.base.own.ontimeout = null;
    state.base.own.onloadend = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

// ============================================================================
// Inherited event handler getters/setters
// These access state.base.own.* (XMLHttpRequestEventTarget's own fields)
// ============================================================================

/// Getter for onloadstart (inherited from XMLHttpRequestEventTarget)
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onloadstart;
}

/// Setter for onloadstart (inherited from XMLHttpRequestEventTarget)
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onloadstart = value;
}

/// Getter for onprogress (inherited from XMLHttpRequestEventTarget)
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onprogress;
}

/// Setter for onprogress (inherited from XMLHttpRequestEventTarget)
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onprogress = value;
}

/// Getter for onabort (inherited from XMLHttpRequestEventTarget)
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onabort;
}

/// Setter for onabort (inherited from XMLHttpRequestEventTarget)
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onabort = value;
}

/// Getter for onerror (inherited from XMLHttpRequestEventTarget)
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onerror;
}

/// Setter for onerror (inherited from XMLHttpRequestEventTarget)
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onerror = value;
}

/// Getter for onload (inherited from XMLHttpRequestEventTarget)
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onload;
}

/// Setter for onload (inherited from XMLHttpRequestEventTarget)
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onload = value;
}

/// Getter for ontimeout (inherited from XMLHttpRequestEventTarget)
pub fn get_ontimeout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.ontimeout;
}

/// Setter for ontimeout (inherited from XMLHttpRequestEventTarget)
pub fn set_ontimeout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.ontimeout = value;
}

/// Getter for onloadend (inherited from XMLHttpRequestEventTarget)
pub fn get_onloadend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.base.own.onloadend;
}

/// Setter for onloadend (inherited from XMLHttpRequestEventTarget)
pub fn set_onloadend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.base.own.onloadend = value;
}
