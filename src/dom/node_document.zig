//! DOM § 4.4 "node document", as the hook every node creator reaches.
//!
//! Every node has a node document, set when the node is created and changed
//! only by adopt. It lives in the Node impl's state, and the code that creates
//! nodes - Document's factory methods, the HTML parsers and the DOM tree
//! adapter, cloning, DOMImplementation, the V8 context manager - is other
//! impls or engine code, none of which may reach into the Node impl. This
//! module is only the seam between them, the same shape as
//! `abort_algorithms.zig`.
//!
//! The Node impl installs the implementation in its installHooks, which runs for
//! every node before anything can hold that node to set its document.
//!
//! lint-impls: hook for Node
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const engine = @import("engine");
const instance_bridge = @import("instance_bridge.zig");
const refcount_audit = @import("refcount_audit.zig");

/// Assigning the document establishes template contents, which can allocate.
pub const Error = error{ InvalidStateError, OutOfMemory };

/// The member through which a node keeps its node document: one edge from
/// the node's wrapper - to its parent's wrapper while it has a parent, to its
/// document's while it is a root (engine.traceChild's slot namespace) - so a
/// node script can reach keeps its document, and through the document's own
/// wrapper its tree, for as long as the node lives. Blink: `Node::Trace`
/// visits `parent_or_shadow_host_node_` and `tree_scope_` (core/dom/node.cc),
/// whose `TreeScope::Trace` visits its document; WebKit counts the node on its
/// document instead (`Document::incrementReferencingNodeCount` in
/// `Node::Node`).
///
/// The engine adapter's node tracing keeps the slot: the document when it
/// wraps a root (the host has no step at that moment: a factory method sets
/// the node document before the binding wraps its result, and a holder's
/// rescue wraps a root inside the adapter), the parent on insertion, the
/// document again on removal. The Node impl redraws it when adopt changes a
/// wrapped root's document, replacing the old one, so an adopted node keeps
/// its new document and lets the old one go. A node no wrapper reaches draws
/// nothing: it is as safe as its tree, whose root's wrapper - script's, or a
/// holder's rescue (node_holds.zig) - holds the document, or which is its
/// document's own tree.
pub const traced_slot: engine.TracedSlot = .{ .name = "tree parent or node document" };

/// What the Node impl supplies.
pub const Implementation = struct {
    set: *const fn (node: *runtime.Instance, document: ?*runtime.Instance) Error!void,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Node's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Set `node`'s node document to `document`.
pub fn set(node: *runtime.Instance, document: ?*runtime.Instance) Error!void {
    // Refcount step 6: a node step 7 would have freed is given a document.
    if (refcount_audit.on()) if (instance_bridge.getNodeBaseUnaudited(node)) |base| refcount_audit.checkRead(base, .node_document, @returnAddress());
    const impl = implementation orelse return error.InvalidStateError;
    return impl.set(node, document);
}

test "set without an installed implementation reports InvalidStateError" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation the call does not reach it.
    var node: runtime.Instance = undefined;
    try std.testing.expectError(error.InvalidStateError, set(&node, null));
}

test "set forwards to the installed implementation" {
    const std = @import("std");
    const saved = implementation;
    defer implementation = saved;

    const Fake = struct {
        var seen_node: ?*runtime.Instance = null;
        var seen_document: ?*runtime.Instance = null;
        fn set(node: *runtime.Instance, document: ?*runtime.Instance) Error!void {
            seen_node = node;
            seen_document = document;
        }
    };
    install(.{ .set = &Fake.set });

    var node: runtime.Instance = undefined;
    var document: runtime.Instance = undefined;
    try set(&node, &document);
    try std.testing.expect(Fake.seen_node == &node);
    try std.testing.expect(Fake.seen_document == &document);
}
