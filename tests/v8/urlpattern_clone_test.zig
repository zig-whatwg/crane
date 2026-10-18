//! URLPattern.clone(): a deep copy of a compiled URL pattern - its component
//! pattern strings, regular expressions, group names and ignore case flag -
//! that outlives the original and matches exactly as it does. Service
//! Workers' Parse URL Pattern keeps a constructed URLPattern object's pattern
//! this way for a router rule (lane sw1-b4), long after the object is gone.

const std = @import("std");
const testing = std.testing;
const urlpattern = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const URLPattern = urlpattern.URLPattern;

test "a cloned pattern matches as the original does, after the original is gone" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var original = try URLPattern.create(allocator, realm, .{ .init = .{ .pathname = "/**/direct.txt" } }, .{});
    var copy = try original.clone(allocator);
    defer copy.deinit(allocator);
    const urls = [_][]const u8{
        "https://a.test/x/direct.txt",
        "https://a.test/direct.txt",
        "https://a.test/x/DIRECT.TXT",
        "https://a.test/x/other.txt",
    };
    var expected: [urls.len]bool = undefined;
    for (urls, &expected) |url, *e| e.* = try urlpattern.matcher.testMatch(allocator, realm, &original, url, null);
    original.deinit(allocator);
    for (urls, expected) |url, e| {
        try testing.expectEqual(e, try urlpattern.matcher.testMatch(allocator, realm, &copy, url, null));
    }
    try testing.expect(expected[0]);
    try testing.expect(!expected[2]);
    try testing.expectEqualStrings("/**/direct.txt", copy.pathname.pattern_string);
}

test "a cloned pattern keeps ignoreCase, its group names and its regexp groups flag" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const allocator = testing.allocator;

    var original = try URLPattern.create(allocator, realm, .{ .init = .{ .pathname = "/:section/(\\d+)/*.TxT" } }, .{ .ignore_case = true });
    defer original.deinit(allocator);
    var copy = try original.clone(allocator);
    defer copy.deinit(allocator);
    try testing.expect(copy.ignore_case);
    try testing.expect(copy.hasRegexpGroups());
    try testing.expectEqual(original.pathname.group_names.len, copy.pathname.group_names.len);
    for (original.pathname.group_names, copy.pathname.group_names) |a, b| try testing.expectEqualStrings(a, b);
    for ([_][]const u8{ "https://a.test/docs/12/readme.txt", "https://a.test/docs/x/readme.txt", "https://a.test/DOCS/7/A.TXT" }) |url| {
        try testing.expectEqual(
            try urlpattern.matcher.testMatch(allocator, realm, &original, url, null),
            try urlpattern.matcher.testMatch(allocator, realm, &copy, url, null),
        );
    }
    try testing.expect(try urlpattern.matcher.testMatch(allocator, realm, &copy, "https://a.test/DOCS/7/A.TXT", null));
    // The copy's strings are its own.
    try testing.expect(copy.pathname.regex_string.ptr != original.pathname.regex_string.ptr);
    try testing.expect(copy.pathname.regexp.source.ptr == copy.pathname.regex_string.ptr);
}

test "a clone that cannot be made fails without a leak" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    var pattern = try URLPattern.create(testing.allocator, realm, .{ .init = .{ .pathname = "/:a/:b", .search = "q=:c" } }, .{});
    defer pattern.deinit(testing.allocator);
    const Clone = struct {
        fn run(allocator: std.mem.Allocator, p: *const URLPattern) !void {
            var copy = try p.clone(allocator);
            copy.deinit(allocator);
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Clone.run, .{&pattern});
}
