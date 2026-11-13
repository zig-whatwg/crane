//! NodeBase's wrapper slot (the wrapper redesign's P1,
//! tmp/redesign/wrapper-redesign-design.md section 7): the field that was
//! `bound_v8_wrapper: ?*anyopaque` is the engine's own type,
//! `wrapper: engine.NodeWrapperSlot`, which starts `.empty`; the host asks it
//! only `isEmpty()` (dom.mutation's opaque-root tests, orphanRemoved, Node's
//! teardown), and the adapter reaches it only through runtime.lifetime's
//! `slotOf` - never by naming the field. NodeBase is 80 bytes since the
//! redesign's P6 (tests/dom/refcount_test.zig).

const std = @import("std");
const dom = @import("dom");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NodeBase = dom.NodeBase;

test "NodeBase's wrapper is the engine's slot, and nothing else names the old alias" {
    try std.testing.expect(@FieldType(NodeBase, "wrapper") == engine.NodeWrapperSlot);
    try std.testing.expect(!@hasField(NodeBase, "bound_v8_wrapper"));
    try std.testing.expectEqual(@as(usize, 80), @sizeOf(NodeBase));
}

test "a new node's slot is empty" {
    const node: NodeBase = .{ .node_type = NodeBase.ELEMENT_NODE };
    try std.testing.expect(node.wrapper.isEmpty());
}

test "runtime.lifetime.slotOf answers a node's own slot (dom.refcount installs it)" {
    // The process start installs it (refcount.install, from Document's and
    // Node's installHooks): the sanctioned test start runs it.
    interfaces.process_hooks.startHooksForTest();
    var node: NodeBase = .{ .node_type = NodeBase.ELEMENT_NODE };
    try std.testing.expect(runtime.lifetime.slotOf(&node) == &node.wrapper);
    try std.testing.expect(runtime.lifetime.slotOf(&node).isEmpty());
}
