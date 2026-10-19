//! The cookie URL (lane sw1-b9): the URL document.cookie and the Cookie Store
//! API read and write cookies for is the one the document was created with -
//! a same-document change (history.pushState) does not move it - and an
//! about:blank or about:srcdoc document's is its creator's (its parent's).
//! The browsers' cookie URL: Blink DocumentInit::GetCookieUrl (the owner
//! document's for about:blank and srcdoc, fixed at creation), WebKit
//! Document::setCookieURL (in initSecurityContext; pushState's
//! updateURLForPushOrReplaceState leaves it). Cookie Store's spec text says
//! "creation URL", about:blank for such a frame; all three browsers pass
//! cookiestore/cookieStore_get_set_across_frames.https.html.
//!
//! The two-Browser case: two Browsers on two threads load the same page, and
//! each sets the same cookie name with its own value through its own
//! about:blank frame after a pushState: each reads back only its own.
//! Each Browser allocates from a DebugAllocator of its own
//! (docs/lessons/testing-a-shared-test-allocator-makes-two-browsers-take-turns.md).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "https://cookie-url.test/a/page.html";

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn waitFor(browser: *browser_mod.Browser, allocator: std.mem.Allocator, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    const context = browser.current_context orelse return error.TimedOut;
    const state = context.evaluateScriptToString("String(globalThis.state)", allocator) catch return error.TimedOut;
    defer allocator.free(state);
    std.debug.print("timed out waiting for: {s}\n  state: {s}\n", .{ source, state });
    return error.TimedOut;
}

fn loadPage(browser: *browser_mod.Browser, allocator: std.mem.Allocator) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body><iframe></iframe></body>", .{ .base_url = page_url });
    try waitFor(browser, allocator, "document.readyState === 'complete'");
}

/// Sets `name=value` for path /a/, moves the document's URL with pushState,
/// then reads the cookie every way: the page's document.cookie and
/// cookieStore, and its about:blank frame's. `globalThis.state` ends as the
/// readings, or the failure.
fn readingsScript(allocator: std.mem.Allocator, name: []const u8, value: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\globalThis.state = 'running';
        \\(async () => {{
        \\  const frame = document.querySelector('iframe').contentWindow;
        \\  frame.document.cookie = '{0s}={1s}; path=/a/';
        \\  history.pushState({{}}, '', '/b/other');
        \\  const page = await cookieStore.get('{0s}');
        \\  const inFrame = await frame.cookieStore.get('{0s}');
        \\  return [location.pathname, document.cookie, page && page.value, frame.document.cookie, inFrame && inFrame.value].join(' | ');
        \\}})().then(s => {{ globalThis.state = s; }}, e => {{ globalThis.state = 'failed ' + e; }});
    , .{ name, value });
}

test "the cookie URL is the document's at creation, and an about:blank frame's is its parent's" {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try loadPage(browser, testing.allocator);
    const source = try readingsScript(testing.allocator, "c", "1");
    defer testing.allocator.free(source);
    const started = try browser.evaluateScript(source);
    started.release();
    try waitFor(browser, testing.allocator, "globalThis.state !== 'running'");
    try waitFor(browser, testing.allocator, "globalThis.state === '/b/other | c=1 | 1 | c=1 | 1'");
    // The realm's record: its document URL moved, its creation URL did not.
    const realm = browser.getRealm() orelse return error.NoRealm;
    try testing.expectEqualStrings("https://cookie-url.test/b/other", realm.documentUrl().?);
    try testing.expectEqualStrings(page_url, realm.creationUrl().?);
    // replaceState and a fragment navigation are same-document changes too.
    const moved = try browser.evaluateScript("history.replaceState({}, '', '/c/replaced'); location.hash = 'f'; location.href");
    moved.release();
    try testing.expectEqualStrings("https://cookie-url.test/c/replaced#f", realm.documentUrl().?);
    try testing.expectEqualStrings(page_url, realm.creationUrl().?);
    try testing.expect(try truthy(browser, "document.cookie === 'c=1'"));
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    shared: *Shared,
    value: []const u8,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const allocator = self.debug_allocator.allocator();
        const browser = try startBrowser(allocator);
        defer browser.deinit();
        try loadPage(browser, allocator);
        // Both set the same name at once, each with its own value.
        try self.shared.meet(1);
        const source = try readingsScript(allocator, "shared", self.value);
        defer allocator.free(source);
        const started = try browser.evaluateScript(source);
        started.release();
        try waitFor(browser, allocator, "globalThis.state !== 'running'");
        const expected = try std.fmt.allocPrint(allocator, "globalThis.state === '/b/other | shared={0s} | {0s} | shared={0s} | {0s}'", .{self.value});
        defer allocator.free(expected);
        try waitFor(browser, allocator, expected);
        try self.shared.meet(2);
        _ = try browser.runEventLoopBlocking(20);
    }
};

test "two Browsers on two threads: each frame's cookie is its own Browser's, read at the creation URL" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared, .value = "A" }, .{ .shared = &shared, .value = "B" } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
