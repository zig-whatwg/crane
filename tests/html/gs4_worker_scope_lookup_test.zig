//! A worker realm's host (html.worker_host WorkerHost) is found from the
//! realm itself, on any thread (lane gstate4): it was one list per thread,
//! searched by realm, so a lookup from any thread but the worker's own found
//! nothing (docs/lessons/architecture-a-threadlocal-listener-list-splits-a-browser-when-its-work-moves-threads.md).
const std = @import("std");
const runtime = @import("runtime");
const worker_host = @import("html").worker_host;
const cases = worker_host.scope_lookup_test_cases;

fn askFromAnotherThread(realm: runtime.Context) !void {
    const Other = struct {
        fn ask(r: runtime.Context, url: *?[]const u8) void {
            url.* = if (worker_host.scopeSettings(r)) |settings| settings.url else null;
        }
    };
    var url: ?[]const u8 = null;
    const thread = try std.Thread.spawn(.{}, Other.ask, .{ realm, &url });
    thread.join();
    try std.testing.expectEqualStrings(cases.worker_url, url orelse return error.HostNotFoundFromAnotherThread);
}

test "a worker realm's host is found from the realm on another thread" {
    try cases.withRecordedHost(&askFromAnotherThread);
}
