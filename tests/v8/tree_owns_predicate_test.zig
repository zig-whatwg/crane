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
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");

const treeOwns = v8.wrapper_cache_mod.treeOwns;

/// One isolate, context and realm for the whole file; V8 is never torn down
/// here (see engine_realm_operations_test.zig).
var realm_once: ?runtime.Context = null;

/// The process-wide pools Instances come from, made once for the file and,
/// like V8 here, never torn down.
var pools_ready = false;

fn ensurePools() void {
    if (pools_ready) return;
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

fn realm() !runtime.Context {
    ensurePools();
    if (realm_once) |r| return r;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    // Already initialized is fine: the manager is per thread, not per test.
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    realm_once = r;
    return r;
}

test "treeOwns: a node with a parent is its tree's; its detached root is not" {
    const r = try realm();
    const allocator = testing.allocator;

    const fragment = try interfaces.DocumentFragment.init(allocator, r);
    // The fragment's teardown walks its subtree and frees the child too.
    defer interfaces.DocumentFragment.deinit(fragment);
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
    const r = try realm();
    const allocator = testing.allocator;

    const fragment = try interfaces.DocumentFragment.init(allocator, r);
    defer interfaces.DocumentFragment.deinit(fragment);
    const child = try interfaces.Text.init(allocator, r);
    defer interfaces.Text.deinit(child);

    _ = try interfaces.Node.call_appendChild(fragment, child);
    try testing.expect(treeOwns(child));
    _ = try interfaces.Node.call_removeChild(fragment, child);
    try testing.expect(!treeOwns(child));
}

test "treeOwns: the default - anything that is not a node answers false" {
    const r = try realm();
    const headers = try interfaces.Headers.init(testing.allocator, r);
    defer interfaces.Headers.deinit(headers);
    try testing.expect(!treeOwns(headers));
}
