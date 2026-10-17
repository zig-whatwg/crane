//! A document whose `<meta>` CSP could not be recorded fails closed through
//! the hosts' own CSP paths, not only through src/csp's.
//!
//! On out of memory, HTMLMetaElement's Content Security Policy state leaves
//! the document's CSP list unenforceable (csp.integration.enforceMetaPolicy;
//! tests/csp/meta_policy_fails_closed_test.zig pins that part with every
//! allocation failure in turn). Such a list has no policies, and five host
//! fast paths answered "nothing to check" for a list with no policies
//! (`policies.items.len == 0`): the inline check (dom.csp_violations
//! shouldBlockInline, and Document's isInlineScriptAllowedByCSP before it),
//! the target's javascript: URL check, eval's (html.code_generation) and the
//! plugin check (html.embedded_content). They ask `isEmpty()` now, which an
//! unenforceable list never is, and the inline check's own policy loop asks
//! `blocksEverything()`. The plugin check's answer is not observable - Crane
//! loads no plugin content either way, and only reports - so it has no case
//! here; tests/csp checks its src/csp entry point.
//!
//! Each case runs in the same page before (the control: it runs) and after
//! the list is made unenforceable, as the OOM'd `<meta>` leaves it.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const html = @import("html");

fn expectScript(page: anytype, script: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("`{s}` answered {s}, expected {s}\n", .{ script, got, expected });
    try testing.expectEqualStrings(expected, got);
}

/// An inline script and an element with an event handler content
/// attribute, made while the list still allows them: once it fails closed,
/// Trusted Types' sinks (script text, on* attributes) throw too - so they are
/// prepared before, and only inserted or dispatched to after.
const prepare =
    \\(() => {
    \\  window.ran = 0;
    \\  window.clicked = 0;
    \\  window.preparedScript = document.createElement("script");
    \\  window.preparedScript.textContent = "window.ran = 1";
    \\  window.preparedDiv = document.createElement("div");
    \\  window.preparedDiv.setAttribute("onclick", "window.clicked = 1");
    \\  return "prepared";
    \\})()
;

const inline_script =
    \\(() => {
    \\  window.ran = 0;
    \\  document.head.appendChild(window.preparedScript);
    \\  return String(window.ran);
    \\})()
;

const event_handler =
    \\(() => {
    \\  window.clicked = 0;
    \\  window.preparedDiv.click();
    \\  return String(window.clicked);
    \\})()
;

/// HTML 8.1.8.1: an event handler content attribute is checked when it is
/// SET ("should element's inline behavior be blocked", type "script
/// attribute"), and setting one is a Trusted Types sink too: once the list
/// fails closed the attribute cannot be set at all.
const event_handler_set =
    \\(() => {
    \\  window.clicked = 0;
    \\  const d = document.createElement("div");
    \\  try { d.setAttribute("onclick", "window.clicked = 1"); } catch (e) { return e.name; }
    \\  d.click();
    \\  return String(window.clicked);
    \\})()
;

const trusted_types_sink =
    \\(() => { try { document.createElement("script").textContent = "1"; return "set"; } catch (e) { return e.name; } })()
;

const eval_script =
    \\(() => { try { return String(eval("2")); } catch (e) { return e.constructor.name; } })()
;

const function_constructor =
    \\(() => { try { return String(new Function("return 3")()); } catch (e) { return e.constructor.name; } })()
;

fn fetchResult(browser: anytype, page: anytype) ![]u8 {
    try page.runScript("window.fetched = 'pending'; fetch('data:text/plain,hi').then(() => window.fetched = 'fetched', (e) => window.fetched = e.name);");
    _ = try browser.runEventLoopBlocking(50);
    return page.evaluateScriptToString("window.fetched", testing.allocator);
}

fn javascriptUrlResult(browser: anytype, page: anytype) ![]u8 {
    try page.runScript("window.jsran = 0; location.href = 'javascript:window.jsran = 1';");
    _ = try browser.runEventLoopBlocking(50);
    return page.evaluateScriptToString("String(window.jsran)", testing.allocator);
}

fn exercise() !void {
    const allocator = testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><head></head><body></body>", .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const container = @constCast(html.worker_host.creatorPolicyContainer(realm) orelse return error.NoPolicyContainer);
    try testing.expect(container.csp_list.isEmpty());

    // The control: a document with no policy runs and loads everything.
    try expectScript(page, prepare, "prepared");
    try expectScript(page, inline_script, "1");
    try expectScript(page, event_handler, "1");
    try expectScript(page, event_handler_set, "1");
    try expectScript(page, trusted_types_sink, "set");
    try expectScript(page, eval_script, "2");
    try expectScript(page, function_constructor, "3");
    {
        const got = try fetchResult(browser, page);
        defer allocator.free(got);
        try testing.expectEqualStrings("fetched", got);
    }
    {
        const got = try javascriptUrlResult(browser, page);
        defer allocator.free(got);
        try testing.expectEqualStrings("1", got);
    }

    // What a `<meta>` CSP that ran out of memory leaves.
    try expectScript(page, prepare, "prepared");
    container.csp_list.markUnenforceable();
    // Trusted Types are required (csp require-trusted-types-for).
    try expectScript(page, trusted_types_sink, "TypeError");
    // The inline check (Document's fast path, then dom.csp_violations).
    try expectScript(page, inline_script, "0");
    try expectScript(page, event_handler_set, "TypeError");
    // eval and Function (html.code_generation, then csp.code_generation).
    try expectScript(page, eval_script, "EvalError");
    try expectScript(page, function_constructor, "EvalError");
    // Fetch (csp.request_check, through fetch's csp_check).
    {
        const got = try fetchResult(browser, page);
        defer allocator.free(got);
        try testing.expectEqualStrings("TypeError", got);
    }
    // A javascript: URL navigation (the initiator's and the target's
    // checks, dom.csp_violations).
    {
        const got = try javascriptUrlResult(browser, page);
        defer allocator.free(got);
        try testing.expectEqualStrings("0", got);
    }
}

test "a document whose meta CSP could not be recorded blocks script, eval, fetch and javascript: URLs" {
    // A Browser of its own, on a thread of its own (tests/html shares one
    // process: no per-thread state from another file).
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
