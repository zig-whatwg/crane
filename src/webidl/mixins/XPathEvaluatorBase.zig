//! Auto-generated mixin: XPathEvaluatorBase
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XPathEvaluatorBaseImpl = @import("impls").XPathEvaluatorBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const XPathExpression = @import("interfaces").XPathExpression;
const Node = @import("interfaces").Node;
const XPathResult = @import("interfaces").XPathResult;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").XPathEvaluatorBase;

pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
    return try XPathEvaluatorBaseImpl.call_createNSResolver(instance, nodeResolver);
}

pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    return try XPathEvaluatorBaseImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
}

/// Extended attributes: [NewObject]
pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try XPathEvaluatorBaseImpl.call_createExpression(instance, expression, resolver);
}
