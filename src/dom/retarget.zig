//! DOM retargeting for source getters. No event-dispatch integration.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

// ============================================================================
// DOM "retarget"
// ============================================================================

/// DOM "retarget A against B": repeat - if A is not a node, or A's root is
/// not a shadow root, or B is a node and A's root is a shadow-including
/// inclusive ancestor of B, return A; otherwise set A to A's root's host.
/// `a` is an Element here (source's type), so always a node.
///
/// Spec: https://dom.spec.whatwg.org/#retarget
pub fn retarget(a_given: *runtime.Instance, b: ?*runtime.Instance) !*runtime.Instance {
    var a = a_given;
    // A shadow root chain is a handful deep; the bound only stops a corrupt
    // tree from looping here.
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const root = try rootOf(a);
        const host = shadowHostOf(root) orelse return a;
        if (b) |target| {
            if (isNode(target) and try isShadowIncludingInclusiveAncestor(root, target)) return a;
        }
        a = host;
    }
    return a;
}

fn isNode(target: *runtime.Instance) bool {
    return target.stateAs(interfaces.Node.State) != null;
}

fn rootOf(node: *runtime.Instance) !*runtime.Instance {
    return interfaces.Node.call_getRootNode(node, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed());
}

/// `root`'s host when it is a shadow root; null for any other root.
fn shadowHostOf(root: *runtime.Instance) ?*runtime.Instance {
    if (root.stateAs(interfaces.ShadowRoot.State) == null) return null;
    return interfaces.ShadowRoot.get_host(root) catch null;
}

/// DOM: "An object A is a shadow-including inclusive ancestor of an object B,
/// if and only if A is B or A is a shadow-including ancestor of B" - an
/// inclusive ancestor of B, or of the host of each shadow root B's tree hangs
/// from.
fn isShadowIncludingInclusiveAncestor(ancestor: *runtime.Instance, node: *runtime.Instance) !bool {
    var current = node;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        if (try interfaces.Node.call_contains(ancestor, current)) return true;
        current = shadowHostOf(try rootOf(current)) orelse return false;
    }
    return false;
}
