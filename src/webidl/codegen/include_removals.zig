//! Which `includes` statements codegen leaves out.
//!
//! An `includes` statement all three browsers decline (golden rule 2, last
//! case: the browsers agree with each other, and no newer spec is lagging
//! behind them), each entry with its probe evidence and the spec issue;
//! codegen fails on an entry that matches no includes statement
//! (ir.zig `checkIncludeRemovals`), so a snapshot that drops the statement
//! drops its entry too.
//!
//! specs/idl is a pinned webref snapshot, never edited (specs/idl/WEBREF.md);
//! this table is the codegen means to apply golden rule 2 to one of its
//! `includes` lines. Keep it to includes statements: it is no general
//! override (a removed member is member_removals.zig's, and only when its
//! spec removed it).

const std = @import("std");

pub const Removal = struct {
    /// The interface that would include the mixin.
    target: []const u8,
    mixin: []const u8,
    /// The browsers' evidence and the spec issue.
    reason: []const u8,
};

const svg_window_event_handlers = "SVG 2's IDL says `SVGSVGElement includes WindowEventHandlers`, and no browser ships it: " ++
    "lane fw2's probe (2026-11-22) found none of onafterprint ... onunload on an <svg> in Chrome 157, Firefox 159 or " ++
    "Safari 27 (SVGSVGElement.prototype has no onafterprint; HTMLBodyElement.prototype does). w3c/svgwg#741, open since " ++
    "2019, asks whether the line is meant at all (\"ideally we do not expose more events as attributes than are " ++
    "implemented in UAs\"); no engine has a bug to add it. Angular's zone.js suite depends on the browsers' shape " ++
    "(\"should patch all possible on properties on svg element\")";

pub const table = [_]Removal{
    .{ .target = "SVGSVGElement", .mixin = "WindowEventHandlers", .reason = svg_window_event_handlers },
};

/// The index in `entries` of the entry for `target includes mixin`, if any.
pub fn indexOf(entries: []const Removal, target: []const u8, mixin: []const u8) ?usize {
    for (entries, 0..) |entry, i| {
        if (std.mem.eql(u8, entry.target, target) and std.mem.eql(u8, entry.mixin, mixin)) return i;
    }
    return null;
}

/// The first entry no includes statement matched (`matched[i]` for
/// `entries[i]`), among those whose target the sources define (`defined`):
/// a source set without the interface - a test's own IDL - says nothing.
pub fn firstStale(entries: []const Removal, matched: []const bool, context: anytype, comptime defined: fn (@TypeOf(context), []const u8) bool) ?Removal {
    for (entries, matched) |entry, was_matched| {
        if (was_matched) continue;
        if (!defined(context, entry.target)) continue;
        return entry;
    }
    return null;
}

test "the table names each statement once, with a reason" {
    for (table, 0..) |entry, i| {
        try std.testing.expect(entry.reason.len > 0);
        for (table[i + 1 ..]) |other| {
            try std.testing.expect(!(std.mem.eql(u8, entry.target, other.target) and std.mem.eql(u8, entry.mixin, other.mixin)));
        }
    }
    try std.testing.expectEqual(@as(?usize, 0), indexOf(&table, "SVGSVGElement", "WindowEventHandlers"));
    try std.testing.expectEqual(@as(?usize, null), indexOf(&table, "HTMLBodyElement", "WindowEventHandlers"));
    try std.testing.expectEqual(@as(?usize, null), indexOf(&table, "SVGSVGElement", "GlobalEventHandlers"));
}

test "an entry no includes statement matched is stale, when the sources define its target" {
    const entries = [_]Removal{
        .{ .target = "A", .mixin = "M", .reason = "r" },
        .{ .target = "B", .mixin = "N", .reason = "r" },
    };
    const Defined = struct {
        fn f(names: []const []const u8, name: []const u8) bool {
            for (names) |n| if (std.mem.eql(u8, n, name)) return true;
            return false;
        }
    };
    const both: []const []const u8 = &.{ "A", "B" };
    // Every entry matched: nothing stale.
    try std.testing.expectEqual(@as(?Removal, null), firstStale(&entries, &.{ true, true }, both, Defined.f));
    // B's statement is gone from sources that define B: B is stale.
    try std.testing.expectEqualStrings("B", firstStale(&entries, &.{ true, false }, both, Defined.f).?.target);
    // Sources without B (a test's own IDL) say nothing about it.
    const only_a: []const []const u8 = &.{"A"};
    try std.testing.expectEqual(@as(?Removal, null), firstStale(&entries, &.{ true, false }, only_a, Defined.f));
}
