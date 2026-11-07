//! NodeBase's layout (lane perf2, batch 4: R6 part 1; tmp/plans/perf2b4-design.md).
//!
//! Every node of every document carries one NodeBase, so each byte of it is
//! paid once per node. Measured on main 6b853131403 it was 472 bytes, 256 of
//! them an `infra.List(RegisteredObserver)` with four inline registrations
//! that almost no node ever uses. The engines keep a node's mutation observer
//! registrations - and its other cold fields - in rare data made on first use
//! (WebKit NodeRareData / NodeMutationObserverData, Blink NodeRareData, Gecko
//! nsINode::nsSlots); Crane's NodeRareData is allocated once and never moved
//! (Blink 601c5205e1d5 fixed a corruption from rare data that reallocated).
//!
//! These pins assert Crane's own layout, in the safe builds the tests and the
//! WPT runner's Crane modules use (Debug; ReleaseSafe lays out the same: the
//! only mode-dependent sizes, std's SafetyLock and a bare union's tag, follow
//! `std.debug.runtime_safety`, on in both). The std parts they count are named
//! and fixed below (docs/lessons/testing-a-std-safety-field-moves-size-pins-in-safe-builds.md):
//! a toolchain that grows one moves the pin, and the field that grew is
//! printed. What a node costs in an allocator's size classes is gc_bench's
//! measurement, not this test's.

const std = @import("std");
const builtin = @import("builtin");
const dom = @import("dom");
const infra = @import("infra");

const NodeBase = dom.NodeBase;
const NodeRareData = dom.node_base.NodeRareData;
const ObserverRegistration = dom.node_base.ObserverRegistration;
const RegisteredObserver = dom.node_base.RegisteredObserverType;

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
    std.debug.print("{s:<24} {s:>6} {s:>6} {s:>6}  {s}\n", .{ "field", "offset", "size", "align", "type" });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("{s:<24} {d:>6} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @alignOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

test "the std parts NodeBase's pins count are the sizes they were pinned with" {
    // child_nodes (removed by R6 part 2) and the observer list's head and link.
    try std.testing.expectEqual(@as(usize, 96), @sizeOf(infra.List(*NodeBase)));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(std.DoublyLinkedList));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(std.DoublyLinkedList.Node));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(std.mem.Allocator));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(RegisteredObserver));
}

test "NodeBase is 208 bytes: the registered observer list and the node name live in rare data" {
    // 472 at 6b853131403: - 256 (the inline observer list) - 16 (node_name)
    // + 8 (the rare data pointer), and the tail word keeps its 2 free bytes.
    try expectSize(NodeBase, 208);
    try std.testing.expect(!@hasField(NodeBase, "registered_observers"));
    try std.testing.expect(!@hasField(NodeBase, "node_name"));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(NodeBase, "rare")));
}

test "NodeRareData is 40 bytes and a registration record 64" {
    // The list head (16), the node name (16) and whether it was allocated.
    try expectSize(NodeRareData, 40);
    // The link (16) and the registered observer (48).
    try expectSize(ObserverRegistration, 64);
}
