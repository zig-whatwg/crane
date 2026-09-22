//! Duplicate-attribute detection on a tag with many attributes.
//!
//! HTML Standard §13.2.5: "If there is already an attribute on the token with
//! the exact same name, then this is a duplicate-attribute parse error and the
//! new attribute must be removed from the token."
//! https://html.spec.whatwg.org/multipage/parsing.html#attribute-name-state
//!
//! `TagToken.finishCurrentAttribute` switches from a linear scan to a
//! `StringHashMapUnmanaged` once a tag carries more than four attributes. The
//! keys it stored were slices into `Attribute.name`, and `SmallString` keeps up
//! to 31 bytes INLINE - so a slice taken from a by-value `Attribute` copy points
//! into a stack slot the next copy reuses. Every seeded key aliased one address,
//! so on the next rehash they all compared equal and `grow`'s
//! `putAssumeCapacityNoClobber` asserted, killing the process.
//!
//! These tests live here rather than beside the code because `html_core_mod`
//! has no `addTest` target: a test block in `src/html/parser/tokens.zig` is
//! never compiled, let alone run. `tests/html/` is wired into `zig build test`.

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;

/// Collect the attribute names of the first start tag in `source`.
fn firstStartTagAttributeNames(
    allocator: std.mem.Allocator,
    source: []const u8,
    out: *std.ArrayList([]const u8),
) !void {
    var tokenizer = Tokenizer.init(allocator, source);
    defer tokenizer.deinit();

    // `emitCurrentTag` does `self.current_token = null` and returns the token
    // by value, so each token belongs to US the moment we receive it.
    while (try tokenizer.nextToken()) |token| {
        var owned = token;
        defer owned.deinit();

        switch (owned) {
            .start_tag => |tag| {
                for (tag.attributes.toSlice()) |attr| {
                    try out.append(allocator, try allocator.dupe(u8, attr.getName()));
                }
                return;
            },
            else => {},
        }
    }
}

fn freeNames(allocator: std.mem.Allocator, names: *std.ArrayList([]const u8)) void {
    for (names.items) |n| allocator.free(n);
    names.deinit(allocator);
}

test "tokenizer - a tag with seven attributes keeps all of them" {
    const allocator = testing.allocator;

    // Verbatim from html/semantics/forms/the-input-element/range-2.html, the
    // WPT file this crashed on. Seven attributes is what it takes: the hash set
    // is seeded at the sixth and rehashes at the seventh.
    const source =
        \\<input type="range" id="r00" min="0" max="100" step="20" value="40" style="display:none">
    ;

    var names: std.ArrayList([]const u8) = .empty;
    defer freeNames(allocator, &names);
    try firstStartTagAttributeNames(allocator, source, &names);

    const expected = [_][]const u8{ "type", "id", "min", "max", "step", "value", "style" };
    try testing.expectEqual(expected.len, names.items.len);
    for (expected, names.items) |want, got| {
        try testing.expectEqualStrings(want, got);
    }
}

test "tokenizer - duplicates are dropped past the hash-set threshold" {
    const allocator = testing.allocator;

    // Ten distinct names, each repeated once. The repeats must all be dropped,
    // and the survivors must be the FIRST of each pair - §13.2.5 removes the
    // new attribute, not the old one.
    const source =
        \\<x a=1 b=2 c=3 d=4 e=5 f=6 g=7 h=8 i=9 j=10 a=X b=X c=X d=X e=X f=X g=X h=X i=X j=X>
    ;

    var names: std.ArrayList([]const u8) = .empty;
    defer freeNames(allocator, &names);
    try firstStartTagAttributeNames(allocator, source, &names);

    const expected = [_][]const u8{ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" };
    try testing.expectEqual(expected.len, names.items.len);
    for (expected, names.items) |want, got| {
        try testing.expectEqualStrings(want, got);
    }
}

test "tokenizer - names longer than SmallString's inline capacity" {
    const allocator = testing.allocator;

    // SmallString holds 31 bytes inline and spills to the heap above that. The
    // heap case has a stable pointer, so it never hit the aliasing bug - which
    // is exactly why it is worth pinning alongside the inline case.
    const source =
        \\<x data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-0=1 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-1=2 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-2=3 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-3=4 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-4=5 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-5=6 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-6=7 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-0=X>
    ;

    var names: std.ArrayList([]const u8) = .empty;
    defer freeNames(allocator, &names);
    try firstStartTagAttributeNames(allocator, source, &names);

    // Seven distinct names; the eighth repeats the first and is dropped.
    try testing.expectEqual(@as(usize, 7), names.items.len);
    try testing.expectEqualStrings(
        "data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-0",
        names.items[0],
    );
    try testing.expectEqualStrings(
        "data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes-6",
        names.items[6],
    );
}

test "tokenizer - a mix of inline and heap attribute names" {
    const allocator = testing.allocator;

    // The set holds both kinds at once, so a fix that only stabilises one of
    // them still fails here.
    const source =
        \\<x a=1 data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes=2 b=3 c=4 d=5 e=6 f=7 a=X>
    ;

    var names: std.ArrayList([]const u8) = .empty;
    defer freeNames(allocator, &names);
    try firstStartTagAttributeNames(allocator, source, &names);

    const expected = [_][]const u8{
        "a",
        "data-attribute-name-that-is-definitely-longer-than-thirty-one-bytes",
        "b",
        "c",
        "d",
        "e",
        "f",
    };
    try testing.expectEqual(expected.len, names.items.len);
    for (expected, names.items) |want, got| {
        try testing.expectEqualStrings(want, got);
    }
}
