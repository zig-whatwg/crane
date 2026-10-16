//! A Window's origin is its associated Document's origin (HTML: a Window's
//! relevant settings object's origin is its document's). A document made with
//! an opaque origin - a sandboxed frame's, a frame's network-error document's
//! - makes its window's origin opaque too, whatever its URL says: its
//! `origin` is "null" and another window reaches it only cross-origin.
//!
//! Before: Window.effectiveOrigin derived the origin from the document's URL
//! and never consulted the document's origin record, so a frame whose
//! document was given an opaque origin reported its URL's tuple origin and
//! its parent could reach into it (Codex row 43 Q5/Q10).

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
}

fn expectAnswer(browser: *Browser, script: []const u8, expected: []const u8) !void {
    const result = try answer(browser, script);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

/// Run the event loop until `script` evaluates to something other than
/// "pending", and expect `expected`.
fn awaitAnswer(browser: *Browser, script: []const u8, expected: []const u8) !void {
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        const result = try answer(browser, script);
        defer testing.allocator.free(result);
        if (!std.mem.eql(u8, result, "pending")) {
            try testing.expectEqualStrings(expected, result);
            return;
        }
        _ = try browser.runEventLoopBlocking(20);
    }
    return error.NoAnswer;
}

const access_location =
    \\(function () { try { return String(frames[0].location.href); } catch (e) { return e.name; } })()
;
const access_document =
    \\(function () { try { return String(frames[0].document); } catch (e) { return e.name; } })()
;

test "a sandboxed srcdoc frame's window has an opaque origin, which its parent cannot reach" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const html =
        \\<!doctype html><body><script>
        \\  var answer = 'pending';
        \\  addEventListener('message', function (e) { answer = String(e.data); });
        \\</script>
        \\<iframe sandbox="allow-scripts" srcdoc="<script>parent.postMessage(self.origin, '*')</script>"></iframe>
    ;
    try page.loadHTML(html, .{ .base_url = "http://web-platform.test:8000/a.html" });
    _ = try browser.runEventLoopBlocking(100);
    try awaitAnswer(browser, "answer", "null");
    try expectAnswer(browser, access_location, "SecurityError");
    try expectAnswer(browser, access_document, "SecurityError");
}

test "a frame's network-error document has an opaque origin, which its parent cannot reach" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // Port 1 on loopback refuses the connection: the navigation's response
    // is a network error, and its document's origin a new opaque origin.
    const html =
        \\<!doctype html><body><script>
        \\  var loaded = 'pending';
        \\</script>
        \\<iframe src="http://127.0.0.1:1/refused.html" onload="loaded = 'yes'"></iframe>
    ;
    try page.loadHTML(html, .{ .base_url = "http://127.0.0.1:1/a.html" });
    try awaitAnswer(browser, "loaded", "yes");
    try expectAnswer(browser, access_document, "SecurityError");
    try expectAnswer(browser, access_location, "SecurityError");
}

test "a same-origin frame stays reachable" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe srcdoc='<p>x'></iframe>", .{ .base_url = "http://web-platform.test:8000/a.html" });
    _ = try browser.runEventLoopBlocking(100);
    try expectAnswer(browser, access_location, "about:srcdoc");
    try expectAnswer(browser, "String(frames[0].origin)", "http://web-platform.test:8000");
}

test "an object's and an iframe's about:blank documents keep their container's origin" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const html =
        \\<!doctype html><body>
        \\<iframe id="f"></iframe>
        \\<object name="o" type="text/html" data="about:blank"></object>
    ;
    try page.loadHTML(html, .{ .base_url = "http://web-platform.test:8000/a.html" });
    _ = try browser.runEventLoopBlocking(200);
    try expectAnswer(browser, "String(frames[0].origin)", "http://web-platform.test:8000");
    try expectAnswer(browser, "(function () { try { return String(window.o.origin); } catch (e) { return e.name; } })()", "http://web-platform.test:8000");
}
