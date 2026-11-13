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
//!
//! They name generated States only, and compile at any base.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

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
/// a State - Node's childNodes (lane wr1 holds NodeRareData) and a
/// DocumentFragment's children.
const pins = [_]Pin{
    .{ .name = "HTMLDivElement", .State = interfaces.HTMLDivElement.State, .block = 184, .generated = 16 },
    .{ .name = "HTMLSpanElement", .State = interfaces.HTMLSpanElement.State, .block = 184, .generated = 16 },
    .{ .name = "HTMLElement", .State = interfaces.HTMLElement.State, .block = 184, .generated = 16 },
    .{ .name = "Element", .State = interfaces.Element.State, .block = 184, .generated = 16 },
};

test "a div's, a span's, an HTMLElement's and an Element's one block, whole and generated" {
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

test "a div's block is an exact-size arena block" {
    const S = interfaces.HTMLDivElement.State;
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S));
    if (held - @sizeOf(S) >= 16) {
        std.debug.print("HTMLDivElement.State: {d} bytes in a {d}-byte block\n", .{ @sizeOf(S), held });
        return error.NotExactSize;
    }
}
