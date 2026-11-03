//! A module script's [[HostDefined]] - what import.meta and an import() in
//! it read - is looked up among its AGENT's module scripts
//! (`AgentHost.module_scripts`, lane gstate4): only the agent's own realms
//! run its modules' code, so only they hand one of its records back. The
//! list was one process-wide list under a mutex, every Browser's and every
//! worker's module scripts in it, walked on every import.meta and import().
//!
//! Two Browsers on one thread each run module scripts: each agent's list
//! holds its own scripts only, and one Browser's end leaves the other's
//! module code reading its import.meta.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 300) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

/// A page whose inline module scripts keep a function reading their
/// import.meta.url.
fn openModulePage(browser: *browser_mod.Browser, url: []const u8, modules: usize) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    var markup: std.ArrayListUnmanaged(u8) = .empty;
    defer markup.deinit(testing.allocator);
    try markup.appendSlice(testing.allocator, "<!doctype html><body><script>globalThis.urls = [];</script>");
    for (0..modules) |_| try markup.appendSlice(testing.allocator, "<script type=module>urls.push(() => import.meta.url);</script>");
    try markup.appendSlice(testing.allocator, "</body>");
    try page.loadHTML(markup.items, .{ .base_url = url });
    var buffer: [96]u8 = undefined;
    try waitFor(browser, try std.fmt.bufPrint(&buffer, "globalThis.urls.length === {d}", .{modules}));
}

fn countOf(browser: *browser_mod.Browser) usize {
    var n: usize = 0;
    var it = browser.agent_host.module_scripts.first();
    while (it) |link| : (it = link.next()) n += 1;
    return n;
}

fn eachAgentKeepsItsOwnModuleScripts() !void {
    const a = try startBrowser();
    defer a.deinit();
    try openModulePage(a, "http://gs4-a.test/page.html", 3);
    const a_count = countOf(a);
    try testing.expect(a_count >= 3);

    {
        const b = try startBrowser();
        defer b.deinit();
        try openModulePage(b, "http://gs4-b.test/page.html", 5);
        try testing.expect(countOf(b) >= 5);
        // B's module scripts are B's agent's: A's list did not grow.
        try testing.expectEqual(a_count, countOf(a));
        try expectScript(b, "urls.every((url) => url() === 'http://gs4-b.test/page.html')");
    }

    // B's end freed only B's: A's module code still reads its import.meta.
    try testing.expectEqual(a_count, countOf(a));
    try expectScript(a, "urls.every((url) => url() === 'http://gs4-a.test/page.html')");
}

test "each agent keeps its own module scripts, and another Browser's end leaves them" {
    try onFreshThread(eachAgentKeepsItsOwnModuleScripts);
}
