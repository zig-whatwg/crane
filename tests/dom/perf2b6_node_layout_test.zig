//! A node's layout, part 3 (lane perf2, batch 6): the bytes a node still spent
//! on copies and pointers that say what the object already knows.
//!
//! - The allocator copies (16 bytes each: NodeBase, Node, EventTarget,
//!   CharacterData, Comment): a node's creation allocator IS its Browser's -
//!   asserted where a node and an EventTarget are made - so what it allocates
//!   comes from `runtime.allocatorOf(instance)`, found from its address
//!   (docs/lessons/architecture-a-nodes-creation-allocator-is-its-browsers-only-inside-a-browser.md).
//!   A NodeBase no Instance owns (the tests' fixtures and WithBase types) names
//!   its allocator in its owner word instead.
//! - The `_internal` pointer of every level whose state is kept by value or is
//!   empty (8 bytes a level, five on a div): one live word at the chain's root
//!   instead (tests/runtime/perf2b6_live_flags_test.zig).
//! - `last_child`: the first child's previous link holds it (Gecko's
//!   nsIContent::mPreviousOrLastSibling; nsINode::GetLastChild reads
//!   mFirstChild->mPreviousOrLastSibling, GetPreviousSibling hides the wrap).
//! - EventTarget's LazyEntry (24 bytes): only a lazily made entry (an
//!   EventTarget whose impl never chains EventTarget's init) has a realm and a
//!   generation; it is that entry's block, not every target's state.
//!
//! They name generated States and src/dom types only (an embedded state is
//! its State's `_embedded` field type), and compile at the base, where they
//! fail.

const std = @import("std");
const builtin = @import("builtin");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const NodeBase = dom.NodeBase;

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<28} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

fn expectNoField(comptime T: type, comptime names: anytype) !void {
    var kept: usize = 0;
    inline for (names) |name| {
        if (@hasField(T, name)) {
            std.debug.print("{s} still has `{s}`\n", .{ @typeName(T), name });
            kept += 1;
        }
    }
    if (kept != 0) return error.FieldKept;
}

fn Embedded(comptime State: type) type {
    if (!@hasField(State, "_embedded")) return void;
    return @FieldType(State, "_embedded");
}

/// The bytes of every level's embedded state in `State`, down its `base` chain.
fn embeddedBytes(comptime State: type) usize {
    return comptime sum: {
        var total: usize = 0;
        var Cur: type = State;
        while (true) {
            total += @sizeOf(Embedded(Cur));
            if (!@hasField(Cur, "base") or @FieldType(Cur, "base") == void) break;
            Cur = @FieldType(Cur, "base");
        }
        break :sum total;
    };
}

fn slack(comptime State: type) usize {
    return runtime.ArenaAllocator.heldBytes(@sizeOf(State), @alignOf(State)) - @sizeOf(State);
}

fn Own(comptime State: type) type {
    return @FieldType(State, "own");
}

test "NodeBase keeps no allocator copy, no last_child, no holds chain" {
    // 112 at main f7853e77e9a: - 16 (the allocator: an owned node's is its
    // Browser's, an owner-less one's is named by its owner word) - 8
    // (last_child: the first child's previous link). 88 until the wrapper
    // redesign's P6 (lane wr1 batch 6): - 8 (`holds`, node_holds' chain -
    // holders trace their nodes from their wrappers instead, design 3.4).
    // Its size is pinned in node_block_sizes_test.zig (one place: lane nm1).
    try expectNoField(NodeBase, .{ "allocator", "last_child", "child_nodes", "holds" });
}

test "Node's embedded state keeps no allocator copy" {
    const E = Embedded(interfaces.Node.State);
    try std.testing.expect(E != void);
    try expectNoField(E, .{"allocator"});
}

test "EventTarget's embedded state keeps no allocator and no lazy entry: 8 bytes" {
    const E = Embedded(interfaces.EventTarget.State);
    try std.testing.expect(E != void);
    try expectNoField(E, .{ "allocator", "lazy" });
    // listener list 8, handler map 8, listeners_watched 1 (padded to 8): 32
    // at batch 6, less the current event batch 7 moved to Window's state:
    // 24; lane lis1 made the list, the handlers and the flag one block, made
    // with the first listener: one pointer.
    try expectSize(E, 8);
}

test "CharacterData's and Comment's embedded states keep no allocator copy" {
    const data = Embedded(interfaces.CharacterData.State);
    try std.testing.expect(data != void);
    try expectNoField(data, .{"allocator"});
    const comment = Embedded(interfaces.Comment.State);
    try expectNoField(comment, .{"allocator"});
    try std.testing.expectEqual(@as(usize, 0), @sizeOf(comment));
}

test "no embedded or empty level keeps an `_internal` pointer; a separate block's level does" {
    inline for (.{
        interfaces.EventTarget.State, interfaces.Node.State,           interfaces.CharacterData.State,
        interfaces.Text.State,        interfaces.Comment.State,        interfaces.Element.State,
        interfaces.HTMLElement.State, interfaces.HTMLDivElement.State, interfaces.HTMLSpanElement.State,
    }) |State| try expectNoField(Own(State), .{"_internal"});
    // Document keeps its state in a block of its own (an InstanceRegistry).
    try std.testing.expect(@hasField(Own(interfaces.Document.State), "_internal"));
}

// A div's generated part (72 bytes after this batch) is pinned in ONE place since lane cg1:
// tests/dom/node_block_sizes_test.zig.

test "a text node's State spends 16 bytes on pointers and the live word, in an exact-size block" {
    const S = interfaces.Text.State;
    // 40 at main: 4 `_internal` pointers + cached_childNodes.
    if (@sizeOf(S) - embeddedBytes(S) != 16) {
        printLayout(S);
        std.debug.print("Text.State: {d} bytes, {d} embedded\n", .{ @sizeOf(S), embeddedBytes(S) });
        return error.SizePinMoved;
    }
    try std.testing.expect(slack(S) < 16);
}
