//! A node's layout (lane perf2, batch 5: Z7 and R6 part 2; tmp/plans/perf2b5-design.md).
//!
//! A div was seven storage blocks at d1ee79a9386: five arena requests (its
//! State and the EventTarget, Node, Element and HTMLElement InternalStates:
//! 1,288 bytes requested in 1,600 of power-of-two classes), a malloc'd
//! 208-byte NodeBase and its 32-byte slab slot. Blink, WebKit and Gecko lay
//! a node out by inheritance in ONE object, and Lightpanda's Factory makes
//! "1 large allocation for the total size" of the whole chain, reaching each
//! level at a comptime offset (`chainOffsetOf`). Crane now does the same:
//! every level whose InternalState is kept in its own State (runtime.OwnState)
//! keeps it there BY VALUE (`_embedded`, runtime.FlattenedState), the NodeBase
//! lives by value in Node's, and the arena hands the State out in an
//! exact-size class - so a node is its slab slot and one block.
//!
//! These pins assert that layout in the safe builds the tests and the WPT
//! runner use (Debug; ReleaseSafe lays out the same, see
//! perf2b4_node_base_size_test.zig). They name only generated States and src/dom
//! types - an embedded InternalState is reached as its State's field type,
//! never through its impl. Element's own state is perf3's (D1/D2): its size is
//! summed here, not pinned.

const std = @import("std");
const builtin = @import("builtin");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const NodeBase = dom.NodeBase;

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
    std.debug.print("{s:<28} {s:>6} {s:>6} {s:>6}  {s}\n", .{ "field", "offset", "size", "align", "type" });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("{s:<28} {d:>6} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @alignOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

/// The InternalState a level keeps by value in its own State (Z7), or void.
fn Embedded(comptime State: type) type {
    if (!@hasField(State, "_embedded")) return void;
    return @FieldType(State, "_embedded");
}

/// The bytes of every level's embedded InternalState in `State`, down its
/// `base` chain.
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

/// The bytes the arena's block for `State` holds beyond the State.
fn slack(comptime State: type) usize {
    return runtime.ArenaAllocator.heldBytes(@sizeOf(State), @alignOf(State)) - @sizeOf(State);
}

test "NodeBase keeps no child list: the sibling links are the children" {
    // 208 at d1ee79a9386: - 96 (child_nodes, an infra.List with four inline
    // slots; the sibling links are the children). The wrapper slot stays
    // inline (bound_v8_wrapper then, `wrapper: engine.NodeWrapperSlot` since
    // the wrapper redesign's P1): every wrapper the cache takes sets it
    // (wrapper_cache.zig, `set`), as Blink keeps the main world's wrapper on the object
    // (ScriptWrappable::wrapper_). The per-node allocator (16) is the next
    // step: an owner-less NodeBase (the test-only WithBase types) still needs
    // it, so it waits for those to carry their own (design 3.4, deferred).
    // Done in batch 6 (with last_child): 88 bytes, perf2b6_node_layout_test.zig;
    // 80 since the wrapper redesign's P6 (no holds chain).
    try expectSize(NodeBase, 80);
    try std.testing.expect(!@hasField(NodeBase, "child_nodes"));
    try std.testing.expect(@hasField(NodeBase, "wrapper"));
}

test "every OwnState level keeps its InternalState by value in its own State" {
    const levels = [_]type{
        interfaces.EventTarget.State,         interfaces.Node.State,              interfaces.CharacterData.State,
        interfaces.Text.State,                interfaces.Comment.State,           interfaces.DocumentFragment.State,
        interfaces.DocumentType.State,        interfaces.ShadowRoot.State,        interfaces.Element.State,
        interfaces.HTMLElement.State,         interfaces.HTMLAnchorElement.State, interfaces.HTMLAreaElement.State,
        interfaces.HTMLTemplateElement.State, interfaces.SVGScriptElement.State,  interfaces.HTMLSlotElement.State,
    };
    var missing: usize = 0;
    inline for (levels) |State| {
        if (Embedded(State) == void) {
            missing += 1;
            std.debug.print("{s} keeps no InternalState by value\n", .{@typeName(State)});
        }
    }
    try std.testing.expectEqual(@as(usize, 0), missing);
}

test "Node's embedded state is its NodeBase by value and the fields a node uses: 120 bytes" {
    const E = Embedded(interfaces.Node.State);
    if (E == void) {
        return error.NotEmbedded;
    } else {
        // allocator 16, node_base 8, node_type 2, owner_document 8 + its
        // generation 8, child_nodes_list 8, the NodeBase 112. Gone:
        // local_name (written, never read), namespace_uri (its one writer had
        // no caller), prefix and node_value (no writer) and is_connected
        // (NodeBase's is the one the DOM reads). The allocator copy stays
        // until every realm's creation allocator is its scope's (the V8
        // tests' realms are not). Batch 6: no allocator copy, NodeBase 88;
        // 80 since the wrapper redesign's P6 (no holds chain).
        try expectSize(E, 120);
        try std.testing.expect(@FieldType(E, "base") == NodeBase);
        inline for (.{ "local_name", "namespace_uri", "prefix", "node_value", "is_connected" }) |dead| {
            if (@hasField(E, dead)) {
                std.debug.print("Node's state still has `{s}`\n", .{dead});
                return error.DeadFieldKept;
            }
        }
    }
}

test "a div is ONE exact-size block: its pointers and every level's InternalState" {
    const S = interfaces.HTMLDivElement.State;
    // EventTarget, Node, Element and HTMLElement embed (HTMLDivElement's own
    // InternalState is empty); the generated part is batch 3's 104 bytes.
    if (embeddedBytes(S) == 0) {
        std.debug.print("HTMLDivElement.State: {d} bytes, nothing embedded\n", .{@sizeOf(S)});
        return error.NotEmbedded;
    }
    // Batch 6: no `_internal` pointers, the root's live word instead: 72.
    // The generated part's bytes are pinned in ONE place since lane cg1:
    // tests/dom/node_block_sizes_test.zig.
    try std.testing.expectEqual(@as(usize, 8), @alignOf(S));
    if (slack(S) >= 16) {
        std.debug.print("HTMLDivElement.State: {d} bytes in a {d}-byte block\n", .{ @sizeOf(S), @sizeOf(S) + slack(S) });
        return error.NotExactSize;
    }
}

test "a text node is ONE exact-size block: 16 bytes of pointers and every level's InternalState" {
    const S = interfaces.Text.State;
    if (embeddedBytes(S) == 0) {
        std.debug.print("Text.State: {d} bytes, nothing embedded\n", .{@sizeOf(S)});
        return error.NotEmbedded;
    }
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(S) - embeddedBytes(S));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(S));
    try std.testing.expect(slack(S) < 16);
}

test "a Document's state block is its exact size, not the next power of two" {
    // 2,168 bytes (lane nav2 batch 7) took a 4,096-byte block; the arena's
    // exact classes hold it in 2,176.
    const T = dom.document_state.InternalState;
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(T), @alignOf(T));
    if (held - @sizeOf(T) >= 16) {
        std.debug.print("Document's state: {d} bytes in a {d}-byte block\n", .{ @sizeOf(T), held });
        return error.NotExactSize;
    }
}
