//! A cached response keeps its timing allow passed flag (Chromium's
//! cache_storage.proto stores timing_allow_passed): a service worker that
//! answers from Cache Storage hands the client the flag its own fetch of the
//! response set (resource-timing-cross-origin-server-timing.https.html,
//! "Redirect where all hops have TAO via Cache Storage").
const std = @import("std");
const testing = std.testing;
const records = @import("service_worker").cache.records;

test "a cached response's timing allow passed flag survives encode and decode" {
    for ([_]bool{ true, false }) |passed| {
        var url = "https://a.test/r".*;
        var method = "GET".*;
        const entry: records.Entry = .{
            .request = .{ .url = &url, .method = &method },
            .response = .{ .response_type = 2, .timing_allow_passed = passed },
        };
        const bytes = try records.encode(testing.allocator, &entry);
        defer testing.allocator.free(bytes);
        var decoded = try records.decode(testing.allocator, bytes);
        defer decoded.deinit(testing.allocator);
        try testing.expectEqual(passed, decoded.response.timing_allow_passed);
    }
}
