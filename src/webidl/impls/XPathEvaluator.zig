//! DOM XPathEvaluator. Compilation and evaluation belong to XPathExpression.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

pub const State = interfaces.XPathEvaluator.State;
pub const InternalState = struct {};
pub const ImplError = error{ SyntaxError, NamespaceError, TypeError, NotSupportedError, OutOfMemory };

pub fn call_constructor(instance: *runtime.Instance) !void {
    // The generated constructor made it (WebIDL 3.7.1 step 1.8): no steps.
    _ = instance;
}
