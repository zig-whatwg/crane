//! Fetch step 14 adds the platform's preferred language before main fetch.
const std = @import("std");
const fetch = @import("fetch");

fn languageAfterStart(preset: ?[]const u8) ![]u8 {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://a.test/x");
    defer request.deinit();
    try request.setOrigin("http://a.test");
    if (preset) |value| try request.header_list.append("aCcEpT-lAnGuAgE", value);
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    _ = try job.start();
    const value = request.header_list.getFirstValue("Accept-Language") orelse return error.TestExpectedAcceptLanguage;
    return allocator.dupe(u8, value);
}

test "fetch adds the most preferred platform language when Accept-Language is absent" {
    const allocator = std.testing.allocator;
    // The testing platform supplies en-US (platform/kit/posix/root.zig).
    const actual = try languageAfterStart(null);
    defer allocator.free(actual);
    try std.testing.expectEqualStrings("en-US", actual);
}

test "fetch preserves an explicitly supplied Accept-Language including the empty value" {
    for ([_][]const u8{ "bzh", "", "fr, en;q=0.7" }) |preset| {
        const actual = try languageAfterStart(preset);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(preset, actual);
    }
}

test "fetch releases the default language and request on allocation failure" {
    try allocationPath(std.testing.allocator);
    var failure_index: usize = 0;
    while (true) : (failure_index += 1) {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure_index });
        allocationPath(failing.allocator()) catch |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
        };
        // Existing main-fetch paths can turn an allocation failure into a
        // network-error response. Exercise their cleanup too, without making
        // this header test require a different error policy from all of Fetch.
        if (!failing.has_induced_failure) break;
    }
}

fn allocationPath(allocator: std.mem.Allocator) !void {
    const request = try fetch.internal.InternalRequest.init(allocator, "data:text/plain,body");
    defer request.deinit();
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    switch (try job.start()) {
        .done => {
            var owned = job.takeResult();
            owned.deinit();
        },
        else => return error.TestUnexpectedResult,
    }
}
