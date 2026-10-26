//! The host page's top-level traversable (lane newwin1): the navigable record
//! a Browser page keeps for its whole life - its top-level browsing context,
//! session history and WindowProxy record - across every Window its loads
//! make (HTML 7.3.1.2 "top-level traversables"; "create and initialize a
//! Document object" step 7). The Window that made the context hands it over;
//! the record frees it once every Window it showed is gone.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const html = @import("html");
const runtime = @import("runtime");

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
fn onFreshThread(comptime body: fn () anyerror!void) !void {
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
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn startBrowser() !*browser_mod.Browser {
    // No snapshot: the startup path JavaScriptCore runs on.
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// The page's traversable record, and its browsing context.
fn traversableOf(page: *browser_mod.Context) !*html.IFrameIntegration {
    return @ptrCast(@alignCast(page.traversable orelse return error.NoTraversable));
}

fn recordOwnsBrowsingContext() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    const record = try traversableOf(page);
    const window = page.window_instance orelse return error.TestUnexpectedResult;
    // The page's Window shows the record's browsing context, a top-level one
    // with no container.
    const shown = dom.browser_state.browsingContextOf(window) orelse return error.NoBrowsingContext;
    try testing.expectEqual(record.browsing_context.?, shown);
    try testing.expect(shown.parent == null);
    try testing.expect(record.iframe_element == null);
    try page.loadHTML("<!doctype html><p>one</p>", .{ .base_url = "http://example.test/one" });
    try testing.expectEqual(record.browsing_context.?, dom.browser_state.browsingContextOf(page.window_instance.?).?);
    // A fresh traversable for the next page: the record of the first goes
    // with its Context - freed once, after its Window (std.testing.allocator
    // and the debug allocator's double-free check say so).
    try browser.navigate("about:blank", .window);
    const next = browser.current_context orelse return error.TestUnexpectedResult;
    _ = try traversableOf(next);
}

test "the host page's top-level browsing context belongs to its traversable record, freed once after its Window" {
    try onFreshThread(recordOwnsBrowsingContext);
}
