//! Implementation for XMLHttpRequestUpload interface
//!
//! XMLHttpRequestUpload inherits from XMLHttpRequestEventTarget, which provides
//! the event handler properties (onloadstart, onprogress, etc.).
//!
//! Those handlers are kept in EventTarget's event handler map, like every
//! other event handler IDL attribute's.
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
const XMLHttpRequestEventTargetImpl = @import("XMLHttpRequestEventTarget.zig");

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
    // An XMLHttpRequestUpload is an XMLHttpRequestEventTarget, whose event
    // handlers - and listeners - are EventTarget's.
    return XMLHttpRequestEventTargetImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
    XMLHttpRequestEventTargetImpl.deinit(instance);
}
