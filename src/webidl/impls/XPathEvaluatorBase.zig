//! Implementation for XPathEvaluatorBase interface
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
const XPathEvaluatorBase = interfaces.XPathEvaluatorBase;

pub const State = XPathEvaluatorBase.State;

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

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = nodeResolver;
    return error.NotImplemented;
}

/// Operation: evaluate
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: interfaces.Node, resolver: interfaces.XPathNSResolver, @"type": u16, result: interfaces.XPathResult) ImplError!interfaces.XPathResult {
    _ = instance;
    _ = expression;
    _ = contextNode;
    _ = resolver;
    _ = @"type";
    _ = result;
    return error.NotImplemented;
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: interfaces.XPathNSResolver) ImplError!interfaces.XPathExpression {
    _ = instance;
    _ = expression;
    _ = resolver;
    return error.NotImplemented;
}

