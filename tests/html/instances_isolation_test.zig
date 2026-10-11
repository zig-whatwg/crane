//! Instances B3 (tmp/plans/instances-design.md sections 4.2 and 6.1): the web's
//! shared state - the storage shed, the blob URL store, the cookie jar and its
//! change listeners - is a Browser's, a supplement of its scope
//! (runtime.BrowserScope), never the process's or a thread's.
//!
//! These tests (inst3, written before instances B1 gave each Browser its own
//! slab and arena) prove isolation two ways (integrator, 2026-10-10); the
//! concurrent two-Browser tests are tests/html/instances_concurrent_test.zig:
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
const interfaces = @import("interfaces");
const file = @import("file");
const fetch = @import("fetch");

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

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(20);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
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

// ============================================================================
// Blob URLs: the Browser's blob URL store
// ============================================================================

fn makeBlobURL(scope: *runtime.BrowserScope, url: *[]u8) !void {
    const store = try scope.of(file.BlobURLStore);
    const blob = try file.BlobData.init(testing.allocator, "hello", "text/plain");
    defer blob.deinit();
    url.* = try store.createObjectURL(blob, origin, null);
}

/// Scheme fetch "blob" of `url`, for a request of `origin` whose client's
/// Browser is `scope`'s: `expected` is its body, or null for a network error.
fn fetchBlob(scope: *runtime.BrowserScope, url: []const u8, expected: ?[]const u8) !void {
    const request = try fetch.internal.InternalRequest.init(testing.allocator, url);
    defer request.deinit();
    try request.setOrigin(origin);
    request.blob_url_store = try scope.of(file.BlobURLStore);
    switch (try fetch.algorithms.scheme_fetch.schemeFetchRequest(testing.allocator, request)) {
        .response => |response| {
            defer response.deinit();
            try testing.expectEqualStrings(expected orelse return error.ExpectedANetworkError, response.body.?.getBytes());
        },
        .network_error => if (expected != null) return error.UnexpectedNetworkError,
    }
}

test "blob URLs: two Browsers' scopes on two threads share no blob URL store; a scope's own requests resolve its URLs" {
    // Scheme fetch "blob"'s resolver, installed once for the process.
    interfaces.process_hooks.startHooksForTest();
    var scope_a = runtime.BrowserScope.init(testing.allocator);
    defer scope_a.deinit();
    var scope_b = runtime.BrowserScope.init(testing.allocator);
    defer scope_b.deinit();

    var url: []u8 = undefined;
    try onThread(makeBlobURL, .{ &scope_a, &url });
    defer testing.allocator.free(url);
    try onThread(fetchBlob, .{ &scope_b, url, null });
    try onThread(fetchBlob, .{ &scope_a, url, "hello" });
}

fn blobURLsResolveInTheirBrowserOnly() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try openPage(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;

    _ = realm;

    // A blob URL another Browser's store made, for the same origin, handed
    // to this page as a string. (Not by lending the page's realm another
    // Browser's scope for a script: since instances B1 a realm's objects
    // come from its scope's slab, so that script's Blob would be the other
    // Browser's object, freed with it while this page still held it.)
    var other = runtime.BrowserScope.init(testing.allocator);
    defer other.deinit();
    var other_url: []u8 = undefined;
    {
        const store = try other.of(file.BlobURLStore);
        const blob = try file.BlobData.init(testing.allocator, "other", "text/plain");
        defer blob.deinit();
        other_url = try store.createObjectURL(blob, origin, null);
    }
    defer testing.allocator.free(other_url);
    var buffer: [256]u8 = undefined;
    try expectScript(browser, try std.fmt.bufPrint(&buffer, "globalThis.other_url = '{s}'; true", .{other_url}));

    try expectScript(browser, "globalThis.own_url = URL.createObjectURL(new Blob(['own'])); true");
    try expectScript(browser,
        \\globalThis.results = {};
        \\for (const [key, url] of [['other', other_url], ['own', own_url]])
        \\  fetch(url).then(r => r.text()).then(t => results[key] = t, () => results[key] = 'network error');
        \\true
    );
    try waitFor(browser, "'other' in results && 'own' in results");
    // The other Browser's URL is a network error here; this Browser's own
    // resolves.
    try expectScript(browser, "results.other === 'network error'");
    try expectScript(browser, "results.own === 'own'");
}

test "blob URLs: a URL another Browser made is a network error to this Browser's fetch; its own resolves" {
    try onThread(blobURLsResolveInTheirBrowserOnly, .{});
}

// ============================================================================
// IndexedDB: pinned, not moved
//
// IndexedDB has no process-global state: each IDBFactory - each global's
// `indexedDB` - holds its own databases, so two Browsers already share none
// (nor, today, do a page and its frames or workers: the queued
// IndexedDB-sharing batch makes the databases the Browser's, per storage
// key). This pins the two-Browser half.
// ============================================================================

/// Open the database "inst3" (no version: the current one, or 1 if it is
/// new), recording whether it needed an upgrade - whether it was new.
fn openDatabase(browser: *browser_mod.Browser) !void {
    try expectScript(browser,
        \\globalThis.opened = null;
        \\globalThis.upgradeSeen = false;
        \\{
        \\const request = indexedDB.open('inst3');
        \\request.onupgradeneeded = () => {
        \\  upgradeSeen = true;
        \\  request.result.createObjectStore('s');
        \\};
        \\request.onsuccess = () => {
        \\  opened = { version: request.result.version };
        \\  request.result.close();
        \\};
        \\request.onerror = () => opened = { error: String(request.error) };
        \\}
        \\true
    );
    try waitFor(browser, "opened !== null");
}

fn indexedDBIsNotSharedAcrossBrowsers() !void {
    {
        const browser = try startBrowser();
        defer browser.deinit();
        try openPage(browser);
        try openDatabase(browser);
        try expectScript(browser, "upgradeSeen === true && opened.version === 1");
        // The same page opens it again: it exists, no upgrade.
        try openDatabase(browser);
        try expectScript(browser, "upgradeSeen === false && opened.version === 1");
    }
    // The next Browser, one origin: the database does not exist there.
    const browser = try startBrowser();
    defer browser.deinit();
    try openPage(browser);
    try openDatabase(browser);
    try expectScript(browser, "upgradeSeen === true && opened.version === 1");
}

test "IndexedDB: a database one Browser made does not exist in the next" {
    try onThread(indexedDBIsNotSharedAcrossBrowsers, .{});
}

// ============================================================================
// Cookies: the Browser's jar, and the CookieStores that hear it
// ============================================================================

const cookiestore = @import("cookiestore");

/// A page in a secure context (a loopback origin is potentially
/// trustworthy): cookieStore is [SecureContext].
const cookie_page_url = "http://127.0.0.1/page.html";

fn openCookiePage(browser: *browser_mod.Browser) !void {
    try browser.navigateWithOptions(cookie_page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = cookie_page_url });
}

/// A response's `Set-Cookie` stored on a thread that is not the page's - as
/// a dedicated worker's fetch stores one, on the worker's thread.
fn storeOnAnotherThread(jar: *cookiestore.CookieJar, header: []const u8) !void {
    _ = try cookiestore.parseAndStoreCookie(testing.allocator, jar, header, "/", .{
        .is_secure = false,
        .host = "127.0.0.1",
        .http_only_allowed = true,
    });
}

fn cookieStoreHearsEveryThread() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try openCookiePage(browser);
    try expectScript(browser,
        \\globalThis.heard = [];
        \\cookieStore.addEventListener('change', event => {
        \\  for (const item of event.changed) heard.push(item.name + '=' + item.value);
        \\});
        \\true
    );
    try onThread(storeOnAnotherThread, .{ browser.cookie_jar, "w=1; Path=/" });
    try waitFor(browser, "heard.length > 0");
    try expectScript(browser, "heard.join() === 'w=1'");
    // And the page's own thread, as before.
    try expectScript(browser, "document.cookie = 'p=2; path=/'; true");
    try waitFor(browser, "heard.length > 1");
    try expectScript(browser, "heard.join() === 'w=1,p=2'");
}

test "cookies: a page's cookieStore hears a cookie stored on another of its Browser's threads" {
    try onThread(cookieStoreHearsEveryThread, .{});
}

fn cookiesEndWithTheirBrowser() !void {
    {
        const browser = try startBrowser();
        defer browser.deinit();
        try openPage(browser);
        try expectScript(browser, "document.cookie = 'k=a; path=/'; document.cookie === 'k=a'");
        // The same Browser's next page of the origin shares the jar.
        try openPage(browser);
        try expectScript(browser, "document.cookie === 'k=a'");
    }
    const browser = try startBrowser();
    defer browser.deinit();
    try openPage(browser);
    try expectScript(browser, "document.cookie === ''");
}

test "cookies: a Browser's jar ends with it - the next Browser sees none of its cookies" {
    try onThread(cookiesEndWithTheirBrowser, .{});
}
