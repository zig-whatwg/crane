//! What the HTML parser's DOM adapter may free, and what it must leave alone.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tree-construction
//!
//! `DomTreeAdapter` creates a DOM node before the tree builder knows where the
//! node goes, so some nodes are never attached and nothing else will ever free
//! them - the adapter has to. The question these tests pin is which ones.
//!
//! A node the parser attached belongs to V8 from that moment: the wrapper cache
//! holds it and a weak callback can return its Instance handle to the slab at any
//! time, after which the address is whatever allocated next. So "attached" is a
//! fact the adapter must record when it happens, not a property it can re-derive
//! later by reading `parentNode` back off a pointer it is no longer sure of.

const std = @import("std");
const html = @import("html");
const html_core = @import("html_core");
const runtime = @import("runtime");

const interfaces = html.interfaces;
const impls = html.impls;
const DomTreeAdapter = html.parser_script_execution.DomTreeAdapter;
const TreeNode = html_core.parser.TreeNode;

const testing = std.testing;

/// One detached element TreeNode plus its DOM counterpart, created through the
/// adapter's own callback the way the tree builder does it.
fn createElement(
    adapter: *DomTreeAdapter,
    allocator: std.mem.Allocator,
    local_name: []const u8,
) !*TreeNode {
    const tree_node = try TreeNode.initElement(allocator, local_name, .html);
    try adapter.onNodeCreated(tree_node);
    return tree_node;
}

test "DomTreeAdapter.deinit - frees a node the parser never attached" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const document = try interfaces.Document.init(allocator, ctx);
    defer interfaces.Document.deinit(document);

    var adapter = DomTreeAdapter.init(allocator, ctx, document);

    const orphan_tn = try createElement(&adapter, allocator, "div");
    defer orphan_tn.deinit();
    const orphan = adapter.node_map.get(orphan_tn).?;

    adapter.deinit();

    // Never reached the tree, so never reachable from script, so nothing else
    // was ever going to free it.
    try testing.expect(impls.Node.getInternalState(orphan) == null);
}

test "DomTreeAdapter.deinit - leaves a node a script detached after the parser attached it" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const document = try interfaces.Document.init(allocator, ctx);
    defer interfaces.Document.deinit(document);

    var adapter = DomTreeAdapter.init(allocator, ctx, document);

    const parent_tn = try createElement(&adapter, allocator, "div");
    defer parent_tn.deinit();
    const child_tn = try createElement(&adapter, allocator, "span");
    defer child_tn.deinit();

    const parent = adapter.node_map.get(parent_tn).?;
    const child = adapter.node_map.get(child_tn).?;

    // The parser attached the child, then a script detached it again. Its parent
    // is null now - which is all the sweep used to look at.
    try adapter.onChildAppended(parent_tn, child_tn);
    try testing.expect(impls.Node.getParent(child) == parent);
    _ = try interfaces.Node.call_removeChild(parent, child);
    try testing.expect(impls.Node.getParent(child) == null);

    adapter.deinit();

    const survived = impls.Node.getInternalState(child) != null;
    if (survived) impls.Node.deinitNodeByType(child);
    try testing.expect(survived);
}

test "DomTreeAdapter.deinit - does not follow a slab slot the GC recycled" {
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const document = try interfaces.Document.init(allocator, ctx);
    defer interfaces.Document.deinit(document);

    var adapter = DomTreeAdapter.init(allocator, ctx, document);

    const parent_tn = try createElement(&adapter, allocator, "div");
    defer parent_tn.deinit();
    const child_tn = try createElement(&adapter, allocator, "span");
    defer child_tn.deinit();

    const parent = adapter.node_map.get(parent_tn).?;
    const child = adapter.node_map.get(child_tn).?;

    try adapter.onChildAppended(parent_tn, child_tn);
    _ = try interfaces.Node.call_removeChild(parent, child);

    // V8 collects the detached child: the finalizer hands its Instance handle back
    // to the slab and the adapter's map is left holding the address.
    runtime.gc.onObjectFreed(child);

    // The next Instance lands on that slot. Give it a context whose wrapper-cache
    // slot reads 0xAA.. - the shape freed or never-initialised memory has, and the
    // shape markInstanceCleanedUp panics on with "incorrect alignment", because
    // 0xAAAA_AAAA_AAAA_AAAA is not null but is not 8-aligned either.
    var dead_ctx_data = try runtime.ContextData.init(allocator, .{});
    defer dead_ctx_data.deinit();
    dead_ctx_data.setV8WrapperCacheStorage(@ptrFromInt(0xAAAA_AAAA_AAAA_AAAA));
    const recycled = try interfaces.Element.init(allocator, &dead_ctx_data);
    try testing.expectEqual(child, recycled);

    adapter.deinit();

    // Nothing may have followed the stale pointer into the recycled instance.
    const intact = impls.Node.getInternalState(recycled) != null;
    dead_ctx_data.clearV8WrapperCacheStorage();
    if (intact) impls.Node.deinitNodeByType(recycled);
    try testing.expect(intact);
}
