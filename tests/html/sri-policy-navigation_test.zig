//! Navigation preserves the Integrity-Policy fields used by a new document.
const std = @import("std");
const navigation = @import("html_core").navigation.fetch_integration;

test "sri policy navigation keeps combined owned policy headers after the response is released" {
    const a = std.testing.allocator;
    var result = blk: {
        const response = try navigation.InternalResponse.init(a);
        defer response.deinit();
        response.status = 200;
        try response.addUrl("https://sri.test/page");
        try response.header_list.append("Integrity-Policy", "blocked-destinations=(script)");
        try response.header_list.append("integrity-policy", "endpoints=(enforced)");
        try response.header_list.append("Integrity-Policy-Report-Only", "blocked-destinations=(script), endpoints=(observed)");
        break :blk try navigation.resultFromResponse(a, "https://sri.test/page", response, .{});
    };
    defer result.deinit();
    const headers = result.headers orelse return error.MissingHeaders;
    try std.testing.expectEqualStrings(
        "blocked-destinations=(script), endpoints=(enforced)",
        headers.get("integrity-policy") orelse return error.MissingIntegrityPolicy,
    );
    try std.testing.expectEqualStrings(
        "blocked-destinations=(script), endpoints=(observed)",
        headers.get("integrity-policy-report-only") orelse return error.MissingReportOnlyPolicy,
    );
}
