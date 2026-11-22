//! What one isolated world's script may not do to another's, over a
//! Browser's page (src/browser/isolated_worlds.zig, engine section 4.2a):
//!
//! - Error events are their world's: an uncaught exception of a world's
//!   script fires no `error` event at the page's listeners, and the page's
//!   none at the world's - Blink's ErrorEvent::CanBeDispatchedInWorld
//!   (third_party/blink/renderer/core/events/error_event.cc), which
//!   JSBasedEventListener::Invoke asks before calling a listener.
//! - Animation frames are the document's: a callback a world requested is
//!   cancelled by its id from that world or the page - Blink's
//!   FrameRequestCallbackCollection is the document's, one id space for
//!   every world.
//! - Code generation from strings: a world with a Content Security Policy of
//!   its own is checked against it instead of the page's (Blink's
//!   IsolatedWorldCSP, ContentSecurityPolicy::ShouldBypassMainWorld); a world
//!   with none is governed by the page's.
//!
//! Written for the CDP test pass (the user's directive of 2026-11-21 5:48 PM
//! ET: implement now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");

const isolated_worlds = browser_mod.isolated_worlds;
const navigable: u64 = 1;

fn makeBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn evaluate(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    errdefer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evaluate(realm, source);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  -> {s}\n", .{ source, got });
    try testing.expectEqualStrings(expected, got);
}

/// Pump the Browser's loop until `condition` evaluates to "true" in `realm`:
/// at most `turns` turns of at most 5 ms each.
fn pumpUntil(browser: *browser_mod.Browser, realm: runtime.Context, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try browser.runEventLoopBlocking(5);
        const value = try evaluate(realm, condition);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    std.debug.print("condition never held: {s}\n", .{condition});
    return error.ConditionNeverHeld;
}

/// A page loaded from `html`, its realm.
fn loadPage(browser: *browser_mod.Browser, html: []const u8) !runtime.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    return (browser.current_context orelse return error.NoPage).realm orelse error.NoRealm;
}

// ---------------------------------------------------------------------------
// 1. Error events
// ---------------------------------------------------------------------------

test "an uncaught error of a world's script fires no error event at the page, and the page's none at the world" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__errors__", false);

    const which =
        \\globalThis.which = (m) => String(m).includes('from-world') ? 'world' : String(m).includes('from-page') ? 'page' : 'other';
    ;
    try expect(page, which ++
        \\globalThis.pageErrors = [];
        \\window.addEventListener('error', (e) => pageErrors.push('listener:' + which(e.message)));
        \\window.onerror = (message) => { pageErrors.push('handler:' + which(message)); };
        \\'ok'
    , "ok");
    try expect(world, which ++
        \\globalThis.worldErrors = [];
        \\window.addEventListener('error', (e) => worldErrors.push(which(e.message) + ':' + String(e.error instanceof Error)));
        \\setTimeout(() => { throw new Error('from-world'); }, 0);
        \\'ok'
    , "ok");
    try expect(page, "setTimeout(() => { throw new Error('from-page'); }, 0); 'ok'", "ok");
    try pumpUntil(browser, page, "pageErrors.length >= 2", 200);
    try pumpUntil(browser, world, "worldErrors.length >= 1", 200);
    _ = try browser.runEventLoopBlocking(20);
    // Each world saw its own error, and only it: the page's handler and
    // listener never heard of the world's, and the world's listener - handed
    // its own world's Error - never of the page's.
    try expect(page, "pageErrors.join(' ')", "listener:page handler:page");
    try expect(world, "worldErrors.join(' ')", "world:true");
}

test "a world's rejected promise with no handler is not the page's unhandledrejection" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__errors__", false);
    try expect(page, "globalThis.pageRejections = 0; window.addEventListener('unhandledrejection', () => pageRejections++); 'ok'", "ok");
    try expect(world, "Promise.reject(new Error('from-world')); 'ok'", "ok");
    _ = try browser.runEventLoopBlocking(50);
    try expect(page, "String(pageRejections)", "0");
}

// ---------------------------------------------------------------------------
// 2. Animation frames
// ---------------------------------------------------------------------------

test "cancelAnimationFrame cancels a world's frame from that world and from the page" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__frames__", false);

    try expect(world,
        \\globalThis.ran = [];
        \\const cancelledHere = requestAnimationFrame(() => ran.push('cancelled-in-world'));
        \\cancelAnimationFrame(cancelledHere);
        \\globalThis.cancelledByPage = requestAnimationFrame(() => ran.push('cancelled-by-page'));
        \\requestAnimationFrame(() => ran.push('kept'));
        \\String(cancelledByPage > 0)
    , "true");
    const id_text = try evaluate(world, "String(cancelledByPage)");
    defer testing.allocator.free(id_text);
    var buffer: [64]u8 = undefined;
    const cancel = try std.fmt.bufPrint(&buffer, "cancelAnimationFrame({s}); 'ok'", .{id_text});
    try expect(page, cancel, "ok");
    try pumpUntil(browser, world, "ran.length > 0", 400);
    _ = try browser.runEventLoopBlocking(20);
    try expect(world, "ran.join(' ')", "kept");
}

test "a world's frame callback runs in the world, and the page cancels none of its own by a world's call" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__frames__", false);

    try expect(page, "globalThis.marker = 'page'; globalThis.pageRan = false; globalThis.pageFrame = requestAnimationFrame(() => { pageRan = true; }); 'ok'", "ok");
    try expect(world, "globalThis.marker = 'world'; globalThis.worldSaw = ''; requestAnimationFrame(() => { worldSaw = marker; }); 'ok'", "ok");
    try pumpUntil(browser, page, "pageRan", 400);
    try pumpUntil(browser, world, "worldSaw !== ''", 400);
    try expect(world, "worldSaw", "world");
}

// ---------------------------------------------------------------------------
// 3. Content Security Policy for a world's strings
// ---------------------------------------------------------------------------

const eval_probe = "try { eval('1'); 'allowed' } catch (e) { e.name }";
const function_probe = "try { new Function('return 2')(); 'allowed' } catch (e) { e.name }";

test "a world with no policy of its own is governed by the page's: eval and string timers blocked" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><meta http-equiv=\"Content-Security-Policy\" content=\"script-src 'unsafe-inline'\"><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__plain__", false);

    try expect(page, eval_probe, "EvalError");
    try expect(world, eval_probe, "EvalError");
    try expect(world, function_probe, "EvalError");
    try expect(world, "globalThis.plainTimer = false; setTimeout('globalThis.plainTimer = true', 0); 'ok'", "ok");
    _ = try browser.runEventLoopBlocking(50);
    try expect(world, "String(plainTimer)", "false");
}

test "a world's own policy replaces the page's: it allows what the page's blocks" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><meta http-equiv=\"Content-Security-Policy\" content=\"script-src 'unsafe-inline'\"><body></body>");
    const world = try isolated_worlds.createIsolatedWorldWithPolicy(page, navigable, "__permissive__", false, "script-src 'unsafe-eval'");

    try expect(page, eval_probe, "EvalError");
    try expect(world, eval_probe, "allowed");
    try expect(world, function_probe, "allowed");
    try expect(world, "globalThis.worldTimer = false; setTimeout('globalThis.worldTimer = true', 0); 'ok'", "ok");
    try pumpUntil(browser, world, "worldTimer", 200);
    // The page's own checks are unchanged by it.
    try expect(page, function_probe, "EvalError");
}

test "a world's own policy blocks what the page allows, and reports nothing to the page" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorldWithPolicy(page, navigable, "__strict__", false, "script-src 'self'");

    try expect(page, "globalThis.violations = 0; document.addEventListener('securitypolicyviolation', () => violations++); 'ok'", "ok");
    try expect(page, eval_probe, "allowed");
    try expect(world, eval_probe, "EvalError");
    try expect(world, function_probe, "EvalError");
    try expect(world, "globalThis.strictTimer = false; setTimeout('globalThis.strictTimer = true', 0); 'ok'", "ok");
    _ = try browser.runEventLoopBlocking(50);
    try expect(world, "String(strictTimer)", "false");
    // Blink's isolated-world policy reports to the console only.
    try expect(page, "String(violations)", "0");
}

// ---------------------------------------------------------------------------
// 4. Event handler content attributes, FrozenArray attributes and
//    dictionaries across worlds
// ---------------------------------------------------------------------------

test "an event handler content attribute is the main world's: a world reads null, and its own handler leaves the page's" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body onclick=\"globalThis.fromAttribute = (globalThis.fromAttribute || 0) + 1\"></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__handlers__", false);
    try expect(page, "typeof document.body.onclick", "function");
    try expect(world, "String(document.body.onclick)", "null");
    try expect(world, "globalThis.worldClicks = 0; document.body.onclick = () => { worldClicks++; }; 'ok'", "ok");
    try expect(page, "document.body.dispatchEvent(new Event('click')); typeof document.body.onclick + ' ' + String(fromAttribute)", "function 1");
    try expect(world, "String(worldClicks)", "1");
    // Removing the attribute deactivates the main world's handler only.
    try expect(page, "document.body.removeAttribute('onclick'); String(document.body.onclick)", "null");
    try expect(world, "typeof document.body.onclick", "function");
}

test "a FrozenArray attribute is one frozen array per world, the same array on every read" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__frozen__", false);
    try expect(page, "const l = navigator.languages; String(Object.isFrozen(l) && l === navigator.languages && l.length > 0)", "true");
    try expect(world,
        \\const l = navigator.languages;
        \\String(Object.isFrozen(l) && l === navigator.languages && l instanceof Array && l.length > 0 && typeof l[0] === 'string')
    , "true");
    // Its elements cross too: a port is the world's wrapper of it.
    try expect(world,
        \\globalThis.portsSeen = '';
        \\document.body.addEventListener('ports', (e) => {
        \\  const p = e.ports;
        \\  portsSeen = String(p === e.ports && Object.isFrozen(p) && p instanceof Array && p.length === 1 && p[0] instanceof MessagePort);
        \\});
        \\'ok'
    , "ok");
    try expect(page, "const c = new MessageChannel(); document.body.dispatchEvent(new MessageEvent('ports', { ports: [c.port1] })); 'ok'", "ok");
    try expect(world, "portsSeen", "true");
}

test "a dictionary an operation returns crosses worlds member by member: navigation.navigate()'s promises are the world's" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__dictionaries__", false);
    try expect(world,
        \\globalThis.settled = '';
        \\const r = navigation.navigate('#cdpw-d');
        \\r.committed.then(() => { settled = 'fulfilled'; }, (e) => { settled = 'rejected:' + String(e instanceof DOMException); });
        \\r.finished.catch(() => {});
        \\String(Object.getPrototypeOf(r) === Object.prototype && r.committed instanceof Promise && r.finished instanceof Promise)
    , "true");
    try pumpUntil(browser, world, "settled !== ''", 200);
    try expect(world, "String(settled === 'fulfilled' || settled === 'rejected:true')", "true");
}
