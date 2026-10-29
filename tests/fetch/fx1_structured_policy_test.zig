//! Permissions Policy consumes structured dictionary tokens, strings and report-to.
const std = @import("std");
const fields = @import("fetch").internal.structured_fields;

test "structured policy projection distinguishes scalar and inner-list values" {
    var dictionary = try fields.parsePolicyDictionary(
        std.testing.allocator,
        "camera=(self \"https://child.test\" 123);report-to=endpoint, microphone=*, geolocation=()",
    );
    defer dictionary.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), dictionary.members.items.len);
    const camera = dictionary.members.items[0];
    try std.testing.expect(camera.inner_list);
    try std.testing.expectEqual(@as(usize, 2), camera.items.len);
    try std.testing.expectEqualStrings("self", camera.items[0].token);
    try std.testing.expectEqualStrings("https://child.test", camera.items[1].string);
    try std.testing.expectEqualStrings("endpoint", camera.report_to.?);
    const microphone = dictionary.members.items[1];
    try std.testing.expect(!microphone.inner_list);
    try std.testing.expectEqualStrings("*", microphone.items[0].token);
    try std.testing.expect(dictionary.members.items[2].inner_list);
    try std.testing.expectEqual(@as(usize, 0), dictionary.members.items[2].items.len);
}

test "structured policy projection validates discarded items and parameters" {
    try std.testing.expectError(error.InvalidField, fields.parsePolicyDictionary(std.testing.allocator, "camera=(self;bad=?2)"));
    try std.testing.expectError(error.InvalidField, fields.parsePolicyDictionary(std.testing.allocator, "camera=(self), broken=(\"unterminated)"));
}

test "structured policy duplicate key replaces the value and reporting parameter" {
    var dictionary = try fields.parsePolicyDictionary(
        std.testing.allocator,
        "camera=(\"https://first.test\");report-to=old, microphone=*, camera=(self);report-to=new",
    );
    defer dictionary.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), dictionary.members.items.len);
    try std.testing.expectEqualStrings("camera", dictionary.members.items[0].key);
    try std.testing.expectEqualStrings("self", dictionary.members.items[0].items[0].token);
    try std.testing.expectEqualStrings("new", dictionary.members.items[0].report_to.?);
}

test "structured policy projection is safe under every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var dictionary = try fields.parsePolicyDictionary(
        allocator,
        "camera=(self \"https://one.test\");report-to=endpoint, camera=(\"https://two.test\");report-to=new, microphone=*",
    );
    defer dictionary.deinit(allocator);
}
