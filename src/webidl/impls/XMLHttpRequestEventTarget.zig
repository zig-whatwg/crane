//! Implementation for XMLHttpRequestEventTarget interface
//!
//! XMLHttpRequestEventTarget provides event handler properties for XHR events.
//! Spec: https://xhr.spec.whatwg.org/#xmlhttprequesteventtarget
//!
//! ## What these fields actually hold
//!
//! `typedefs.EventHandler` is `?*const fn (*Instance) JSValue`, but nothing of
//! that shape is ever stored in it. The V8 conversion layer creates a
//! `Global<Value>` for the assigned function and TAGS the pointer, so the field
//! holds a deliberately misaligned address whose low two bits are a tag.
//! Reading it back needs a byte copy - `@ptrCast`/`@alignCast` panic with
//! "incorrect alignment" in a safe build.
//!
//! `src/webidl/impls/XMLHttpRequest.zig` is what invokes them, through
//! `interfaces.XMLHttpRequestEventTarget.State`, which reaches these fields on
//! an XMLHttpRequest and on an XMLHttpRequestUpload alike.
//!
//! ## Known leak, deliberately not fixed here
//!
//! Overwriting one of these fields drops the previous Global without disposing
//! it, so `xhr.onload = a; xhr.onload = b` leaks one handle.
//! `WebSocket.set_onopen` disposes the old one; `HTMLElement.setEventHandler`
//! does not. Adding disposal needs PROOF that nothing else holds that Global -
//! the conversion layer hands the same tagged pointer back out of the getter -
//! and AGENTS.md is explicit that guessing here has shipped use-after-frees
//! twice. Recorded rather than guessed at.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XMLHttpRequestEventTarget = interfaces.XMLHttpRequestEventTarget;

pub const State = XMLHttpRequestEventTarget.State;

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
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onloadstart;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onprogress;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onabort;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onload;
}

/// Getter for ontimeout
pub fn get_ontimeout(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.ontimeout;
}

/// Getter for onloadend
pub fn get_onloadend(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onloadend;
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onloadstart = value;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onprogress = value;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onabort = value;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onerror = value;
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onload = value;
}

/// Setter for ontimeout
pub fn set_ontimeout(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.ontimeout = value;
}

/// Setter for onloadend
pub fn set_onloadend(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.onloadend = value;
}
