//! location.ancestorOrigins masked by the iframe element referrer policy
//! (HTML 3.1.3 "internal ancestor origin objects list creation steps",
//! whatwg/html#11560, 2026-03-11; gr2audit A19). The policy is navigate step
//! 8's target snapshot - the iframe's referrerpolicy attribute as the
//! navigation starts - and for the initial about:blank document the
//! attribute as the document is created.
//!
//! Before: Location walked the parent frames and exposed every origin,
//! whatever the attribute said (Chrome's and Safari's behaviour).

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const base_url = "http://web-platform.test:8000/a.html";

fn answer(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, testing.allocator);
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

test "the initial about:blank document takes the referrerpolicy attribute as it is at creation" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = base_url });
    try awaitAnswer(browser,
        \\(function () {
        \\  var f = document.createElement('iframe');
        \\  f.referrerPolicy = 'no-referrer';
        \\  document.body.append(f);
        \\  var first = [...f.contentWindow.location.ancestorOrigins].join(',');
        \\  f.referrerPolicy = '';
        \\  var plain = document.createElement('iframe');
        \\  document.body.append(plain);
        \\  return first + '|' + [...f.contentWindow.location.ancestorOrigins].join(',') + '|' +
        \\    [...plain.contentWindow.location.ancestorOrigins].join(',');
        \\})()
    , "null|null|http://web-platform.test:8000");
}

test "the policy is snapshotted when the navigation starts" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const html =
        \\<!doctype html><body><script>
        \\  var result = 'pending';
        \\  var f = document.createElement('iframe');
        \\  document.body.append(f);
        \\  f.referrerPolicy = 'no-referrer';
        \\  f.onload = function () { result = [...f.contentWindow.location.ancestorOrigins].join(','); };
        \\  f.srcdoc = '<p>masked';
        \\  f.referrerPolicy = '';
        \\</script>
    ;
    try page.loadHTML(html, .{ .base_url = base_url });
    try awaitAnswer(browser, "result", "null");
}

test "same-origin masks the parent of a document of another origin, as after a cross-origin redirect" {
    // A frame whose final document is of another origin than its parent -
    // what a redirect to another origin yields - is masked under
    // "same-origin"; the policy came from the snapshot, not the final URL.
    // (No HTTP server runs in this test binary; WPT's
    // location-ancestor-origins-redirect-still-mask.sub.html redirects for
    // real.)
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const html =
        \\<!doctype html><body><script>
        \\  var result = 'pending';
        \\  addEventListener('message', function (e) { result = String(e.data); });
        \\</script>
        \\<iframe referrerpolicy="same-origin" src="data:text/html,<script>parent.postMessage([...location.ancestorOrigins].join(','), '*')</script>"></iframe>
        \\<iframe referrerpolicy="same-origin" id="same" srcdoc="<p>x"></iframe>
    ;
    try page.loadHTML(html, .{ .base_url = base_url });
    try awaitAnswer(browser, "result", "null");
    try awaitAnswer(browser, "document.getElementById('same').contentDocument.readyState == 'complete' ? [...frames[1].location.ancestorOrigins].join(',') : 'pending'", "http://web-platform.test:8000");
}

test "a masked origin stays masked below: the spec's grandchild example" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const html =
        \\<!doctype html><body>
        \\<iframe referrerpolicy="no-referrer" srcdoc="<iframe srcdoc='<p>g'></iframe>"></iframe>
    ;
    try page.loadHTML(html, .{ .base_url = base_url });
    try awaitAnswer(browser,
        \\(function () {
        \\  var inner = frames[0] && frames[0].frames[0];
        \\  if (!inner || inner.document.readyState !== 'complete') return 'pending';
        \\  return [...inner.location.ancestorOrigins].join(',') + '|' + [...frames[0].location.ancestorOrigins].join(',');
        \\})()
    , "http://web-platform.test:8000,null|null");
}
