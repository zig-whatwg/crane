//! WindowEventHandlers: event handler IDL attributes (HTML §8.1.8.1).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#windoweventhandlers
//!
//! Every interface that includes WindowEventHandlers inherits these members
//! (src/webidl/codegen/inherited_mixins.zig), and every one is an event
//! handler IDL attribute, whose getter and setter the generated mixin module
//! supplies: HTML's steps, `dom.event_handlers.value` / `setValue` -
//! "determining the target of an event handler" (a body element's
//! window-reflecting handlers are its Window's) included. The handlers live
//! in their target's event handler map, on EventTarget. So this impl
//! declares nothing per attribute.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WindowEventHandlers = interfaces.WindowEventHandlers;

pub const State = WindowEventHandlers.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}
