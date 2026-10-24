//! Q18 control: navigation keeps its existing blob lookup until streamnav
//! carries the parsed entry's opaque identity into its reserved client.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const result = try browser.evaluateScript(source);
    defer result.release();
    return engine.toBoolean(browser.getRealm() orelse return error.NoRealm, result.borrow());
}

fn run() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "http://xw1.test/page.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    try std.testing.expect(try truthy(browser,
        \\(() => {
        \\  globalThis.xw1Loaded = false;
        \\  addEventListener('message', e => { if (e.data === 'xw1-blob-loaded') xw1Loaded = true; });
        \\  const outer = document.createElement('iframe');
        \\  outer.sandbox = 'allow-scripts';
        \\  outer.srcdoc = '<body><script>' +
        \\    "addEventListener('message', e => parent.postMessage(e.data, '*'));" +
        \\    "const f = document.createElement('iframe');" +
        \\    "const end = String.fromCharCode(60) + '/script>';" +
        \\    "const blob = new Blob(['<script>parent.postMessage(\"xw1-blob-loaded\", \"*\");' + end], {type:'text/html'});" +
        \\    "f.src = URL.createObjectURL(blob); document.body.append(f);" +
        \\    String.fromCharCode(60) + '/script>';
        \\  document.body.append(outer);
        \\  return true;
        \\})()
    ));
    for (0..1000) |_| {
        if (try truthy(browser, "xw1Loaded")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.BlobFrameDidNotLoad;
}

test "xw1 an opaque frame can still navigate its child to a blob URL" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn start(out: *anyerror!void) void {
            out.* = run();
        }
    }.start, .{&result});
    thread.join();
    try result;
}
