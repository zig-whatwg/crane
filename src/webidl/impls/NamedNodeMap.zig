//! Implementation for NamedNodeMap interface
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
const NamedNodeMap = interfaces.NamedNodeMap;

pub const State = NamedNodeMap.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!interfaces.Attr {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: getNamedItemNS
pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: getNamedItem
pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: setNamedItemNS
pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: interfaces.Attr) ImplError!interfaces.Attr {
    _ = instance;
    _ = attr;
    return error.NotImplemented;
}

/// Operation: removeNamedItem
pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = qualifiedName;
    return error.NotImplemented;
}

/// Operation: removeNamedItemNS
pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: runtime.DOMString, localName: runtime.DOMString) ImplError!interfaces.Attr {
    _ = instance;
    _ = namespace;
    _ = localName;
    return error.NotImplemented;
}

/// Operation: setNamedItem
pub fn call_setNamedItem(instance: *runtime.Instance, attr: interfaces.Attr) ImplError!interfaces.Attr {
    _ = instance;
    _ = attr;
    return error.NotImplemented;
}

