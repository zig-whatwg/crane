//! engine.NodeWrapperSlot - the engine's inline per-node storage for a node's
//! one wrapper per agent (tmp/redesign/wrapper-redesign-design.md section
//! 3.3; phase P1). The host owns the bytes, inside NodeBase; the adapter owns
//! what is in them; the host only ever asks `isEmpty()` ("is this node
//! wrapped"), on a slot that starts `.empty`.
//!
//! This file is compiled against every adapter with no engine behind it: the
//! runtime tier's test adapter (tests/runtime), and the JavaScriptCore and
//! QuickJS protocol roots through tests/runtime/engine_protocol_test.zig. The
//! V8 adapter's slot is pinned in tests/v8/wr1_node_wrapper_slot_test.zig.
//! Each adapter chooses its slot's layout, and every one of them is 8 bytes
//! with 8-byte alignment: NodeBase is laid out once for every engine (its
//! 88-byte pin, tests/dom/refcount_test.zig).

const std = @import("std");
const engine = @import("engine");

test "the slot is 8 bytes, 8-aligned, on this adapter" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(engine.NodeWrapperSlot));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(engine.NodeWrapperSlot));
}

test "a slot starts empty, and the host's one question answers so" {
    const slot: engine.NodeWrapperSlot = .empty;
    try std.testing.expect(slot.isEmpty());
    // As a field's default, the way NodeBase declares it.
    const Holder = struct { wrapper: engine.NodeWrapperSlot = .empty };
    const holder: Holder = .{};
    try std.testing.expect(holder.wrapper.isEmpty());
}
