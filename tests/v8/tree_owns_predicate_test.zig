//! `wrapper_cache.treeOwns` - is this instance a node its tree still holds?
//!
//! It gates a free: `WrapperCache.deinit` frees every instance its realm
//! wrapped EXCEPT the ones this answers true for, which only their tree's
//! teardown may free. It is also the node arm of `engineOwns`, which the weak
//! callback asks before freeing anything.
//!
//! Wrong towards "false", a child is freed on its own while its parent's child
//! list still points at it: in hash order a child went before its detached
//! root, and the root's teardown walk read the freed NodeBase (a SEGV in
//! `instance_bridge.getInstance`, 3 crashes in 7 runs of an 87-file WPT
//! prefix). Wrong towards "true", an instance waits for the slab teardown.
//! So the tests pin both answers, and the DEFAULT: anything that is not a node
//! answers false and is freed as it always was.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

const treeOwns = v8.wrapper_cache_mod.treeOwns;

/// The test's isolate, context and realm: its own agent's (test_agent), ended
/// with the test.
var test_realm: ?runtime.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_realm = null;
}

fn realm() !runtime.Context {
    _ = try test_agent.open(.{ .realm_allocator = std.heap.page_allocator });
    if (test_realm == null) {
        const context = test_agent.context.?;
        const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        test_realm = r;
    }
    return test_realm.?;
}

test "treeOwns: a node with a parent is its tree's; its detached root is not" {
    defer test_agent.close();
    const r = try realm();
    const allocator = testing.allocator;

    const fragment = try interfaces.DocumentFragment.init(allocator, r);
    // Freed whole, as a native creator frees a root it never inserted
    // (dom.node_creation.destroyUninserted): its teardown walks its subtree
    // and frees the child too. interfaces.DocumentFragment.deinit alone is
    // its destructor, and left its slot in the slab (docs/lessons/
    // architecture-an-interfaces-deinit-is-a-destructor-not-a-free.md).
    defer dom.node_creation.destroyUninserted(fragment);
    const child = try interfaces.Text.init(allocator, r);

    // Both are roots before the append: neither is held by a tree.
    try testing.expect(!treeOwns(fragment));
    try testing.expect(!treeOwns(child));

    _ = try interfaces.Node.call_appendChild(fragment, child);

    try testing.expect(treeOwns(child));
    // The root of a detached tree is still nobody's but its wrapper's.
    try testing.expect(!treeOwns(fragment));
}

test "treeOwns: a node removed from its parent is a root again" {
    defer test_agent.close();
    const r = try realm();
    const allocator = testing.allocator;

    const fragment = try interfaces.DocumentFragment.init(allocator, r);
    defer dom.node_creation.destroyUninserted(fragment);
    const child = try interfaces.Text.init(allocator, r);
    // A root again once removed: its own free.
    defer dom.node_creation.destroyUninserted(child);

    _ = try interfaces.Node.call_appendChild(fragment, child);
    try testing.expect(treeOwns(child));
    _ = try interfaces.Node.call_removeChild(fragment, child);
    try testing.expect(!treeOwns(child));
}

test "treeOwns: the default - anything that is not a node answers false" {
    defer test_agent.close();
    const r = try realm();
    const headers = try interfaces.Headers.init(testing.allocator, r);
    defer runtime.Instance.deinit(headers);
    try testing.expect(!treeOwns(headers));
}
