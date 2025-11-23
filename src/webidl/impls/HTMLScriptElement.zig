//! Implementation for HTMLScriptElement interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLScriptElement = interfaces.HTMLScriptElement;

pub const State = HTMLScriptElement.State;

pub const ImplError = error{
    NotImplemented,
};

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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &HTMLScriptElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for src
pub fn get_src(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for noModule
pub fn get_noModule(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for async
pub fn get_async(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for defer
pub fn get_defer(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for blocking
pub fn get_blocking(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for integrity
pub fn get_integrity(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fetchPriority
pub fn get_fetchPriority(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for text
pub fn get_text(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for charset
pub fn get_charset(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for event
pub fn get_event(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for htmlFor
pub fn get_htmlFor(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for src
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for noModule
pub fn set_noModule(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for async
pub fn set_async(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for defer
pub fn set_defer(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for integrity
pub fn set_integrity(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fetchPriority
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for charset
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for event
pub fn set_event(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for htmlFor
pub fn set_htmlFor(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, @"type": runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = @"type";
    return error.NotImplemented;
}

