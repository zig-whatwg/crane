//! Service worker registrations are partitioned by storage key (lane
//! sw1-b11): the origin, the top-level site and the has-cross-site-ancestor
//! bit, as Chrome and Firefox key them (partition1's key).
//!
//! A page on http://localhost frames http://localhost (same site) and
//! http://b.localhost (cross site: a third-party frame). The third-party
//! frame registers a service worker, opens a first-party popup of its own
//! origin and starts a dedicated and a shared worker. Then:
//!
//! - the frame sees its registration and the first-party popup does not;
//! - one key, two computations: for every environment the manager has - the
//!   page, both frames, the popup, both workers and the service worker's
//!   own global - the storage key the registry holds (computed by
//!   service_worker/realm.zig when the client is made, before a frame's
//!   document URL is set) is the one its settings object computes
//!   (dom.global_settings), read on its own thread once it is final;
//! - two Browsers on two threads doing the same, each with a scope of its
//!   own, see only their own registration (a Browser's registry is its own).
//!
//! A loopback server behind each Browser's manual proxy answers every host
//! (sw1b11_http_server.zig). *.localhost and localhost are secure contexts
//! and two sites. Each Browser allocates from a DebugAllocator of its own
//! (AGENTS.md: a shared std.testing.allocator makes two Browsers take turns).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const sw = @import("service_worker");
const http = @import("sw1b11_http_server.zig");

const frame_html =
    \\<!doctype html><body><script>
    \\if (location.hostname === 'b.localhost') (async () => {
    \\  try {
    \\    const scope = new URLSearchParams(location.search).get('scope');
    \\    const reg = await navigator.serviceWorker.register('/sw.js', { scope });
    \\    const worker = reg.installing || reg.waiting || reg.active;
    \\    await new Promise(resolve => {
    \\      if (worker.state === 'activated') return resolve();
    \\      worker.addEventListener('statechange', () => { if (worker.state === 'activated') resolve(); });
    \\    });
    \\    const mine = (await navigator.serviceWorker.getRegistrations()).map(r => new URL(r.scope).pathname);
    \\    const fromPopup = new Promise(resolve => addEventListener('message', e => resolve(e.data), { once: true }));
    \\    globalThis.popup = window.open('http://b.localhost/popup.html');
    \\    const popup = await fromPopup;
    \\    const dedicated = new Worker('/worker.js');
    \\    const dedicatedReady = new Promise(resolve => { dedicated.onmessage = e => resolve(e.data); });
    \\    dedicated.postMessage('ping');
    \\    const shared = new SharedWorker('/shared.js');
    \\    const sharedReady = new Promise(resolve => { shared.port.onmessage = e => resolve(e.data); });
    \\    shared.port.postMessage('ping');
    \\    const workers = [await dedicatedReady, await sharedReady];
    \\    globalThis.kept = [dedicated, shared];
    \\    parent.postMessage({ mine, popup, workers }, '*');
    \\  } catch (e) {
    \\    parent.postMessage({ error: String(e) }, '*');
    \\  }
    \\})();
    \\</script>
;

const popup_html =
    \\<!doctype html><script>
    \\navigator.serviceWorker.getRegistrations().then(
    \\  r => opener.postMessage(r.length, '*'),
    \\  e => opener.postMessage('error ' + e, '*'));
    \\</script>
;

const routes = [_]http.Route{
    .{ .path = "/frame.html", .body = frame_html },
    .{ .path = "/popup.html", .body = popup_html },
    .{ .path = "/sw.js", .content_type = "text/javascript", .body = "self.addEventListener('install', () => {});" },
    .{ .path = "/worker.js", .content_type = "text/javascript", .body = "onmessage = () => postMessage('dedicated');" },
    .{ .path = "/shared.js", .content_type = "text/javascript", .body = "onconnect = e => { const port = e.ports[0]; port.onmessage = () => port.postMessage('shared'); };" },
};

const page_url = "http://localhost/page.html";

fn evaluate(browser: *browser_mod.Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

/// The answer the third-party frame posts to the page, once it has one.
fn waitForAnswer(browser: *browser_mod.Browser) ![]u8 {
    for (0..2000) |_| {
        const answer = try evaluate(browser, "String(globalThis.answer)");
        if (!std.mem.eql(u8, answer, "null")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.NoAnswer;
}

/// One environment's check, run on its realm's thread: is the registry's
/// key its settings object's?
const Check = struct {
    expected: []const u8,
    endpoint: *sw.manager.Endpoint,
    /// 0 pending, 1 the same, 2 another, 3 no key, 4 the task never ran.
    outcome: std.atomic.Value(u8) = .init(0),
    seen: [192]u8 = undefined,
    seen_len: usize = 0,

    fn run(data: ?*anyopaque) void {
        const self: *Check = @ptrCast(@alignCast(data.?));
        const global = sw.realm.endpointGlobal(self.endpoint) orelse return self.outcome.store(3, .release);
        const key = (dom.global_settings.serializedStorageKeyOf(global) catch null) orelse return self.outcome.store(3, .release);
        const n = @min(key.len, self.seen.len);
        @memcpy(self.seen[0..n], key[0..n]);
        self.seen_len = n;
        self.outcome.store(if (std.mem.eql(u8, key, self.expected)) 1 else 2, .release);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Check = @ptrCast(@alignCast(data.?));
        self.outcome.store(4, .release);
    }
};

/// Every environment's registry key against its settings object's own; the
/// kinds and keys found are returned for the caller to expect.
fn checkKeys(browser: *browser_mod.Browser) !void {
    const allocator = browser.allocator;
    const realm = browser.getRealm() orelse return error.NoRealm;
    const manager = sw.Manager.of(realm) orelse return error.NoManager;
    const keys = try manager.environmentKeys(allocator);
    defer {
        for (keys) |*key| key.deinit(allocator);
        allocator.free(keys);
    }
    const checks = try allocator.alloc(Check, keys.len);
    defer allocator.free(checks);
    for (keys, checks) |key, *check| {
        check.* = .{ .expected = key.storage_key, .endpoint = key.endpoint };
        if (!key.endpoint.sink.post(.{ .run = Check.run, .drop = Check.drop, .data = check })) check.outcome.store(4, .release);
    }
    var turns: usize = 0;
    while (true) : (turns += 1) {
        const pending = for (checks) |*check| {
            if (check.outcome.load(.acquire) == 0) break true;
        } else false;
        if (!pending) break;
        if (turns > 2000) return error.ChecksNeverRan;
        _ = try browser.runEventLoopBlocking(5);
    }
    var failed = false;
    var kinds = std.EnumSet(sw.registry.EnvironmentKind){};
    var cross_site_window = false;
    var first_party_popup = false;
    for (keys, checks) |key, *check| {
        const outcome = check.outcome.load(.acquire);
        if (outcome != 1) {
            failed = true;
            std.debug.print("{s} {s}: registry key '{s}', settings key '{s}' (outcome {d})\n", .{ @tagName(key.kind), key.creation_url, key.storage_key, check.seen[0..check.seen_len], outcome });
            continue;
        }
        kinds.insert(key.kind);
        if (key.kind == .window and std.mem.startsWith(u8, key.creation_url, "http://b.localhost/frame.html")) {
            cross_site_window = std.mem.endsWith(u8, key.storage_key, " 1");
        }
        if (key.kind == .window and std.mem.startsWith(u8, key.creation_url, "http://b.localhost/popup.html")) {
            first_party_popup = std.mem.endsWith(u8, key.storage_key, " 0");
        }
        // The workers of the third-party frame, and its service worker,
        // are keyed as the frame is.
        if (key.kind != .window) try testing.expect(std.mem.endsWith(u8, key.storage_key, " 1"));
    }
    if (failed) return error.StorageKeysDiverge;
    try testing.expect(kinds.contains(.window));
    try testing.expect(kinds.contains(.dedicated_worker));
    try testing.expect(kinds.contains(.shared_worker));
    try testing.expect(kinds.contains(.service_worker));
    try testing.expect(cross_site_window);
    try testing.expect(first_party_popup);
}

fn startBrowser(allocator: std.mem.Allocator, server: *http.Server) !*browser_mod.Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try browser_mod.Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    return browser;
}

/// The page frames both sites; the third-party frame registers `scope`.
fn runScenario(browser: *browser_mod.Browser, scope: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    const html = try std.fmt.allocPrint(browser.allocator,
        \\<!doctype html><body><script>
        \\globalThis.answer = null;
        \\addEventListener('message', e => {{ globalThis.answer = JSON.stringify(e.data); }});
        \\</script>
        \\<iframe src="http://localhost/frame.html?scope={s}"></iframe>
        \\<iframe src="http://b.localhost/frame.html?scope={s}"></iframe>
    , .{ scope, scope });
    defer browser.allocator.free(html);
    try page.loadHTML(html, .{ .base_url = page_url });
    const answer = try waitForAnswer(browser);
    defer browser.allocator.free(answer);
    // The third-party frame sees its own registration only; the popup of
    // its origin, first-party, sees none.
    const expected = try std.fmt.allocPrint(browser.allocator, "{{\"mine\":[\"{s}\"],\"popup\":0,\"workers\":[\"dedicated\",\"shared\"]}}", .{scope});
    defer browser.allocator.free(expected);
    testing.expectEqualStrings(expected, answer) catch |err| {
        std.debug.print("answer: {s}\n", .{answer});
        return err;
    };
    try checkKeys(browser);
}

test "a third-party frame's registration is its partition's; the registry's storage keys are the settings objects' own" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("leaked");
    const browser = try startBrowser(debug.allocator(), server);
    defer browser.deinit();
    try runScenario(browser, "/");
}

const Side = struct {
    server: *http.Server,
    scope: []const u8,
    failure: ?anyerror = null,

    fn main(self: *Side) void {
        self.run() catch |err| {
            self.failure = err;
        };
    }

    fn run(self: *Side) !void {
        var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug.deinit() != .ok) {
            self.failure = error.Leaked;
        };
        const browser = try startBrowser(debug.allocator(), self.server);
        defer browser.deinit();
        try runScenario(browser, self.scope);
    }
};

test "two Browsers on two threads: each third-party frame sees its own Browser's registration only" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    var sides = [_]Side{ .{ .server = server, .scope = "/a/" }, .{ .server = server, .scope = "/b/" } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.main, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| {
        std.debug.print("Browser {s} failed: {s}\n", .{ side.scope, @errorName(err) });
        return err;
    };
}
