//! A worker's origin is the URL Standard's origin of its URL - what its
//! settings object, self.origin and location.origin all read
//! (src/html/workers/worker_location.zig). html_core's own test blocks run
//! under no test target, so the cases live here.

const std = @import("std");
const html_core = @import("html_core");
const WorkerLocation = html_core.workers.worker_location.WorkerLocation;

fn originOf(url: []const u8) ![]u8 {
    const location = try WorkerLocation.init(std.testing.allocator, url);
    defer location.deinit();
    return std.testing.allocator.dupe(u8, location.getOrigin());
}

test "a worker's origin: a tuple, a blob: URL's path origin, and opaque for data:" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "http://web-platform.test:8000/workers/w.js", "http://web-platform.test:8000" },
        .{ "https://a.test:443/w.js", "https://a.test" },
        // A blob: worker is its creator's origin - not "blob:http://...".
        .{ "blob:http://web-platform.test:8000/4c1f-uuid", "http://web-platform.test:8000" },
        .{ "data:text/javascript,postMessage(1)", "null" },
    };
    for (cases) |case| {
        const origin = try originOf(case[0]);
        defer allocator.free(origin);
        try std.testing.expectEqualStrings(case[1], origin);
    }
}
