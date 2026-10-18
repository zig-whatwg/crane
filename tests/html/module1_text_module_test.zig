//! Text module scripts (HTML "create a text module script",
//! whatwg/html#11933): `import t from "./a.txt" with { type: "text" }` and
//! import() with the same attribute, in a Window and in a module worker.
//!
//! The body is UTF-8 decoded whatever its Content-Type (here
//! application/octet-stream and application/json), a UTF-8 BOM is dropped,
//! a bad byte is U+FFFD, the request's Accept header is the "text"
//! destination's, and a JavaScript import of the same URL is a different
//! module map entry, which the MIME type check still fails.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/file.txt", .content_type = "application/octet-stream", .body = "text file\n" },
    .{ .path = "/data.json", .content_type = "application/json", .body = "{\"a\": 1}" },
    .{ .path = "/bom.txt", .content_type = "text/plain", .body = "\xEF\xBB\xBFtext file\n" },
    .{ .path = "/utf16.txt", .content_type = "text/plain", .body = "\xFE\xFF\x00t" },
    .{ .path = "/accept", .content_type = "text/plain", .echo_accept = true },
};

const page_url = "http://module1.test/page.html";

/// The imports, from wherever `base` is: each result lands in `out`.
const imports_script =
    \\globalThis.runTextImports = async (base, out) => {
    \\  const text = async (path) => (await import(base + path, { with: { type: 'text' } })).default;
    \\  try {
    \\    out.plain = await text('/file.txt');
    \\    out.json = await text('/data.json');
    \\    out.bom = await text('/bom.txt');
    \\    out.utf16 = [...await text('/utf16.txt')].map(c => c.codePointAt(0));
    \\    out.accept = await text('/accept');
    \\    out.again = (await text('/file.txt')) === out.plain;
    \\    try { await import(base + '/file.txt'); out.js = 'loaded'; } catch (e) { out.js = e.name; }
    \\  } catch (e) {
    \\    out.error = String(e);
    \\  }
    \\  return out;
    \\};
;

const expected =
    \\{"plain":"text file\n","json":"{\"a\": 1}","bom":"text file\n","utf16":[65533,65533,0,116],"accept":"text/plain,*/*;q=0.5","again":true,"js":"TypeError"}
;

fn evaluate(page: anytype, source: []const u8) ![]u8 {
    return page.evaluateScriptToString(source, std.testing.allocator);
}

fn waitForString(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    for (0..500) |_| {
        const answer = try evaluate(page, source);
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        std.testing.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn startBrowser(server: *http.Server) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(std.testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    return browser;
}

fn windowImports() !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(server);
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // A static import from a module script element, beside the dynamic ones.
    try page.loadHTML(
        \\<!doctype html><body>
        \\<script type=module>
        \\import t from "/file.txt" with { type: "text" };
        \\globalThis.staticText = t;
        \\</script>
    , .{ .base_url = page_url });
    const ready = try evaluate(page, imports_script ++ "globalThis.out = {}; runTextImports('http://module1.test', {}).then(o => { globalThis.out = o; globalThis.done = true; }); 'ok'");
    defer std.testing.allocator.free(ready);
    try std.testing.expectEqualStrings("ok", ready);

    const answer = try waitForString(browser, "globalThis.done && typeof staticText === 'string' ? JSON.stringify(out) : 'pending'");
    defer std.testing.allocator.free(answer);
    try std.testing.expectEqualStrings(expected, answer);
    const static_text = try evaluate(page, "staticText");
    defer std.testing.allocator.free(static_text);
    try std.testing.expectEqualStrings("text file\n", static_text);
    // The second text import of /file.txt was a module map hit; the
    // JavaScript import of it is its own entry, so it fetched.
    try std.testing.expectEqual(@as(u32, 2), server.count("/file.txt"));
}

fn workerImports(worker_type: []const u8) !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const browser = try startBrowser(server);
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    const defined = try evaluate(page, imports_script ++ "'ok'");
    defer std.testing.allocator.free(defined);
    try std.testing.expectEqualStrings("ok", defined);
    const launch = try std.fmt.allocPrint(std.testing.allocator,
        \\globalThis.answer = 'pending';
        \\{{
        \\  const source = `globalThis.runTextImports = ${{runTextImports}};
        \\    runTextImports('http://module1.test', {{}}).then(o => postMessage(JSON.stringify(o)));`;
        \\  const url = URL.createObjectURL(new Blob([source], {{ type: 'text/javascript' }}));
        \\  const worker = new Worker(url, {{ type: '{s}' }});
        \\  worker.onmessage = e => {{ answer = e.data; worker.terminate(); }};
        \\  worker.onerror = () => {{ answer = 'worker-error'; }};
        \\}}
        \\'ok'
    , .{worker_type});
    defer std.testing.allocator.free(launch);
    const ready = try evaluate(page, launch);
    defer std.testing.allocator.free(ready);
    try std.testing.expectEqualStrings("ok", ready);
    const answer = try waitForString(browser, "answer");
    defer std.testing.allocator.free(answer);
    try std.testing.expectEqualStrings(expected, answer);
}

fn onThread(comptime body: anytype, args: anytype) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This(), a: @TypeOf(args)) void {
            @call(.auto, body, a) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{ &run, args });
    thread.join();
    if (run.failure) |err| return err;
}

test "text module scripts: static and dynamic imports in a Window" {
    try onThread(windowImports, .{});
}

test "text module scripts: import() in a module worker" {
    try onThread(workerImports, .{"module"});
}

test "text module scripts: import() in a classic worker" {
    try onThread(workerImports, .{"classic"});
}
