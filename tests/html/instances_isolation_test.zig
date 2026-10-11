//! Instances B3 (tmp/plans/instances-design.md sections 4.2 and 6.1): the web's
//! shared state - the storage shed, the blob URL store, the cookie jar and its
//! change listeners - is a Browser's, a supplement of its scope
//! (runtime.BrowserScope), never the process's or a thread's.
//!
//! Two whole Browsers cannot be alive at once until instances B1 gives each
//! its own slab and arena (runtime.initializeRuntime is still process-wide),
//! so these tests prove isolation two ways (integrator, 2026-10-10):
//!
//! - scope level: two Browsers' scopes on two threads reach each store
//!   through the supplement the binding reaches (realm.browser_scope ->
//!   scope.of(T)), one origin - nothing is shared, and one scope's users do
//!   share;
//! - Browser level, sequential: Browser A writes and ends; Browser B, on the
//!   same thread and on a fresh one, sees none of it - which a store that
//!   outlives its Browser (a process global) fails.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const html_core = @import("html_core");
const engine = @import("engine");

const web_storage = html_core.web_storage;
const UserAgentStorage = web_storage.UserAgentStorage;

/// One origin for every Browser: the storage key both would share if the
/// store were the process's.
const origin = "http://inst3.test";
const page_url = "http://inst3.test/page.html";

/// Run `function` with `args` on a thread of its own, and return its error.
fn onThread(comptime function: anytype, args: anytype) !void {
    const Run = struct {
        fn run(failure: *?anyerror, call_args: @TypeOf(args)) void {
            @call(.auto, function, call_args) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ &failure, args });
    thread.join();
    if (failure) |err| return err;
}

// ============================================================================
// Browser level: a page of `origin` in a Browser of its own
// ============================================================================

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// Show a page of `origin` (no network: the page's markup is given).
fn openPage(browser: *browser_mod.Browser) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
}

/// `source`'s completion value, ToBoolean'd, in the page's realm.
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

// ============================================================================
// localStorage: the Browser's storage shed
// ============================================================================

fn setLocal(scope: *runtime.BrowserScope, key: []const u8, value: []const u8) !void {
    const user_agent_storage = try scope.of(UserAgentStorage);
    var storage = try web_storage.getLocalStorage(testing.allocator, user_agent_storage, origin);
    defer storage.deinit();
    try storage.setItem(key, value);
}

fn expectLocal(scope: *runtime.BrowserScope, key: []const u8, expected: ?[]const u8) !void {
    const user_agent_storage = try scope.of(UserAgentStorage);
    var storage = try web_storage.getLocalStorage(testing.allocator, user_agent_storage, origin);
    defer storage.deinit();
    const actual = storage.getItem(key);
    if (expected) |value| {
        try testing.expectEqualStrings(value, actual orelse return error.ItemMissing);
    } else {
        try testing.expect(actual == null);
    }
}

test "localStorage: two Browsers' scopes on two threads share no storage shed; one scope's storage areas do" {
    var scope_a = runtime.BrowserScope.init(testing.allocator);
    defer scope_a.deinit();
    var scope_b = runtime.BrowserScope.init(testing.allocator);
    defer scope_b.deinit();

    try onThread(setLocal, .{ &scope_a, "k", "a" });
    // B, on a thread of its own, sees nothing of A's - and writes its own.
    try onThread(expectLocal, .{ &scope_b, "k", null });
    try onThread(setLocal, .{ &scope_b, "k", "b" });
    // A's own storage areas, made anew, share its shed: A's value, not B's.
    try onThread(expectLocal, .{ &scope_a, "k", "a" });
    try onThread(expectLocal, .{ &scope_b, "k", "b" });
}

fn localStorageEndsWithItsBrowser() !void {
    {
        const browser = try startBrowser();
        defer browser.deinit();
        try openPage(browser);
        try expectScript(browser, "localStorage.getItem('k') === null");
        try expectScript(browser, "localStorage.setItem('k', 'a'); true");
        // The same Browser's next page of the origin shares the shed.
        try openPage(browser);
        try expectScript(browser, "localStorage.getItem('k') === 'a'");
    }
    // The next Browser on this thread starts with an empty shed.
    {
        const browser = try startBrowser();
        defer browser.deinit();
        try openPage(browser);
        try expectScript(browser, "localStorage.getItem('k') === null");
        try expectScript(browser, "localStorage.setItem('k', 'b'); true");
    }
}

fn localStorageEmptyInAFreshBrowser() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try openPage(browser);
    try expectScript(browser, "localStorage.getItem('k') === null");
}

test "localStorage: a Browser's shed ends with it - the next Browser, on its thread or another, sees none of it" {
    try onThread(localStorageEndsWithItsBrowser, .{});
    try onThread(localStorageEmptyInAFreshBrowser, .{});
}
