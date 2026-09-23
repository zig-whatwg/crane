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
//! The Node impl installs the implementation in its `init`, which runs for
//! every node before anything can hold that node to set its document.
//!
//! lint-impls: hook for Node

const runtime = @import("runtime");

/// The only way setting a node document can fail: the node has no Node state,
/// which is also what a missing implementation means - no node has been made.
pub const Error = error{InvalidStateError};

/// What the Node impl supplies.
pub const Implementation = struct {
    set: *const fn (node: *runtime.Instance, document: ?*runtime.Instance) Error!void,
};

/// Per thread: a node is created, and given its document, on one thread.
threadlocal var implementation: ?Implementation = null;

/// Called by the Node impl. Idempotent: every call installs the same function.
pub fn install(impl: Implementation) void {
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
