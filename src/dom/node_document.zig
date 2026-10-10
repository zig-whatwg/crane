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

/// Assigning the document establishes template contents, which can allocate.
pub const Error = error{ InvalidStateError, OutOfMemory };

/// The member a node keeps its node document in: an edge from the node's
/// wrapper to its document's (engine.traceChild's slot namespace), so a node
/// script can reach keeps its document - and through the document's own
/// wrapper, its tree - for as long as the node lives. Blink: `Node::Trace`
/// visits `tree_scope_` (core/dom/node.cc), whose `TreeScope::Trace` visits
/// its document; WebKit counts the node on its document instead
/// (`Document::incrementReferencingNodeCount` in `Node::Node`).
///
/// Drawn twice, under this one key: by the engine adapter when it makes a
/// node's wrapper (node tracing - the host has no step at that moment: a
/// factory method sets the node document before the binding wraps its
/// result), and by the Node impl when a wrapped node's document changes
/// (adopt), which replaces the edge, so an adopted node keeps its new
/// document and lets the old one go. A node no wrapper reaches draws none: it
/// is as safe as its tree, whose root's wrapper - script's, or a holder's
/// rescue (node_holds.zig) - carries the same edge, or which is its
/// document's own tree.
pub const traced_slot: engine.TracedSlot = .{ .name = "node document" };

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
