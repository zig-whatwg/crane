//! A node's whole State block, pinned in ONE place (lane cg1 batch 1; lesson
//! testing-a-total-pinned-in-six-files-moves-in-six-files.md).
//!
//! Each node-memory batch pins the LEVEL it changed in its own test file (an
//! embedded state, a level's own fields). The sums - a div's whole block, and
//! the generated part of it (the State less every level's embedded
//! InternalState) - are pinned here only, so a change to any level moves one
//! line here instead of a line in every earlier batch's file. A batch that
//! moves a total edits this file and adds its line to the history below.
//!
//! History of a div's block (HTMLDivElement.State, bytes):
//! - 472 after lane perf2 b6; 464 after perf2 b7 (EventTarget's current event
//!   is a Window's); 424/360 after perf3 E1 (the registry association 40, the
//!   slottable state 64); 312 after nd2 N2 (the name, one record pointer); 264
//!   after nd2 N3 (the ID and classes views); 248 after lis1 N5 (EventTarget's
//!   listeners, one pointer). Those pins lived in seven files.
//! - 192 after lane cg1 N1: the 7 [SameObject] caches of Element (classList,
//!   attributes, part, children) and HTMLElement (style, attributeStyleMap,
//!   dataset) left the generated State, 56 bytes (tests/dom/
//!   cg1_element_same_object_test.zig pins the levels: 0 bytes of own fields).
//! - 184 after the wrapper redesign's P6 (lane wr1): NodeBase.holds, the
//!   node_holds chain's head, went (88 -> 80 bytes; tests/dom/
//!   perf2b6_node_layout_test.zig pins NodeBase).
//! - 152 after lane nm1's layout batch, steps 1-4 (plan v2 section 6 items
//!   4 and 5): Node's pointer to its own NodeBase and its second node type
//!   went (16), the element's five flag bytes became one byte of NodeBase
//!   (8), and the childNodes list is cached once (8). NodeBase is an extern
//!   struct at +24 of every node State (tests/dom/nm1_node_layout_pins_test.zig
//!   pins the structure).
//! - 144 after lane nm1's step 5: the node document is one word of NodeBase
//!   (the Document's Instance; it was that in Node's state and the Document's
//!   NodeBase in NodeBase, 8 bytes each), and its generation moved into
//!   NodeBase beside it (tests/dom/nm1_node_document_word_test.zig). An exact
//!   144-byte arena block: 48 bytes less than the 192-byte block of 184.
//!
//! A Text's and a Comment's block: 160 after the wrapper redesign's P6 (their
//! history is in tests/dom/nd1_text_data_layout_test.zig); 136 after lane
//! nm1's steps 1-4 (Node's 24 bytes above; a Text has no element flags); 128
//! after its step 5.
//!
//! NodeBase, and Node's and Element's embedded states, are pinned here too
//! since lane nm1: perf2b5_node_layout_test.zig, perf2b6_node_layout_test.zig,
//! nd1_text_data_layout_test.zig, perf3e1_text_slottable_test.zig and
//! rare1_sparse_rare_data_test.zig each carried a copy of one of them.
//!
//! They name generated States and src/dom types only, and compile at any base.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

fn printLayout(comptime T: type) void {
    std.debug.print("\n{s}: {d} bytes, align {d}\n", .{ @typeName(T), @sizeOf(T), @alignOf(T) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<28} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

const Pin = struct { name: []const u8, State: type, block: usize, generated: usize };

/// Whole block, and the generated part (less every level's InternalState):
/// the root's live word (4, padded to 8) and the [SameObject] caches still in
/// a State - Node's childNodes (NodeRareData is not a sparse block yet) and a
/// DocumentFragment's children.
const pins = [_]Pin{
    .{ .name = "HTMLDivElement", .State = interfaces.HTMLDivElement.State, .block = 144, .generated = 16 },
    .{ .name = "HTMLSpanElement", .State = interfaces.HTMLSpanElement.State, .block = 144, .generated = 16 },
    .{ .name = "HTMLElement", .State = interfaces.HTMLElement.State, .block = 144, .generated = 16 },
    .{ .name = "Element", .State = interfaces.Element.State, .block = 144, .generated = 16 },
    .{ .name = "Text", .State = interfaces.Text.State, .block = 128, .generated = 16 },
    .{ .name = "Comment", .State = interfaces.Comment.State, .block = 128, .generated = 16 },
    .{ .name = "CDATASection", .State = interfaces.CDATASection.State, .block = 128, .generated = 16 },
};

/// The parts every node's block is made of.
const part_pins = .{
    // The tree links 32, the node document 8 and its generation 8, the rare
    // data 8, the wrapper slot 8, the owner 8, the two counts 8, and 8 bytes
    // of type and flags.
    .{ "NodeBase", dom.NodeBase, 88 },
    // The NodeBase, and nothing else.
    .{ "Node's embedded state", Embedded(interfaces.Node.State), 88 },
    // The name 8, the attributes 8, the style 8, the rare word 8.
    .{ "Element's embedded state", Embedded(interfaces.Element.State), 32 },
};

test "the parts of a node's block: NodeBase, and each level's embedded state" {
    var wrong: usize = 0;
    inline for (part_pins) |p| {
        if (@sizeOf(p[1]) != p[2]) {
            wrong += 1;
            printLayout(p[1]);
            std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ p[0], @sizeOf(p[1]), p[2] });
        }
    }
    if (wrong != 0) return error.SizePinMoved;
}

test "an element's, a Text's and a Comment's one block, whole and generated" {
    var wrong: usize = 0;
    inline for (pins) |p| {
        const generated = @sizeOf(p.State) - embeddedBytes(p.State);
        if (@sizeOf(p.State) != p.block or generated != p.generated) {
            wrong += 1;
            printLayout(p.State);
            std.debug.print("{s}.State: {d} bytes ({d} generated, {d} embedded); pinned {d} ({d} generated)\n", .{ p.name, @sizeOf(p.State), generated, embeddedBytes(p.State), p.block, p.generated });
        }
    }
    if (wrong != 0) return error.SizePinMoved;
}

test "a div's and a Text's block is an exact-size arena block" {
    inline for (.{ interfaces.HTMLDivElement.State, interfaces.Text.State }) |S| {
        const held = runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S));
        if (held - @sizeOf(S) >= 16) {
            std.debug.print("{s}: {d} bytes in a {d}-byte block\n", .{ @typeName(S), @sizeOf(S), held });
            return error.NotExactSize;
        }
    }
}
