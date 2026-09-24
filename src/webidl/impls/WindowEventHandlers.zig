//! WindowEventHandlers: event handler IDL attributes (HTML §8.1.8.1).
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#windoweventhandlers
//!
//! Every interface that includes WindowEventHandlers inherits these members
//! (src/webidl/codegen/inherited_mixins.zig), so this is their one
//! implementation, with `this` an instance of whichever includer the
//! attribute was read on. A handler lives in its target's event handler map,
//! on EventTarget - the ancestor every includer shares.

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

// =============================================================================
// Event handler IDL attributes
// =============================================================================

const EventTargetImpl = @import("EventTarget.zig");
const event_handler_target = @import("event_handler_target.zig");

/// The event handler IDL attribute getter steps.
fn handlerValue(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8) Handler {
    // Step 1: "Let eventTarget be the result of determining the target of an
    // event handler given this object and name."
    // Step 2: "If eventTarget is null, then return null."
    const target = event_handler_target.determine(this, name) orelse return null;
    // Step 3: "Return the result of getting the current value of the event
    // handler given eventTarget and name."
    return EventTargetImpl.eventHandler(Handler, target, name[2..]);
}

/// The event handler IDL attribute setter steps.
fn setHandlerValue(comptime Handler: type, this: *runtime.Instance, comptime name: []const u8, value: Handler) !void {
    // Steps 1 and 2: the target, or nothing to do.
    const target = event_handler_target.determine(this, name) orelse return;
    // Steps 3 and 4 on the target's event handler map.
    try EventTargetImpl.setEventHandler(Handler, target, name[2..], value);
}

/// Getter for onafterprint
pub fn get_onafterprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onafterprint");
}

/// Setter for onafterprint
pub fn set_onafterprint(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onafterprint", value);
}

/// Getter for onbeforeprint
pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onbeforeprint");
}

/// Setter for onbeforeprint
pub fn set_onbeforeprint(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onbeforeprint", value);
}

/// Getter for onbeforeunload
pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!typedefs.OnBeforeUnloadEventHandler {
    return handlerValue(typedefs.OnBeforeUnloadEventHandler, instance, "onbeforeunload");
}

/// Setter for onbeforeunload
pub fn set_onbeforeunload(instance: *runtime.Instance, value: typedefs.OnBeforeUnloadEventHandler) anyerror!void {
    try setHandlerValue(typedefs.OnBeforeUnloadEventHandler, instance, "onbeforeunload", value);
}

/// Getter for onhashchange
pub fn get_onhashchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onhashchange");
}

/// Setter for onhashchange
pub fn set_onhashchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onhashchange", value);
}

/// Getter for onlanguagechange
pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onlanguagechange");
}

/// Setter for onlanguagechange
pub fn set_onlanguagechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onlanguagechange", value);
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmessage");
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmessage", value);
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onmessageerror");
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onmessageerror", value);
}

/// Getter for onoffline
pub fn get_onoffline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onoffline");
}

/// Setter for onoffline
pub fn set_onoffline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onoffline", value);
}

/// Getter for ononline
pub fn get_ononline(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ononline");
}

/// Setter for ononline
pub fn set_ononline(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ononline", value);
}

/// Getter for onpagehide
pub fn get_onpagehide(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpagehide");
}

/// Setter for onpagehide
pub fn set_onpagehide(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpagehide", value);
}

/// Getter for onpagereveal
pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpagereveal");
}

/// Setter for onpagereveal
pub fn set_onpagereveal(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpagereveal", value);
}

/// Getter for onpageshow
pub fn get_onpageshow(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpageshow");
}

/// Setter for onpageshow
pub fn set_onpageshow(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpageshow", value);
}

/// Getter for onpageswap
pub fn get_onpageswap(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpageswap");
}

/// Setter for onpageswap
pub fn set_onpageswap(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpageswap", value);
}

/// Getter for onpopstate
pub fn get_onpopstate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onpopstate");
}

/// Setter for onpopstate
pub fn set_onpopstate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onpopstate", value);
}

/// Getter for onrejectionhandled
pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onrejectionhandled");
}

/// Setter for onrejectionhandled
pub fn set_onrejectionhandled(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onrejectionhandled", value);
}

/// Getter for onstorage
pub fn get_onstorage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onstorage");
}

/// Setter for onstorage
pub fn set_onstorage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onstorage", value);
}

/// Getter for onunhandledrejection
pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onunhandledrejection");
}

/// Setter for onunhandledrejection
pub fn set_onunhandledrejection(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onunhandledrejection", value);
}

/// Getter for onunload
pub fn get_onunload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onunload");
}

/// Setter for onunload
pub fn set_onunload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onunload", value);
}

/// Getter for ongamepadconnected
pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ongamepadconnected");
}

/// Setter for ongamepadconnected
pub fn set_ongamepadconnected(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ongamepadconnected", value);
}

/// Getter for ongamepaddisconnected
pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "ongamepaddisconnected");
}

/// Setter for ongamepaddisconnected
pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "ongamepaddisconnected", value);
}

/// Getter for onportalactivate
pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return handlerValue(typedefs.EventHandler, instance, "onportalactivate");
}

/// Setter for onportalactivate
pub fn set_onportalactivate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try setHandlerValue(typedefs.EventHandler, instance, "onportalactivate", value);
}
