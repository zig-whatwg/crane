//! Two Browsers on two threads (lane partition1): each shows a page on a
//! top-level site of its own (http://top-a.test, http://top-b.test) that
//! embeds a frame of ONE origin, http://inner.test. The frame writes
//! localStorage and sessionStorage and makes a blob URL. Nothing crosses
//! between the Browsers - each frame finds empty storage - and, inside each
//! Browser, nothing crosses between partitions: the top page cannot fetch the
//! frame's blob URL (another origin), and http://inner.test shown at the top
//! level - its first-party partition - finds none of what it wrote as a
//! third party. Every storage key is computed per environment from its own
//! realm's state (dom.global_settings), never from shared state.
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! each Browser's proxy. Each Browser allocates from a DebugAllocator of its
//! own (docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const routes = [_]http.Route{
    .{ .path = "/top.html", .content_type = "text/html", .body =
    \\<!doctype html><script>
    \\var heard = [];
    \\addEventListener('message', e => heard.push(e.data));
    \\</script><iframe src="http://inner.test/frame.html"></iframe>
    },
    .{ .path = "/frame.html", .content_type = "text/html", .body =
    \\<!doctype html><script>
    \\const before = [localStorage.getItem('k'), sessionStorage.getItem('k')];
    \\localStorage.setItem('k', 'third-party');
    \\sessionStorage.setItem('k', 'third-party');
    \\const url = URL.createObjectURL(new Blob(['frame blob']));
    \\fetch(url).then(r => r.text()).then(text => parent.postMessage({before, url, text}, '*'),
    \\  () => parent.postMessage({before, url, text: 'failed'}, '*'));
    \\</script>
    },
    .{ .path = "/first.html", .content_type = "text/html", .body =
    \\<!doctype html><script>
    \\var firstParty = [localStorage.getItem('k'), sessionStorage.getItem('k')];
    \\</script>
    },
};

fn truthy(browser: *Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

const Side = struct {
    top: []const u8,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const allocator = self.debug_allocator.allocator();
        const server = try http.Server.start(allocator, &routes);
        defer server.stop();
        var proxy_buf: [64]u8 = undefined;
        const proxy = try server.proxyUrl(&proxy_buf);
        const browser = try Browser.init(allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        defer browser.deinit();

        var url_buf: [64]u8 = undefined;
        try browser.navigate(try std.fmt.bufPrint(&url_buf, "{s}/top.html", .{self.top}), .window);
        try waitFor(browser, "heard.length === 1");
        // The frame found no storage: not the other Browser's, though it is
        // the same origin, and none of its own yet.
        try expectScript(browser, "heard[0].before[0] === null && heard[0].before[1] === null");
        // The frame obtains its own blob URL's blob ...
        try expectScript(browser, "heard[0].text === 'frame blob'");
        // ... and the top page - another origin - does not.
        const started = try browser.evaluateScript("globalThis.topFetch = 'pending'; fetch(heard[0].url).then(() => { topFetch = 'fetched'; }, () => { topFetch = 'failed'; }); true");
        started.release();
        try waitFor(browser, "topFetch !== 'pending'");
        try expectScript(browser, "topFetch === 'failed'");

        // http://inner.test as the top-level page: its first-party partition,
        // which holds nothing the frame wrote under this top-level site.
        try browser.navigate("http://inner.test/first.html", .window);
        try waitFor(browser, "typeof firstParty !== 'undefined'");
        try expectScript(browser, "firstParty[0] === null && firstParty[1] === null");
    }
};

test "two Browsers on two threads: one frame origin under two top-level sites shares no storage and no blob URL" {
    var a: Side = .{ .top = "http://top-a.test" };
    var b: Side = .{ .top = "http://top-b.test" };
    const thread_a = try std.Thread.spawn(.{}, Side.run, .{&a});
    const thread_b = try std.Thread.spawn(.{}, Side.run, .{&b});
    thread_a.join();
    thread_b.join();
    if (a.failure) |err| return err;
    if (b.failure) |err| return err;
}
