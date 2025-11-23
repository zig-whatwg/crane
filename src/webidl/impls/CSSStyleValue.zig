//! Implementation for CSSStyleValue interface
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
const CSSStyleValue = interfaces.CSSStyleValue;

pub const State = CSSStyleValue.State;

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

/// Operation: parseAll
pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) ImplError!*const anyopaque {
    _ = instance;
    _ = property;
    _ = cssText;
    return error.NotImplemented;
}

/// Operation: parse
pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) ImplError!*runtime.Instance {
    _ = instance;
    _ = property;
    _ = cssText;
    return error.NotImplemented;
}

