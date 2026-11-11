//! The generated State of every Node-family interface (lane perf2, batch 3: Z1).
//!
//! An IDL attribute is an accessor, not a field. Every engine keeps what a
//! node's attributes reflect in the node itself: Blink's HTMLDivElement is
//! 80 B, Lightpanda's whole EventTarget-to-HTMLDivElement chain 74 B
//! (tmp/research/dom-performance-report.md 3.1). Crane's Node-family impls do
//! the same - their values live in each impl's InternalState, in ElementData
//! and in NodeBase - so the generated State needs only `_internal` (the impl's
//! state) and the `cached_*` [SameObject] caches the generated getters fill.
//! Every other own field of a Node-family State is a slot nobody writes and
//! nobody reads, and every node pays for all of them: zeroed at every create
//! and held for the node's life.
//!
//! These tests pin that every Node-family State keeps only those fields, and
//! pin the sizes of the hottest ones, so a State cannot regrow silently. When
//! one fails it prints every Node-family State with its size and the state
//! arena's block for it (runtime.ArenaAllocator.heldBytes).

const std = @import("std");
const interfaces = @import("interfaces");
const runtime = @import("runtime");

/// Whether `I` is Node or inherits from it.
fn isNodeFamily(comptime I: type) bool {
    if (I == interfaces.Node) return true;
    if (!@hasDecl(I.Meta, "ParentInterface")) return false;
    return isNodeFamily(I.Meta.ParentInterface);
}

/// Every generated interface that is Node or inherits from it.
const family: []const type = blk: {
    @setEvalBranchQuota(1_000_000);
    var list: []const type = &.{};
    for (@typeInfo(interfaces).@"struct".decl_names) |name| {
        const D = @field(interfaces, name);
        if (@TypeOf(D) != type) continue;
        if (@typeInfo(D) != .@"struct") continue;
        if (!@hasDecl(D, "Meta") or !@hasDecl(D, "State")) continue;
        if (D.Meta.is_mixin) continue;
        if (isNodeFamily(D)) list = list ++ .{D};
    }
    break :blk list;
};

/// Whether an own field is one a Node-family State keeps: the impl's state or
/// a [SameObject] cache.
fn kept(comptime field_name: []const u8) bool {
    return std.mem.eql(u8, field_name, "_internal") or std.mem.startsWith(u8, field_name, "cached_");
}

/// The own fields of `State` that are neither `_internal` nor a cache.
fn droppable(comptime State: type) usize {
    return comptime count: {
        var n: usize = 0;
        for (@typeInfo(@FieldType(State, "own")).@"struct".field_names) |field_name| {
            if (!kept(field_name)) n += 1;
        }
        break :count n;
    };
}

fn printTable() void {
    @setEvalBranchQuota(1_000_000);
    var total_bytes: usize = 0;
    var total_held: usize = 0;
    std.debug.print("\n{s:<40} {s:>8} {s:>8} {s:>10}\n", .{ "Node-family State", "bytes", "block", "own fields" });
    inline for (family) |I| {
        const size = @sizeOf(I.State);
        const held = runtime.ArenaAllocator.heldBytes(size, @alignOf(I.State));
        total_bytes += size;
        total_held += held;
        std.debug.print("{s:<40} {d:>8} {d:>8} {d:>10}\n", .{ I.Meta.name, size, held, comptime droppable(I.State) });
    }
    std.debug.print("{d} Node-family States: {d} bytes, {d} in blocks\n", .{ family.len, total_bytes, total_held });
}

test "the Node family is found: Node, its descendants, and nothing else" {
    try std.testing.expect(family.len >= 150);
    comptime var has_div = false;
    comptime var has_text = false;
    comptime var has_event = false;
    inline for (family) |I| {
        if (I == interfaces.HTMLDivElement) has_div = true;
        if (I == interfaces.Text) has_text = true;
        if (I == interfaces.Event) has_event = true;
    }
    try std.testing.expect(has_div);
    try std.testing.expect(has_text);
    try std.testing.expect(!has_event);
}

test "every Node-family State keeps only _internal and the cached_* [SameObject] caches" {
    @setEvalBranchQuota(1_000_000);
    var offenders: usize = 0;
    inline for (family) |I| {
        if (comptime droppable(I.State) != 0) offenders += 1;
        if (@sizeOf(@FieldType(I.State, "mixins")) != 0) offenders += 1;
    }
    if (offenders != 0) {
        std.debug.print("{d} Node-family States keep IDL attribute fields:", .{offenders});
        printTable();
    }
    try std.testing.expectEqual(@as(usize, 0), offenders);
}

/// The bytes of the InternalStates `State` keeps by value down its `base`
/// chain (lane perf2 batch 5, Z7: runtime.FlattenedState's `_embedded`).
fn embeddedBytes(comptime State: type) usize {
    return comptime sum: {
        var total: usize = 0;
        var Cur: type = State;
        while (true) {
            if (@hasField(Cur, "_embedded")) total += @sizeOf(@FieldType(Cur, "_embedded"));
            if (!@hasField(Cur, "base") or @FieldType(Cur, "base") == void) break;
            Cur = @FieldType(Cur, "base");
        }
        break :sum total;
    };
}

test "the hottest Node-family States are pinned to their generated bytes" {
    const Pin = struct { name: []const u8, State: type, bytes: usize };
    // EventTarget 8 (_internal) + Node 16 (_internal, cached_childNodes) +
    // Element 40 (_internal and 4 caches) + HTMLElement 32 (_internal and 3
    // caches) + HTMLDivElement 8 = 104 bytes. Since lane perf2 batch 5 (Z7)
    // the State also keeps its levels' InternalStates by value, counted
    // apart here; the whole block's size and class are
    // perf2b5_node_layout_test.zig's.
    // Lane perf2 batch 6: a level kept by value or empty keeps no `_internal`
    // pointer - the root's live word (4 bytes, padded to 8) says which
    // levels are made - so 8 + the caches: 72, 72, 48, 16, 16, 24. Lane cg1
    // moved the div's, HTMLElement's and Element's to ONE place
    // (tests/dom/node_block_sizes_test.zig), where N1 made them 16.
    const pins = [_]Pin{
        .{ .name = "Text", .State = interfaces.Text.State, .bytes = 16 },
        .{ .name = "Comment", .State = interfaces.Comment.State, .bytes = 16 },
        .{ .name = "DocumentFragment", .State = interfaces.DocumentFragment.State, .bytes = 24 },
    };
    var wrong: usize = 0;
    inline for (pins) |p| {
        const size = @sizeOf(p.State) - embeddedBytes(p.State);
        if (size != p.bytes) {
            wrong += 1;
            std.debug.print("{s}.State: {d} generated bytes (+ {d} embedded); pinned {d}\n", .{ p.name, size, embeddedBytes(p.State), p.bytes });
        }
    }
    if (wrong != 0) printTable();
    try std.testing.expectEqual(@as(usize, 0), wrong);
}
