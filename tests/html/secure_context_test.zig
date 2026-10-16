//! HTML 8.1.3.5 "secure context" for a Window's and a worker's environment
//! settings object, as the browsers decide it (WebKit
//! Document::computeIsSecureContext, Blink's SecureContextMode): a document is
//! a secure context when its own URL is potentially trustworthy (Secure
//! Contexts 3.2) and its parent's document is a secure context; about:blank
//! and about:srcdoc take their creator's answer (the parent, else the opener);
//! a worker takes its owner's, and its own URL must be potentially
//! trustworthy too.
//!
//! Before: every Window answered true - `Window.InternalState.is_secure_context`
//! defaulted to true and nothing ever set it - so an http: page claimed to be
//! a secure context (Codex row 42 Q5).

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

fn expectAnswer(page: anytype, script: []const u8, expected: []const u8) !void {
    const result = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

/// Load `html` as the page at `url` and run its tasks for a while.
fn load(browser: *Browser, html: []const u8, url: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = url });
    _ = try browser.runEventLoopBlocking(100);
}

/// Run the event loop until `script` evaluates to something other than
/// "pending", and expect `expected`.
fn awaitAnswer(browser: *Browser, script: []const u8, expected: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        const result = try page.evaluateScriptToString(script, testing.allocator);
        defer testing.allocator.free(result);
        if (!std.mem.eql(u8, result, "pending")) {
            try testing.expectEqualStrings(expected, result);
            return;
        }
        _ = try browser.runEventLoopBlocking(20);
    }
    return error.NoAnswer;
}

fn topLevel(url: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try load(browser, "<!doctype html><body>", url);
    try expectAnswer(browser.current_context.?, "String(isSecureContext)", expected);
}

test "a top-level http: page is not a secure context; https:, file: and loopback are" {
    try topLevel("http://web-platform.test:8000/a.html", "false");
    try topLevel("http://example.com/", "false");
    try topLevel("https://web-platform.test:8443/a.html", "true");
    try topLevel("file:///tmp/a.html", "true");
    try topLevel("http://localhost:8000/a.html", "true");
    try topLevel("http://sub.localhost/a.html", "true");
    try topLevel("http://127.0.0.1:8000/a.html", "true");
    try topLevel("http://[::1]/a.html", "true");
}

fn frameAnswer(url: []const u8, frame: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const html = try std.fmt.allocPrint(testing.allocator, "<!doctype html><body>{s}", .{frame});
    defer testing.allocator.free(html);
    try load(browser, html, url);
    try expectAnswer(browser.current_context.?, "String(frames[0].isSecureContext)", expected);
}

test "an about:blank iframe takes its parent's answer" {
    try frameAnswer("http://web-platform.test:8000/a.html", "<iframe></iframe>", "false");
    try frameAnswer("https://web-platform.test:8443/a.html", "<iframe></iframe>", "true");
}

test "an about:srcdoc iframe takes its parent's answer" {
    try frameAnswer("http://web-platform.test:8000/a.html", "<iframe srcdoc='<p>x'></iframe>", "false");
    try frameAnswer("https://web-platform.test:8443/a.html", "<iframe srcdoc='<p>x'></iframe>", "true");
}

test "a srcdoc iframe in a srcdoc iframe of an http: page is not a secure context" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try load(browser, "<!doctype html><body><iframe srcdoc=\"<iframe srcdoc='x'></iframe>\"></iframe>", "http://web-platform.test:8000/a.html");
    try expectAnswer(browser.current_context.?, "String(frames[0].frames[0].isSecureContext)", "false");
}

fn dataFrameAnswer(url: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const html =
        \\<!doctype html><body><script>
        \\  var answer = 'pending';
        \\  addEventListener('message', function (e) { answer = String(e.data); });
        \\</script>
        \\<iframe src="data:text/html,<script>parent.postMessage(isSecureContext, '*')</script>"></iframe>
    ;
    try load(browser, html, url);
    try awaitAnswer(browser, "answer", expected);
}

test "a data: URL iframe takes its parent's answer" {
    try dataFrameAnswer("http://web-platform.test:8000/a.html", "false");
    try dataFrameAnswer("https://web-platform.test:8443/a.html", "true");
}

fn popupAnswer(url: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try load(browser, "<!doctype html><body>", url);
    try expectAnswer(browser.current_context.?, "var w = window.open(''); String(w.isSecureContext)", expected);
}

test "an about:blank popup takes its opener's answer" {
    try popupAnswer("http://web-platform.test:8000/a.html", "false");
    try popupAnswer("https://web-platform.test:8443/a.html", "true");
}

fn workerAnswer(url: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const html =
        \\<!doctype html><body><script>
        \\  var answer = 'pending';
        \\  var w = new Worker('data:text/javascript,postMessage(isSecureContext)');
        \\  w.onmessage = function (e) { answer = String(e.data); };
        \\  w.onerror = function () { answer = 'error'; };
        \\</script>
    ;
    try load(browser, html, url);
    try awaitAnswer(browser, "answer", expected);
}

test "a dedicated worker takes its owner's answer" {
    try workerAnswer("http://web-platform.test:8000/a.html", "false");
    try workerAnswer("https://web-platform.test:8443/a.html", "true");
}
