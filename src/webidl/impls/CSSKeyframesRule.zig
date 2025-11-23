//! Implementation for CSSKeyframesRule interface
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
const CSSKeyframesRule = interfaces.CSSKeyframesRule;

pub const State = CSSKeyframesRule.State;

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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cssRules
pub fn get_cssRules(instance: *runtime.Instance) ImplError!interfaces.CSSRuleList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: deleteRule
pub fn call_deleteRule(instance: *runtime.Instance, select: *const anyopaque) ImplError!void {
    _ = instance;
    _ = select;
    return error.NotImplemented;
}

/// Operation: findRule
pub fn call_findRule(instance: *runtime.Instance, select: *const anyopaque) ImplError!interfaces.CSSKeyframeRule {
    _ = instance;
    _ = select;
    return error.NotImplemented;
}

/// Operation: appendRule
pub fn call_appendRule(instance: *runtime.Instance, rule: *const anyopaque) ImplError!void {
    _ = instance;
    _ = rule;
    return error.NotImplemented;
}

