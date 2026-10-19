//! Empty HTTP script responses still have a successful byte sequence.
//! Exercise the production classic-worker import fetch against a local
//! proxy, with missing-resource and non-JavaScript controls.
const std = @import("std");
const Browser = @import("browser").Browser;
const html = @import("html");
const http = @import("module1_http_server.zig");

fn exercise() !void {
    const allocator = std.testing.allocator;
    const routes = [_]http.Route{
        .{ .path = "/empty.js" },
        .{ .path = "/empty.txt", .content_type = "text/plain" },
        .{ .path = "/body.js", .body = "/* a script */" },
    };
    const server = try http.Server.start(allocator, &routes);
    defer server.stop();
    var proxy_buffer: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buffer);
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions("http://wf1.test/page.html", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "http://wf1.test/page.html" });
    const realm = browser.getRealm() orelse return error.NoRealm;

    // An unsupported scheme fails Fetch itself, independently of MIME and
    // HTTP status validation below.
    try std.testing.expectError(error.NetworkError, html.worker_host.fetchClassicWorkerImportedScript(realm, "wf1-unsupported:script"));

    // The fetch helper reads the client's settings through the same API
    // for a Window and a worker. The Crane fixture covers an actual worker.
    var empty = try html.worker_host.fetchClassicWorkerImportedScript(realm, "http://wf1.test/empty.js");
    defer empty.deinit();
    try std.testing.expectEqualStrings("", empty.source);
    try std.testing.expectEqualStrings("http://wf1.test/empty.js", empty.url);
    try std.testing.expectEqual(@as(u32, 1), server.count("/empty.js"));

    var body = try html.worker_host.fetchClassicWorkerImportedScript(realm, "http://wf1.test/body.js");
    defer body.deinit();
    try std.testing.expectEqualStrings("/* a script */", body.source);
    try std.testing.expectError(error.NetworkError, html.worker_host.fetchClassicWorkerImportedScript(realm, "http://wf1.test/empty.txt"));
    try std.testing.expectError(error.NetworkError, html.worker_host.fetchClassicWorkerImportedScript(realm, "http://wf1.test/missing.js"));
}

test "classic worker import accepts empty JavaScript and rejects bad MIME or HTTP failure" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
