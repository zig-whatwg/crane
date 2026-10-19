//! Fetch's data: URL processor excludes the fragment before reading metadata
//! or decoding the body. Navigation must use the same processor while keeping
//! the complete URL for location.hash and the indicated part of the document.
const std = @import("std");
const fetch = @import("fetch");
const navigation = @import("html").navigation;

const Case = struct { url: []const u8, body: []const u8 };
const cases = [_]Case{
    .{ .url = "data:text/plain,body#fragment", .body = "body" },
    .{ .url = "data:text/plain,body#", .body = "body" },
    .{ .url = "data:text/plain,%23body#fragment", .body = "#body" },
    .{ .url = "data:text/plain,body?query#fragment", .body = "body?query" },
    .{ .url = "data:text/plain,a+b%23c", .body = "a+b#c" },
    .{ .url = "data:text/plain;base64,Ym9keQ==#fragment", .body = "body" },
    .{ .url = "data:text/plain;base64,Ym9keQ%3D%3D#fragment", .body = "body" },
};

test "Fetch data URLs exclude fragments before body decoding" {
    for (cases) |case| {
        var result = (try fetch.algorithms.processDataUrl(std.testing.allocator, case.url)) orelse
            return error.MissingData;
        defer result.deinit();
        try std.testing.expectEqualStrings(case.body, result.body);
        try std.testing.expectEqualStrings("text/plain", result.mime_type);
    }
}

test "a comma in a data URL fragment cannot delimit its body" {
    const result = fetch.algorithms.processDataUrl(std.testing.allocator, "data:text/plain#fragment,body") catch |err| {
        try std.testing.expect(err == error.MissingComma);
        return;
    };
    if (result) |value| {
        var unexpected = value;
        unexpected.deinit();
    }
    return error.TestUnexpectedResult;
}

test "data navigation decodes the body without losing its fragment URL" {
    for (cases) |case| {
        var result = try navigation.fetchNavigationResource(std.testing.allocator, case.url, .{});
        defer result.deinit();
        try std.testing.expect(result.ok);
        try std.testing.expectEqual(@as(u16, 200), result.status);
        try std.testing.expectEqualStrings(case.body, result.body.?);
        try std.testing.expectEqualStrings("text/plain", result.content_type.?);
        try std.testing.expectEqualStrings(case.url, result.final_url);
    }
}

test "data navigation rejects a comma that occurs only in its fragment" {
    var result = try navigation.fetchNavigationResource(std.testing.allocator, "data:text/plain#fragment,body", .{});
    defer result.deinit();
    try std.testing.expect(!result.ok);
    try std.testing.expectEqual(@as(u16, 400), result.status);
    try std.testing.expect(result.body == null);
}

fn navigationAllocationFailure(allocator: std.mem.Allocator) !void {
    var result = try navigation.fetchNavigationResource(allocator, "data:text/plain,%23body#fragment", .{});
    defer result.deinit();
}

test "data navigation releases partial results on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, navigationAllocationFailure, .{});
}
