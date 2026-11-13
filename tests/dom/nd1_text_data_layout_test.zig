//! A CharacterData node's data in 16 bytes (lane nd1, batch 1: N8 of
//! tmp/redesign/nodedata-design.md; techniques.md T8, crane-layout.md P8).
//!
//! The data was 48 bytes on every Text, Comment, CDATASection and
//! ProcessingInstruction: a heap pointer, the two u32 lengths and a 31-byte
//! inline buffer. On real pages 32-99.8% of texts are 1-8 UTF-16 units and
//! 11-76% are whitespace-only (crane-layout.md P8), yet every Text paid all
//! 31 bytes. It is now the two lengths and ONE word: up to 8 bytes inline,
//! the whitespace shapes Gecko shares a slice of one static blob, anything
//! else a pointer to an exact-size block - the shape of Gecko's
//! CharacterDataBuffer (a pointer + a 32-bit state word, `mInHeap` telling
//! shared static storage from the heap; dom/base/CharacterDataBuffer.h) and
//! of Lightpanda's 16-byte string (src/string.zig: a length, then an 8-byte
//! union of inline bytes and a pointer).
//!
//! The pins name generated States and src/dom types only (AGENTS.md "The
//! impls boundary"): CharacterData's data is its State's `_embedded` field.
//! They compile at the base, where they fail.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
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

/// The block a State takes from its Browser's arena holds it exactly (less
/// than one 16-byte quantum to spare): a request saves bytes only when it
/// crosses a class (lesson debugging-a-hot-struct-against-allocator-size-classes).
fn expectExactBlock(comptime State: type) !void {
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(State), @alignOf(State));
    if (held - @sizeOf(State) >= 16) {
        std.debug.print("{s}: {d} bytes in a {d}-byte block\n", .{ @typeName(State), @sizeOf(State), held });
        return error.NotExactSize;
    }
}

const Data = @FieldType(interfaces.CharacterData.State, "_embedded");

test "CharacterData's data is 16 bytes: two u32 lengths and one word" {
    comptime std.debug.assert(Data == dom.character_data.Data);
    try expectNoField(Data, .{ "heap", "inline_text" });
    // Safe builds give a bare union a hidden tag (lesson
    // testing-a-std-safety-field-moves-size-pins-in-safe-builds): the word
    // must stay 8 bytes in every mode this test runs in.
    try expectSize(Data, 16);
    try std.testing.expectEqual(@as(usize, 8), @alignOf(Data));
}

test "a text node's one block is 160 bytes: 216 less 32 of inline buffer, EventTarget's 16 and NodeBase.holds' 8" {
    // 216 at main b1bd4eae568 (perf3e1_text_slottable_test.zig): 16 of
    // pointers and the live word, EventTarget's 24, Node's 128 and
    // CharacterData's 48. Its arena block goes from 224 to 192; lane lis1
    // made EventTarget's 24 one pointer (8): 168; the wrapper redesign's P6
    // (lane wr1) took NodeBase.holds (8): 160, an exact block.
    const S = interfaces.Text.State;
    try expectSize(S, 160);
    try expectExactBlock(S);
}

test "a comment's one block is 160 bytes, as a text node's" {
    const S = interfaces.Comment.State;
    try expectSize(S, 160);
    try expectExactBlock(S);
}

test "a CDATA section's block is a text node's" {
    try expectSize(interfaces.CDATASection.State, @sizeOf(interfaces.Text.State));
}
