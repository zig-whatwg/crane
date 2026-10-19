//! register() checks the client's Content Security Policy for the script
//! URL on the client's own thread, before any job is scheduled (lane
//! sw1-b10, item 1): a blocked URL rejects with a "SecurityError" and the
//! page's securitypolicyviolation event names worker-src and the calling
//! script's location; an allowed one schedules its job as before. The
//! browsers all check there (Blink ServiceWorkerContainer::
//! registerServiceWorker, WebKit ServiceWorkerContainer::addRegistration,
//! Gecko ServiceWorkerScopeAndScriptAreValid) - src/service_worker/realm.zig.
//!
//! The script fetch is the test's (no network): the manager's host answers
//! from a table, and starts and dispatches with the real host (run.zig).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const sw = @import("service_worker");
const registry = sw.registry;

const page_url = "https://sw-csp.test/page.html";

const test_host: sw.manager.Host = .{
    .fetch = tableFetch,
    .start = sw.run.host.start,
    .dispatch = sw.run.host.dispatch,
    .post_message = sw.run.host.post_message,
    .dispatch_fetch = sw.run.host.dispatch_fetch,
};

fn tableFetch(manager: *sw.Manager, plan: *const registry.FetchPlan) registry.FetchOutcome {
    var outcome: registry.FetchOutcome = .{ .has_updated_resources = true, .checked_network = true };
    const allocator = manager.allocator;
    const url = allocator.dupe(u8, plan.script_url) catch return .{ .failure = .network };
    const body = allocator.dupe(u8, "// an empty worker") catch return .{ .failure = .network };
    const content_type = allocator.dupe(u8, "text/javascript") catch return .{ .failure = .network };
    outcome.resources.append(allocator, .{ .url = url, .body = body, .content_type = content_type }) catch return .{ .failure = .network };
    return outcome;
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    const context = browser.current_context orelse return error.TimedOut;
    const state = context.evaluateScriptToString("String(globalThis.state) + ' events: ' + JSON.stringify(globalThis.events)", testing.allocator) catch return error.TimedOut;
    defer testing.allocator.free(state);
    std.debug.print("timed out waiting for: {s}\n  {s}\n", .{ source, state });
    return error.TimedOut;
}

/// A page with `policy` in a meta element, whose inline script registers
/// /sw.js on its second line and records what came of it.
fn pageWith(policy: []const u8) ![]u8 {
    return std.mem.concat(testing.allocator, u8, &.{
        "<!doctype html>\n<meta http-equiv=\"Content-Security-Policy\" content=\"",
        policy,
        "\">\n",
        "<script>globalThis.state = 'registering'; globalThis.events = []; document.addEventListener('securitypolicyviolation', e => events.push([e.violatedDirective, e.effectiveDirective, e.blockedURI, e.sourceFile, e.lineNumber].join(' ')));\n",
        "navigator.serviceWorker.register('/sw.js').then(r => { globalThis.state = 'registered ' + r.scope; }, e => { globalThis.state = 'rejected ' + e.name; });\n",
        "</script>\n",
    });
}

fn open(policy: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    // The host is the test's before the page's script schedules a job.
    {
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
        const realm = browser.getRealm() orelse return error.NoRealm;
        const manager = sw.Manager.of(realm) orelse return error.NoManager;
        manager.host = &test_host;
    }
    const html = try pageWith(policy);
    defer testing.allocator.free(html);
    try context.loadHTML(html, .{ .base_url = page_url });
    return browser;
}

test "register() of a script URL worker-src blocks rejects with SecurityError, reports worker-src at the caller, and schedules no job" {
    const browser = try open("worker-src 'none'");
    defer browser.deinit();
    try waitFor(browser, "globalThis.state !== 'registering' && globalThis.events.length > 0");
    try testing.expect(try truthy(browser, "globalThis.state === 'rejected SecurityError'"));
    // One violation, of worker-src, naming the script URL and the calling
    // script's position: the register() call, the inline script's second
    // line (its positions count from the script's first line here).
    try waitFor(browser, "globalThis.events.length === 1 && globalThis.events[0] === \"worker-src worker-src https://sw-csp.test/sw.js https://sw-csp.test/page.html 2\"");
    // No job ran: no registration exists for the scope.
    const listed = try browser.evaluateScript("globalThis.listed = 'pending'; navigator.serviceWorker.getRegistrations().then(rs => { globalThis.listed = rs.length; }); true");
    listed.release();
    try waitFor(browser, "globalThis.listed === 0");
}

test "register() falls back to child-src for a service worker: child-src 'none' blocks, reported as worker-src" {
    const browser = try open("child-src 'none'; script-src 'self' 'unsafe-inline'; default-src 'none'");
    defer browser.deinit();
    try waitFor(browser, "globalThis.state !== 'registering' && globalThis.events.length > 0");
    try testing.expect(try truthy(browser, "globalThis.state === 'rejected SecurityError'"));
    try testing.expect(try truthy(browser, "globalThis.events[0].startsWith('worker-src worker-src https://sw-csp.test/sw.js')"));
}

test "register() of a script URL the policy allows still schedules its job" {
    const browser = try open("worker-src 'self'");
    defer browser.deinit();
    try waitFor(browser, "globalThis.state === 'registered https://sw-csp.test/'");
    try testing.expect(try truthy(browser, "globalThis.events.length === 0"));
}
