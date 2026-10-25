//! Rule construction transfers its prelude to make even when allocation fails.
const std = @import("std");
const dom = @import("dom");
const css = dom.style.css;
const rules = dom.style.rules;

fn buildAndRelease(a: std.mem.Allocator, parsed: *const css.rules.Rule, kind: rules.Kind) !void {
    const rule = (try rules.build(.{ .parse = .{ .allocator = a } }, parsed, .top)) orelse
        return error.ExpectedBuiltRule;
    defer rule.unref();
    try std.testing.expectEqual(kind, std.meta.activeTag(rule.data));
    try std.testing.expectEqualStrings(parsed.prelude, rule.prelude);
    try std.testing.expect(rule.block().?.get(.margin_top) != null);
}

fn checkBuild(text: []const u8, kind: rules.Kind) !void {
    // Keep syntax parsing outside the failure walk: inject every allocation
    // in the CSSOM builder, including the final Rule allocation.
    var parsed = (try css.rules.parseRule(std.testing.allocator, text)) orelse
        return error.ExpectedParsedRule;
    defer parsed.deinitOwned(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, buildAndRelease, .{ &parsed, kind });
}

test "style rule construction frees its prelude exactly once on every allocation failure" {
    try checkBuild(".ci1 > b { margin-top: 10px }", .style);
}

test "page rule construction frees its prelude exactly once on every allocation failure" {
    try checkBuild("@page :first { margin-top: 10px }", .page);
}
