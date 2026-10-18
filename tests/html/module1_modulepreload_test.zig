//! <link rel=modulepreload> puts its module into the document's module map
//! (HTML 4.6.8.12 step 14, "fetch a modulepreload module script graph"): a
//! later import() of the URL takes it from there - one request, made under
//! the link's referrer policy, not the import's - and an import while the
//! preload is in flight joins its fetch. The load event still fires, and a
//! module the map already holds is not fetched by a modulepreload again.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/preloaded.js", .echo_referrer = true },
    .{ .path = "/slow-preloaded.js", .delay_ms = 300, .echo_referrer = true },
    .{ .path = "/plain.js", .echo_referrer = true },
    .{ .path = "/not-js.txt", .content_type = "text/plain", .body = "not a module" },
};

const page_url = "http://module1.test/dir/page.html";

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, std.testing.allocator);
}

fn waitForAnswer(browser: *Browser) ![]u8 {
    for (0..500) |_| {
        const answer = try evaluate(browser, "answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        std.testing.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn run() !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(std.testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });

    const started = try evaluate(browser,
        \\globalThis.answer = 'pending';
        \\const preload = (href, policy) => new Promise(resolve => {
        \\  const link = document.createElement('link');
        \\  link.rel = 'modulepreload';
        \\  link.href = href;
        \\  if (policy) link.referrerPolicy = policy;
        \\  link.onload = () => resolve('load');
        \\  link.onerror = () => resolve('error');
        \\  document.head.appendChild(link);
        \\});
        \\(async () => {
        \\  const results = [];
        \\  // Preloaded under no-referrer, then imported: the map's module.
        \\  results.push(await preload('/preloaded.js', 'no-referrer'));
        \\  results.push(JSON.stringify((await import('/preloaded.js')).default));
        \\  // Imported while the preload is in flight: its fetch, joined.
        \\  const slow = preload('/slow-preloaded.js', 'origin');
        \\  results.push(JSON.stringify((await import('/slow-preloaded.js')).default));
        \\  results.push(await slow);
        \\  // A module already in the map: the preload fetches nothing.
        \\  results.push(JSON.stringify((await import('/plain.js')).default));
        \\  results.push(await preload('/plain.js', 'no-referrer'));
        \\  // Not a JavaScript MIME type: no module script, error.
        \\  results.push(await preload('/not-js.txt'));
        \\  answer = results.join('|');
        \\})().catch(e => { answer = 'threw:' + e; });
        \\'ok'
    );
    defer std.testing.allocator.free(started);
    try std.testing.expectEqualStrings("ok", started);
    const answer = try waitForAnswer(browser);
    defer std.testing.allocator.free(answer);
    try std.testing.expectEqualStrings(
        \\load|""|"http://module1.test/"|load|"http://module1.test/dir/page.html"|load|error
    , answer);
    try std.testing.expectEqual(@as(u32, 1), server.count("/preloaded.js"));
    try std.testing.expectEqual(@as(u32, 1), server.count("/slow-preloaded.js"));
    try std.testing.expectEqual(@as(u32, 1), server.count("/plain.js"));
}

test "modulepreload: the module enters the module map, and import() takes it from there" {
    const Run = struct {
        failure: ?anyerror = null,
        fn go(self: *@This()) void {
            run() catch |err| {
                self.failure = err;
            };
        }
    };
    var state: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.go, .{&state});
    thread.join();
    if (state.failure) |err| return err;
}
