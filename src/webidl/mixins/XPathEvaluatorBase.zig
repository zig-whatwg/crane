//! Auto-generated mixin: XPathEvaluatorBase
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;

// Re-export types from impl
pub const impl = @import("impls").XPathEvaluatorBase;

pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) !*runtime.Instance {
    return XPathEvaluatorBaseImpl.call_createNSResolver(instance, nodeResolver);
}

pub fn call_evaluate(instance: *runtime.Instance, expression: typedefs.DOMString, contextNode: *runtime.Instance, resolver: ??*runtime.CallbackWrapper, @"type": runtime.JSValue, result: ?*runtime.Instance) !*runtime.Instance {
    return XPathEvaluatorBaseImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
}

pub fn call_createExpression(instance: *runtime.Instance, expression: typedefs.DOMString, resolver: ??*runtime.CallbackWrapper) !*runtime.Instance {
    return XPathEvaluatorBaseImpl.call_createExpression(instance, expression, resolver);
}

