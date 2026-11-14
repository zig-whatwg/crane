//! Lane nav3: a frame its container's load listener removes stays removed.
//!
//! Since lane nav2 batch 12, "the end" completes a document's load inside the
//! parser's task (the browsers' order, the user's ruling 2026-11-12), and a
//! frame's parse runs inside its navigation's commit. So the iframe load
//! event steps - and a listener that removes the frame - run before the
//! commit returns. HTML "destroy a child navigable" sets the container's
//! content navigable to null (step 3), and "content window" is then null
//! (crane/nav1-frame-load-removes-frame.html; html/semantics/embedded-content/
//! the-iframe-element/iframe-synchronously-discard.html passes in Chrome 157,
//! Firefox 160 and Safari 27.2). The commit went on after the parse and
//! marked the destroyed navigable ready again, and contentWindow answered the
//! removed frame's Window.
//!
//! Each test removes a frame from its own load listener, for each way a
//! frame's document is committed: a fetched HTML document, a srcdoc
//! document, a text document, a network error's document and a javascript:
//! URL's string document. One more removes it from the frame's own inline
//! script, during the parse: the same commit, left the same way.
//!
//! tests/html is one executable: the engine may already be started.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;

const routes = [_]http.Route{
    .{ .path = "/page.html", .content_type = "text/html", .body = "<!doctype html><body></body>" },
    // frame-src 'self': a frame navigated to another origin gets a network
    // error's document (CSP 3 "should navigation request of type be blocked
    // by Content Security Policy?"), which still fires its container's load.
    .{ .path = "/csp.html", .content_type = "text/html", .body = "<!doctype html><meta http-equiv=\"Content-Security-Policy\" content=\"frame-src 'self'\"><body></body>" },
    .{ .path = "/child.html", .content_type = "text/html", .body = "<!doctype html><script>addEventListener('load', () => parent.events.push('child-load'));</script>" },
    .{ .path = "/text.txt", .content_type = "text/plain", .body = "a text document" },
};

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

fn run(browser: *Browser, script: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(script);
}

/// Turn the event loop until `script` answers "true", or fail.
fn waitFor(browser: *Browser, script: []const u8) !void {
    var turn: usize = 0;
    while (turn < 400) : (turn += 1) {
        const now = try answer(browser, script);
        defer testing.allocator.free(now);
        if (std.mem.eql(u8, now, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{script});
    return error.NeverHappened;
}

fn openPage(server: *http.Server, url: []const u8) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigate(url, .window);
    try waitFor(browser, "document.readyState === 'complete'");
    return browser;
}

/// The listener every test installs on its frame: it records whether the
/// frame had a content window when its load fired, removes the frame, and
/// records whether the content window is null right after.
const remove_on_load =
    \\globalThis.events = [];
    \\globalThis.frame = document.createElement('iframe');
    \\globalThis.onFrameLoad = () => {
    \\  events.push('load:' + (frame.contentWindow !== null));
    \\  frame.remove();
    \\  events.push('removed:' + (frame.contentWindow === null));
    \\};
;

/// Once the listener ran, a few more turns of the event loop - the tasks the
/// commit and the removal queued - and the frame is still gone: no content
/// window, no content document.
fn expectGone(browser: *Browser, expected_events: []const u8) !void {
    try waitFor(browser, "events.includes('removed:true') || events.includes('removed:false')");
    for (0..5) |_| _ = try browser.runEventLoopBlocking(10);
    const result = try answer(browser, "events.join() + ' | ' + (frame.contentWindow === null) + ',' + (frame.contentDocument === null)");
    defer testing.allocator.free(result);
    var expected_buf: [256]u8 = undefined;
    const expected = try std.fmt.bufPrint(&expected_buf, "{s} | true,true", .{expected_events});
    try testing.expectEqualStrings(expected, result);
}

test "a fetched frame its load listener removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/page.html");
    defer browser.deinit();
    try run(browser, remove_on_load ++
        \\frame.onload = onFrameLoad;
        \\frame.src = '/child.html';
        \\document.body.append(frame);
    );
    // The container's load fires inside the child's window load dispatch,
    // after the child's own load listeners (Document's completeLoading).
    try expectGone(browser, "child-load,load:true,removed:true");
}

test "a srcdoc frame its load listener removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/page.html");
    defer browser.deinit();
    try run(browser, remove_on_load ++
        \\frame.onload = onFrameLoad;
        \\frame.srcdoc = '<p>srcdoc</p>';
        \\document.body.append(frame);
    );
    try expectGone(browser, "load:true,removed:true");
}

test "a text document frame its load listener removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/page.html");
    defer browser.deinit();
    try run(browser, remove_on_load ++
        \\frame.onload = onFrameLoad;
        \\frame.src = '/text.txt';
        \\document.body.append(frame);
    );
    try expectGone(browser, "load:true,removed:true");
}

test "a frame showing a network error's document that its load listener removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/csp.html");
    defer browser.deinit();
    try run(browser, remove_on_load ++
        \\frame.onload = onFrameLoad;
        \\frame.src = 'http://nav3other.test/child.html';
        \\document.body.append(frame);
    );
    try expectGone(browser, "load:true,removed:true");
}

test "a frame its own document's parse-time script removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/page.html");
    defer browser.deinit();
    // The same commit, left by script that runs during the parse rather than
    // at its end: the frame's inline script removes its own container. Its
    // parent is read first: a removed frame's window has none.
    try run(browser, remove_on_load ++
        \\frame.srcdoc = '<script>const p = parent; p.events.push("script"); frameElement.remove(); p.events.push("removed:" + (p.frame.contentWindow === null));</script>';
        \\document.body.append(frame);
    );
    try expectGone(browser, "script,removed:true");
}

test "a frame whose javascript: URL's string its load listener removes has no content window after its commit" {
    const server = try http.Server.start(testing.allocator, &routes);
    defer server.stop();
    const browser = try openPage(server, "http://nav3remove.test/page.html");
    defer browser.deinit();
    // The initial about:blank's load fires at the insertion, before the
    // listener is set; the javascript: URL's string document is the
    // navigation whose load removes the frame.
    try run(browser, remove_on_load ++
        \\document.body.append(frame);
        \\frame.onload = onFrameLoad;
        \\frame.src = 'javascript:"<p>from a javascript: URL</p>"';
    );
    try expectGone(browser, "load:true,removed:true");
}
