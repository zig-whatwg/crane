//! XPathEvaluatorBase Mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-xpathevaluatorbase
//!
//! This mixin delegates to the XPathEvaluatorBase impl for all functionality.
//! The impl contains the actual logic for XPathEvaluatorBase methods.
//!
//! The XPathEvaluatorBase mixin defines:
//! - createExpression(expression, resolver) - Creates a compiled XPath expression
//! - createNSResolver(nodeResolver) - Creates an XPathNSResolver
//! - evaluate(expression, contextNode, resolver, type, result) - Evaluates XPath

const std = @import("std");
const runtime = @import("runtime");

// Import the impl which contains all the actual logic
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    TypeError,
    OutOfMemory,
};

// Re-export ResultType from impl
pub const ResultType = XPathEvaluatorBaseImpl.ResultType;

// =============================================================================
// XPathEvaluatorBase Methods (delegate to impl)
// =============================================================================

/// createExpression - Creates a compiled XPath expression
/// Spec: https://dom.spec.whatwg.org/#dom-xpathevaluatorbase-createexpression
pub fn createExpression(
    allocator: std.mem.Allocator,
    root: *runtime.Instance,
    expression: []const u8,
    resolver: ?*runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    _ = allocator;
    _ = resolver;
    _ = ctx;

    const dom_string = runtime.DOMString.initInterned(expression);
    return XPathEvaluatorBaseImpl.call_createExpression(root, dom_string, .none) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.SyntaxError => return error.SyntaxError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// createNSResolver - Creates an XPathNSResolver from a node
/// Spec: https://dom.spec.whatwg.org/#dom-xpathevaluatorbase-creatensresolver
pub fn createNSResolver(
    allocator: std.mem.Allocator,
    root: *runtime.Instance,
    node_resolver: *runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    _ = allocator;
    _ = ctx;

    return XPathEvaluatorBaseImpl.call_createNSResolver(root, node_resolver) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

/// evaluate - Evaluates an XPath expression
/// Spec: https://dom.spec.whatwg.org/#dom-xpathevaluatorbase-evaluate
pub fn evaluate(
    allocator: std.mem.Allocator,
    root: *runtime.Instance,
    expression: []const u8,
    context_node: *runtime.Instance,
    resolver: ?*runtime.Instance,
    result_type: u16,
    result: ?*runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    _ = allocator;
    _ = resolver;
    _ = ctx;

    const dom_string = runtime.DOMString.initInterned(expression);
    return XPathEvaluatorBaseImpl.call_evaluate(
        root,
        dom_string,
        context_node,
        .none,
        .{ .value = result_type },
        .{ .value = result },
    ) catch |err| switch (err) {
        error.NotImplemented => return error.NotImplemented,
        error.SyntaxError => return error.SyntaxError,
        error.TypeError => return error.TypeError,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidStateError,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "XPathEvaluatorBase mixin - delegation to impl" {
    // Test that mixin correctly delegates to impl
    // Full tests are in the impl file
}
