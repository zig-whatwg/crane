const std = @import("std");
const fetch = @import("fetch");

test "fetch timing preserves the request render-blocking value even when opaque" {
    const allocator = std.testing.allocator;
    for ([_]bool{ false, true }) |blocking| {
        const request = try fetch.internal.InternalRequest.init(allocator, "http://a.test/script.js");
        defer request.deinit();
        try request.setOrigin("http://a.test");
        request.render_blocking = blocking;
        const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
        defer job.destroy();
        try std.testing.expect(try job.start() == .network);
        try std.testing.expectEqual(blocking, job.timing_info.render_blocking);
        var opaque_timing = fetch.internal.fetch_timing.createOpaqueTimingInfo(allocator, &job.timing_info);
        defer opaque_timing.deinit();
        try std.testing.expectEqual(blocking, opaque_timing.render_blocking);
    }
}
