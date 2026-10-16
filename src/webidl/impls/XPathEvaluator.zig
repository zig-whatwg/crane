//! DOM XPathEvaluator. Compilation and evaluation belong to XPathExpression.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.XPathEvaluator.State;
pub const InternalState = struct {};
pub const ImplError = error{ SyntaxError, NamespaceError, TypeError, NotSupportedError, OutOfMemory };

pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    return interfaces.XPathEvaluator.init(ctx.allocator, ctx);
}

/// Operation: createNSResolver
pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // DOM §8.3: return nodeResolver (the legacy method is an identity).
    return nodeResolver;
}

/// Operation: evaluate
pub fn call_evaluate(instance: *runtime.Instance, expression: runtime.DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    // DOM Level 3 XPath §1.4: compile, evaluate and convert to the requested type.
    const compiled = try interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
    // This private, unwrapped temporary owns both its grammar and instance storage.
    defer runtime.Instance.deinit(compiled);
    return interfaces.XPathExpression.call_evaluate(compiled, contextNode, @"type", result);
}

/// Operation: createExpression
pub fn call_createExpression(instance: *runtime.Instance, expression: runtime.DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
    // DOM XPath: compile once; namespace callbacks run during construction.
    return interfaces.XPathExpression.initWith(instance.ctx.allocator, instance.ctx, .{
        .expression = expression,
        .resolver = resolver,
    });
}
