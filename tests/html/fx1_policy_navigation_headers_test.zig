//! Permissions Policy §9.1: both navigation response fields reach the
//! document factory as combined, owned values.
const std = @import("std");
const navigation = @import("html_core").navigation.fetch_integration;

fn copyHeaders(allocator: std.mem.Allocator) !void {
    var result: navigation.NavigationFetchResult = undefined;
    {
        const response = try navigation.InternalResponse.init(allocator);
        defer response.deinit();
        response.status = 200;
        try response.addUrl("https://parent.test/frame");
        try response.header_list.append("Permissions-Policy", "deferred-fetch=()");
        try response.header_list.append("permissions-policy", "deferred-fetch-minimal=*");
        try response.header_list.append("Permissions-Policy-Report-Only", "deferred-fetch=*;report-to=one");
        try response.header_list.append("permissions-policy-report-only", "deferred-fetch-minimal=();report-to=two");
        result = try navigation.resultFromResponse(allocator, "https://parent.test/frame", response, .{});
    }
    defer result.deinit();
    // The response (and every field value it owned) has already been freed.
    const headers = result.headers orelse return error.MissingNavigationHeaders;
    try std.testing.expectEqualStrings("deferred-fetch=(), deferred-fetch-minimal=*", headers.get("permissions-policy") orelse return error.MissingEnforcingPolicy);
    try std.testing.expectEqualStrings("deferred-fetch=*;report-to=one, deferred-fetch-minimal=();report-to=two", headers.get("permissions-policy-report-only") orelse return error.MissingReportingPolicy);
}

test "navigation preserves both combined permissions policy headers after response destruction" {
    try copyHeaders(std.testing.allocator);
}

test "navigation policy header projection cleans every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, copyHeaders, .{});
}
