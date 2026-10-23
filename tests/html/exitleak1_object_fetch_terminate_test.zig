//! An <object> element whose fetch is still in flight when it is removed
//! frees what the fetch record held (lane exitleak1).
//!
//! The fetch record keeps a copy of the URL it fetches; the fetch's own end
//! frees it (Fetch.finish), but terminating the fetch - the element removed,
//! its data changed, its document aborted or destroyed - destroyed the record
//! and leaked the copy. The WPT runner reported it at exit after
//! resource-timing/nested-nav-fallback-timing.html (main's sweep: one
//! `leaked:` in shard abl/6), whose cleanup removes an <object> while its
//! slow page is still loading.
//!
//! The page comes from a loopback HTTP server (module1_http_server.zig)
//! through the Browser's proxy, answering late.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const host_url = "http://exitleak1.test/host.html";

const routes = [_]http.Route{
    .{ .path = "/slow.html", .content_type = "text/html", .body = "<!doctype html><p>slow", .delay_ms = 300 },
};

test "removing an <object> whose fetch is in flight leaves nothing of the fetch behind" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body><script>
        \\  var object = document.createElement('object');
        \\  object.type = 'text/html';
        \\  object.data = '/slow.html';
        \\  document.body.appendChild(object);
        \\</script>
    , .{ .base_url = host_url });
    // The element's processing starts its fetch from a task.
    var turns: usize = 0;
    while (turns < 100 and server.count("/slow.html") == 0) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
    try testing.expectEqual(@as(u32, 1), server.count("/slow.html"));
    // Removed while the response is still on its way: the fetch is
    // terminated.
    try page.runScript("object.remove();");
    turns = 0;
    while (turns < 50) : (turns += 1) _ = try browser.runEventLoopBlocking(10);
    // browser.deinit (deferred): testing.allocator reports what is not freed.
}
