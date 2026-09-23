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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}
