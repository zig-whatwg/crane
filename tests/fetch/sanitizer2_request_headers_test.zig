//! Fetch's outgoing header fields combine values under the first name's case.
const std = @import("std");
const fetch = @import("fetch");
const http = fetch.algorithms.http_fetch;

fn sendHeaders(allocator: std.mem.Allocator, first: []const u8, second: []const u8) !void {
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/echo");
    defer request.deinit();
    try request.header_list.append(first, "one");
    try request.header_list.append("X-Unrelated", "middle");
    try request.header_list.append(second, "two");
    try request.header_list.append(first, "");
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    // Retries must not combine values back into the script-visible list.
    for (0..2) |_| {
        const started = try http.httpNetworkOrCacheFetchStart(allocator, params, .{});
        const network = started.network;
        defer http.freeNetworkRequest(allocator, network);
        var matches: usize = 0;
        for (network.headers) |header| {
            if (!std.ascii.eqlIgnoreCase(header.name, first)) continue;
            matches += 1;
            try std.testing.expectEqualStrings(first, header.name);
            try std.testing.expectEqualStrings("one, two, ", header.value);
        }
        try std.testing.expectEqual(@as(usize, 1), matches);
        try std.testing.expectEqual(@as(usize, 4), request.header_list.len());
        try std.testing.expectEqualStrings("one", request.header_list.entries.items[0].value);
        try std.testing.expectEqualStrings("two", request.header_list.entries.items[2].value);
    }
}

test "network request combines repeated values in order and keeps the first header name's case" {
    try sendHeaders(std.testing.allocator, "THIS-is-A-test", "THIS-IS-A-TEST");
    try sendHeaders(std.testing.allocator, "THIS-IS-A-TEST", "THIS-is-A-test");
}

test "combining outgoing headers releases partial allocations on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, sendHeaders, .{ "X-Test", "x-test" });
}
