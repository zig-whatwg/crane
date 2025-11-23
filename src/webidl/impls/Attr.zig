//! Implementation for Attr interface
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
const Attr = interfaces.Attr;

pub const State = Attr.State;

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

/// Getter for namespaceURI
pub fn get_namespaceURI(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for prefix
pub fn get_prefix(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for localName
pub fn get_localName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ownerElement
pub fn get_ownerElement(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for specified
pub fn get_specified(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for value
pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

