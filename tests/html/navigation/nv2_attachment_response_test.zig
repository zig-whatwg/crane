//! A download response leaves the current document in place. Its disposition
//! must survive the navigation fetch's header copy before commit inspects it.
const std = @import("std");
const html = @import("html_core");
const navigation_fetch = html.navigation.fetch_integration;

test "a navigation fetch preserves Content-Disposition after its response is freed" {
    const allocator = std.testing.allocator;
    const response = try navigation_fetch.InternalResponse.init(allocator);
    var response_owned = true;
    defer if (response_owned) response.deinit();
    response.status = 200;
    try response.addUrl("http://example.test/download");
    try response.header_list.append("Content-Type", "text/html");
    try response.header_list.append("Content-Disposition", "attachment; filename=page.html");
    var result = try navigation_fetch.resultFromResponse(allocator, "http://example.test/download", response, .{});
    defer result.deinit();
    response.deinit();
    response_owned = false;
    try std.testing.expect(result.headers != null);
    const disposition = result.headers.?.get("content-disposition");
    try std.testing.expect(disposition != null);
    try std.testing.expectEqualStrings("attachment; filename=page.html", disposition.?);
}

test "attachment disposition prevents a document independently of MIME and filename parameters" {
    const allocator = std.testing.allocator;
    var integration = html.IFrameIntegration.init(allocator);
    defer integration.deinit();
    const Case = struct { disposition: []const u8, makes_document: bool };
    const cases = [_]Case{
        .{ .disposition = "attachment", .makes_document = false },
        .{ .disposition = "\t ATTACHMENT \t; filename=page.html", .makes_document = false },
        .{ .disposition = "attachment; filename=\"unfinished", .makes_document = false },
        .{ .disposition = "extension-type; filename=page.html", .makes_document = false },
        .{ .disposition = "inline; filename=page.html", .makes_document = true },
        .{ .disposition = "INLINE", .makes_document = true },
        .{ .disposition = "", .makes_document = true },
        .{ .disposition = "; filename=page.html", .makes_document = true },
        .{ .disposition = "attachment, inline", .makes_document = true },
        .{ .disposition = "attachment=invalid", .makes_document = true },
    };
    for (cases) |case| {
        var result = navigation_fetch.NavigationFetchResult.init(allocator);
        defer result.deinit();
        result.status = 200;
        result.is_network_error = false;
        result.content_type = try allocator.dupe(u8, "text/html");
        result.headers = navigation_fetch.NavigationFetchResult.HeaderMap.init(allocator);
        try result.headers.?.put(try allocator.dupe(u8, "content-disposition"), try allocator.dupe(u8, case.disposition));
        try std.testing.expectEqual(case.makes_document, integration.responseMakesDocument(&result));
    }
}
