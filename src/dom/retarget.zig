//! DOM "retarget A against B" (DOM 4.8), for event dispatch's path and for
//! the IDL getters that report an object across shadow boundaries (an
//! event's `source`).
//!
//! It works on the nodes' NodeBase links: a root is the end of the
//! parent_node chain, a shadow root is a DocumentFragment whose instance is
//! a ShadowRoot, and its host is the ShadowRoot's host. Nothing walks
//! through the IDL getters (getRootNode, contains), which take the instance
//! bridge's lock at every step.
//!
//! Spec: https://dom.spec.whatwg.org/#retarget
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");

/// A shadow root chain is a handful deep; the bound only stops a corrupt
/// tree (a host inside its own shadow tree) from looping.
const max_shadow_depth: usize = 256;

/// `instance`'s node, or null when it is not a node.
pub fn nodeOf(instance: *runtime.Instance) ?*NodeBase {
    return instance_bridge.getNodeBase(instance);
}

/// `node`'s instance. Every node a script or the engine can reach has one.
pub fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const opaque_instance = node.owner_instance orelse return null;
    return @ptrCast(@alignCast(opaque_instance));
}

/// DOM: a node's root - the topmost inclusive ancestor.
pub fn rootOf(node: *NodeBase) *NodeBase {
    var current = node;
    while (current.parent_node) |parent| current = parent;
    return current;
}

/// Whether `node` is a shadow root.
pub fn isShadowRoot(node: *NodeBase) bool {
    if (node.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return false;
    const instance = instanceOf(node) orelse return false;
    return instance.vtable == &interfaces.ShadowRoot.vtable;
}

/// `shadow`'s host, as a node - `shadow` a shadow root. Null when the host
/// is gone (a host freed before its shadow root, dom.shadow_hosts).
pub fn hostOf(shadow: *NodeBase) ?*NodeBase {
    const instance = instanceOf(shadow) orelse return null;
    const host = interfaces.ShadowRoot.get_host(instance) catch return null;
    return nodeOf(host);
}

/// Whether `shadow`, a shadow root, is closed.
pub fn isClosed(shadow: *NodeBase) bool {
    const instance = instanceOf(shadow) orelse return false;
    const mode = interfaces.ShadowRoot.get_mode(instance) catch return false;
    return mode == ._closed_;
}

/// DOM: "An object A is a shadow-including inclusive ancestor of an object
/// B, if and only if A is B or A is a shadow-including ancestor of B", for
/// `root`, a root: it is B's root, or the root of the host of the shadow
/// root at the top of each tree B's tree hangs from.
pub fn isShadowIncludingInclusiveAncestorOf(root: *NodeBase, b: *NodeBase) bool {
    var current = rootOf(b);
    var depth: usize = 0;
    while (depth < max_shadow_depth) : (depth += 1) {
        if (current == root) return true;
        if (!isShadowRoot(current)) return false;
        const host = hostOf(current) orelse return false;
        current = rootOf(host);
    }
    return false;
}

/// DOM "retarget A against B" on nodes: `a` a node, `b` a node or null for an
/// object that is not one. Repeat: if A's root is not a shadow root, or B is
/// a node and A's root is a shadow-including inclusive ancestor of B, return
/// A; otherwise set A to A's root's host.
pub fn retargetNode(a_given: *NodeBase, b: ?*NodeBase) *NodeBase {
    var a = a_given;
    var depth: usize = 0;
    while (depth < max_shadow_depth) : (depth += 1) {
        // Step 1: "If one of the following is true - A's root is not a
        // shadow root; B is a node and A's root is a shadow-including
        // inclusive ancestor of B - then return A."
        const root = rootOf(a);
        if (!isShadowRoot(root)) return a;
        if (b) |target| {
            if (isShadowIncludingInclusiveAncestorOf(root, target)) return a;
        }
        // Step 2: "Set A to A's root's host."
        a = hostOf(root) orelse return a;
    }
    return a;
}

/// DOM "retarget A against B" on any objects, as event dispatch asks it:
/// null (no relatedTarget) retargets to null, and an A that is not a node
/// to itself (step 1's first case).
pub fn retargetAgainst(a: ?*runtime.Instance, b: *runtime.Instance) ?*runtime.Instance {
    const a_instance = a orelse return null;
    const a_node = nodeOf(a_instance) orelse return a_instance;
    const result = retargetNode(a_node, nodeOf(b));
    if (result == a_node) return a_instance;
    return instanceOf(result) orelse a_instance;
}

/// DOM "retarget A against B" for the IDL getters: `a_given` is an Element
/// (an event's source), so always a node; `b` is the object it is reported
/// to, or null.
///
/// Spec: https://dom.spec.whatwg.org/#retarget
pub fn retarget(a_given: *runtime.Instance, b: ?*runtime.Instance) !*runtime.Instance {
    const a_node = nodeOf(a_given) orelse return a_given;
    const b_node: ?*NodeBase = if (b) |target| nodeOf(target) else null;
    const result = retargetNode(a_node, b_node);
    if (result == a_node) return a_given;
    return instanceOf(result) orelse a_given;
}
