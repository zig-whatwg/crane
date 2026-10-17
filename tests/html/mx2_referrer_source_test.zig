//! Referrer Policy 8.3: a srcdoc client's source is its first non-srcdoc
//! ancestor's document URL. The request snapshot must preserve that rule.
const std = @import("std");
const Browser = @import("browser").Browser;
const dom = @import("dom");
const runtime = @import("runtime");

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn readyDescendant(root: *runtime.Instance, depth: usize) ?*runtime.Instance {
    var window = root;
    for (0..depth) |_| {
        const context = dom.browser_state.browsingContextOf(window) orelse return null;
        if (context.children.items.len != 1) return null;
        const child = context.children.items[0].getActiveWindow() orelse return null;
        window = @ptrCast(@alignCast(child));
        const url = window.ctx.documentUrl() orelse return null;
        if (!std.mem.eql(u8, url, "about:srcdoc")) return null;
    }
    return window;
}

fn expectSource(url: []const u8, depth: usize) !void {
    const browser = try Browser.init(std.testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
    });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const html = switch (depth) {
        0 => "<!doctype html><body>",
        1 => "<!doctype html><iframe srcdoc='child'></iframe>",
        2 => "<!doctype html><iframe srcdoc=\"<iframe srcdoc='nested'></iframe>\"></iframe>",
        else => unreachable,
    };
    try page.loadHTML(html, .{ .base_url = url });
    const root = page.window_instance orelse return error.NoWindow;
    var descendant = readyDescendant(root, depth);
    for (0..100) |_| {
        if (descendant != null) break;
        _ = try browser.runEventLoopBlocking(50);
        descendant = readyDescendant(root, depth);
    }
    const window = descendant orelse return error.FramesDidNotLoad;
    var client = try dom.global_settings.requestClient(window);
    defer client.deinit();
    try std.testing.expectEqualStrings(url, client.request.referrer_source orelse return error.NoReferrerSource);
}

test "referrer source: an ordinary Window uses its own document URL" {
    try onThread(struct {
        fn body() !void {
            try expectSource("https://example.test/ordinary?source=own", 0);
        }
    }.body);
}

test "referrer source: srcdoc inherits the HTTP parent document URL" {
    try onThread(struct {
        fn body() !void {
            try expectSource("http://example.test/parent?source=http", 1);
        }
    }.body);
}

test "referrer source: srcdoc inherits the HTTPS parent document URL" {
    try onThread(struct {
        fn body() !void {
            try expectSource("https://example.test/parent?source=https", 1);
        }
    }.body);
}

test "referrer source: nested srcdoc reaches the first non-srcdoc ancestor" {
    try onThread(struct {
        fn body() !void {
            try expectSource("https://example.test/parent?source=nested", 2);
        }
    }.body);
}
