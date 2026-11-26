//! Implementation for the XPathEvaluatorBase mixin (DOM §8.2):
//! createExpression(), createNSResolver(), and evaluate(), shared by Document
//! and XPathEvaluator.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const XPathEvaluatorBase = interfaces.XPathEvaluatorBase;

pub const State = XPathEvaluatorBase.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Operation: createExpression (DOM §8.2).
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: webidl.Opt(?runtime.BorrowedCallbackInterface)) anyerror!*runtime.Instance {
    return interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
}

/// Operation: createNSResolver (DOM §8.3): legacy identity method.
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return nodeResolver;
}

/// Operation: evaluate (DOM Level 3 XPath §1.4).
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(?runtime.BorrowedCallbackInterface), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    const compiled = try interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
    defer runtime.Instance.deinit(compiled);
    return interfaces.XPathExpression.call_evaluate(compiled, contextNode, @"type", result);
}
