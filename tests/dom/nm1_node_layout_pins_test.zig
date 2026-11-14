//! The node layout's permanent pins (lane nm1 batch 1: the layout batch of
//! tmp/redesign/node-memory-plan-v2.md, section 6 item 4 - its X4, I1, I3).
//!
//! A node is ONE State block: the generated State, every level's
//! InternalState by value and the NodeBase in Node's (runtime.FlattenedState).
//! Code computes into that block: src/dom finds a node's NodeBase from the
//! block's address (`dom.node_base.offset_in_state`), `Instance.stateAs`
//! reads an ancestor's State at the block's first byte, and the planned
//! phases compute more (the Instance folded into the block, 32-bit links).
//! Zig promises none of the facts those computations rest on: an auto-layout
//! struct is sorted by alignment (unstably past 24 fields), a nested level
//! moves when anything in it is more aligned than its `base`, and a single
//! 16-aligned field in ANY node interface's impl would move its State's
//! levels with no error and no crash (the deep review's Z2, MEASURED). So
//! they are pinned here, over EVERY node interface, at comptime cost:
//!
//! - every node State is 8-aligned, never more;
//! - every level's `base` is at offset 0, down the whole chain, so each
//!   ancestor's State starts at the block's first byte;
//! - NodeBase is at ONE offset in every node State, the one src/dom uses;
//! - NodeBase is an `extern struct` - its order is its declaration's - with
//!   every field's offset pinned, no padding, and the fields a tree walk
//!   reads (parent, first child, next sibling, the node type) in its first
//!   32 bytes, one cache line's half (the research review's R5, MEASURED
//!   1.1-1.8x on cold scattered walks on x86-64). The block-level guarantee -
//!   that those 32 bytes never straddle a line - needs the node pool's
//!   class-stable spans (plan phase H2): the state arena's 16-byte classes
//!   start a block at any multiple of 16.
//!
//! A node State's TOTAL is pinned in one place, tests/dom/
//! node_block_sizes_test.zig; this file pins the structure. It names
//! generated States and src/dom types only (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const NodeBase = dom.NodeBase;

/// Where NodeBase sits in every node's State block.
const pinned_node_base_offset: usize = 24;

fn isNodeState(comptime S: type) bool {
    comptime {
        var Cur = S;
        while (true) {
            if (Cur == interfaces.Node.State) return true;
            if (@typeInfo(Cur) != .@"struct" or !@hasField(Cur, "base")) return false;
            const B = @FieldType(Cur, "base");
            if (B == void) return false;
            Cur = B;
        }
    }
}

/// `D.State` when `D` is a generated node interface, else null.
fn nodeInterfaceState(comptime D: type) ?type {
    comptime {
        if (@typeInfo(D) != .@"struct") return null;
        if (!@hasDecl(D, "State")) return null;
        if (@TypeOf(D.State) != type) return null;
        if (!isNodeState(D.State)) return null;
        return D.State;
    }
}

/// The first level of `S`'s chain whose `base` is not at offset 0, or null.
fn firstMovedBase(comptime S: type) ?[]const u8 {
    comptime {
        var Cur = S;
        while (@hasField(Cur, "base") and @FieldType(Cur, "base") != void) {
            if (@offsetOf(Cur, "base") != 0) return @typeName(Cur);
            Cur = @FieldType(Cur, "base");
        }
        return null;
    }
}

/// Where NodeBase sits in `S`: down the `base` chain to Node's State, then
/// its embedded state's `base`.
fn nodeBaseOffset(comptime S: type) usize {
    comptime {
        var off: usize = 0;
        var Cur = S;
        while (Cur != interfaces.Node.State) {
            off += @offsetOf(Cur, "base");
            Cur = @FieldType(Cur, "base");
        }
        const E = @FieldType(Cur, "_embedded");
        return off + @offsetOf(Cur, "_embedded") + @offsetOf(E, "base");
    }
}

/// The bytes of `T` no field uses, nested structs included (the deep
/// review's `paddingOf`, tmp/redesign/review/zig/bench/shapes/s09_final.zig).
fn paddingOf(comptime T: type) usize {
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            if (info.layout == .@"packed") return 0;
            var used: usize = 0;
            var inner: usize = 0;
            for (info.field_types, info.field_attrs) |F, attrs| {
                if (attrs.@"comptime") continue;
                used += @sizeOf(F);
                inner += paddingOf(F);
            }
            return @sizeOf(T) - used + inner;
        },
        .array => |info| return info.len * paddingOf(info.child),
        else => return 0,
    }
}

test "every node interface's State: 8-aligned, every level at offset 0, NodeBase at one offset" {
    @setEvalBranchQuota(100_000_000);
    const decls = comptime @typeInfo(interfaces).@"struct".decl_names;
    var count: usize = 0;
    var wrong: usize = 0;
    inline for (decls) |name| {
        const D = @field(interfaces, name);
        if (comptime @TypeOf(D) == type) {
            if (comptime nodeInterfaceState(D)) |S| {
                count += 1;
                if (comptime @alignOf(S) != 8) {
                    wrong += 1;
                    std.debug.print("{s}.State is {d}-aligned: a field aligned past 8 moves every level of the block (find it with tests/dom/nm1_node_layout_probe_test.zig)\n", .{ name, @alignOf(S) });
                }
                if (comptime firstMovedBase(S)) |level| {
                    wrong += 1;
                    std.debug.print("{s}.State: `base` is not at offset 0 in {s}\n", .{ name, level });
                }
                const at = comptime nodeBaseOffset(S);
                if (at != pinned_node_base_offset) {
                    wrong += 1;
                    std.debug.print("{s}.State: NodeBase at +{d}, pinned +{d}\n", .{ name, at, pinned_node_base_offset });
                }
            }
        }
    }
    // The walk found the node interfaces (169 on 2026-11-13), not nothing.
    try std.testing.expect(count >= 160);
    if (wrong != 0) return error.NodeLayoutPinMoved;
}

test "src/dom finds NodeBase at the pinned offset of a node's State block" {
    if (comptime !@hasDecl(dom.node_base, "offset_in_state")) return error.NoOffsetInState;
    try std.testing.expectEqual(pinned_node_base_offset, dom.node_base.offset_in_state);
}

const FieldPin = struct { name: []const u8, offset: usize, size: usize };

/// NodeBase, field by field: the walk's window first (0..32), then what a
/// link or a wrap reads (32..64), then the owner, the counts and the node
/// document's generation.
const node_base_fields = [_]FieldPin{
    .{ .name = "parent_node", .offset = 0, .size = 8 },
    .{ .name = "first_child", .offset = 8, .size = 8 },
    .{ .name = "next_sibling", .offset = 16, .size = 8 },
    .{ .name = "node_type", .offset = 24, .size = 2 },
    .{ .name = "is_connected", .offset = 26, .size = 1 },
    .{ .name = "is_shadow_host", .offset = 27, .size = 1 },
    .{ .name = "traces_held", .offset = 28, .size = 1 },
    .{ .name = "rc_flags", .offset = 29, .size = 1 },
    .{ .name = "element", .offset = 30, .size = 1 },
    .{ .name = "spare", .offset = 31, .size = 1 },
    .{ .name = "previous_or_last", .offset = 32, .size = 8 },
    .{ .name = "document_word", .offset = 40, .size = 8 },
    .{ .name = "rare", .offset = 48, .size = 8 },
    .{ .name = "wrapper", .offset = 56, .size = 8 },
    .{ .name = "owner", .offset = 64, .size = 8 },
    .{ .name = "rc", .offset = 72, .size = 4 },
    .{ .name = "subtree_holds", .offset = 76, .size = 4 },
    .{ .name = "document_generation", .offset = 80, .size = 8 },
};

test "NodeBase is an extern struct: every field at its pinned offset, no padding" {
    var wrong: usize = 0;
    if (@typeInfo(NodeBase).@"struct".layout != .@"extern") {
        wrong += 1;
        std.debug.print("NodeBase's layout is {s}, not extern: Zig may order its fields as it likes\n", .{@tagName(@typeInfo(NodeBase).@"struct".layout)});
    }
    inline for (node_base_fields) |pin| {
        if (comptime !@hasField(NodeBase, pin.name)) {
            wrong += 1;
            std.debug.print("NodeBase has no field `{s}` (pinned at +{d})\n", .{ pin.name, pin.offset });
        } else if (@offsetOf(NodeBase, pin.name) != pin.offset or @sizeOf(@FieldType(NodeBase, pin.name)) != pin.size) {
            wrong += 1;
            std.debug.print("NodeBase.{s}: +{d}, {d} bytes; pinned +{d}, {d} bytes\n", .{ pin.name, @offsetOf(NodeBase, pin.name), @sizeOf(@FieldType(NodeBase, pin.name)), pin.offset, pin.size });
        }
    }
    const field_count = @typeInfo(NodeBase).@"struct".field_names.len;
    if (field_count != node_base_fields.len) {
        wrong += 1;
        std.debug.print("NodeBase has {d} fields, {d} are pinned: pin the new one\n", .{ field_count, node_base_fields.len });
    }
    const padding = comptime paddingOf(NodeBase);
    if (padding != 0) {
        wrong += 1;
        std.debug.print("NodeBase has {d} bytes of padding, pinned 0\n", .{padding});
    }
    if (wrong != 0) return error.NodeBaseLayoutMoved;
}

test "the fields a tree walk reads are in NodeBase's first 32 bytes" {
    inline for (.{ "parent_node", "first_child", "next_sibling", "node_type" }) |name| {
        if (comptime !@hasField(NodeBase, name)) return error.NoSuchField;
        const end = @offsetOf(NodeBase, name) + @sizeOf(@FieldType(NodeBase, name));
        if (end > 32) {
            std.debug.print("NodeBase.{s} ends at +{d}: outside the walk's 32-byte window\n", .{ name, end });
            return error.WalkWindowMoved;
        }
    }
}

test "the element's flags are one byte of NodeBase, not five of Element's state" {
    if (comptime !@hasDecl(NodeBase, "ElementBits")) return error.NoElementBits;
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(NodeBase.ElementBits));
    // All zero is an element as "create an element" starts it: custom
    // element state "undefined", no registry, nothing in progress - what a
    // zeroed State block holds.
    try std.testing.expectEqual(@as(u8, 0), @as(u8, @bitCast(NodeBase.ElementBits{})));
    const E = @FieldType(interfaces.Element.State, "_embedded");
    inline for (.{ "custom_element_state", "custom_element_ever_enqueued", "appending_clone", "registry_place", "click_in_progress" }) |name| {
        if (@hasField(E, name)) {
            std.debug.print("Element's state still keeps `{s}` as a byte of its own\n", .{name});
            return error.ElementFlagKept;
        }
    }
}

test "the padding in a div's and a Text's block only goes down" {
    // What is left is the tail of EventTarget's level: its 4-byte live word
    // beside the 8-byte listener pointer. It goes when the live bits join
    // the flags and the listener reference leaves the node (plan v2 X2, I1).
    const pins = .{
        .{ "HTMLDivElement", interfaces.HTMLDivElement.State, 4 },
        .{ "Text", interfaces.Text.State, 4 },
        .{ "Comment", interfaces.Comment.State, 4 },
    };
    var wrong: usize = 0;
    inline for (pins) |p| {
        const padding = comptime paddingOf(p[1]);
        if (padding != p[2]) {
            wrong += 1;
            std.debug.print("{s}.State: {d} bytes of padding, pinned {d}\n", .{ p[0], padding, p[2] });
        }
    }
    if (wrong != 0) return error.PaddingPinMoved;
}
