//! HTML "in body" start and end tags that close what they imply: list
//! items, definitions and buttons (HTML 13.2.6.4.7). The tree builder had no steps for
//! them, so "<li>x<li>y" made nested items, in the live parser and in
//! DOMParser alike. Each case is parsed both ways - by document.write into a
//! frame's document (the live, scripted parser) and by DOMParser (the
//! tree-then-convert path) - and both must give the spec's tree, which is
//! what Chrome, Firefox and Safari make.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
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

/// Parse each `[markup, expected body innerHTML]` both ways in a fresh page;
/// "ok", or every mismatch.
fn compare(comptime cases: []const u8) !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/implied-end-tags" });
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const cases =
    ++ cases ++
        \\;
        \\  const frame = document.body.appendChild(document.createElement('iframe')).contentDocument;
        \\  const failures = [];
        \\  for (const [markup, expected] of cases) {
        \\    frame.open();
        \\    frame.write('<!doctype html><body>' + markup);
        \\    frame.close();
        \\    const live = frame.body.innerHTML;
        \\    const parsed = new DOMParser().parseFromString('<!doctype html><body>' + markup, 'text/html').body.innerHTML;
        \\    if (live !== expected) failures.push('live ' + markup + ' => ' + live);
        \\    if (parsed !== expected) failures.push('DOMParser ' + markup + ' => ' + parsed);
        \\  }
        \\  return failures.length ? failures.join('\n') : 'ok';
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ok", result);
}

fn listsDefinitionsAndButtons() !void {
    try compare(
        \\[
        \\  ['<ul><li>x<li>y</ul>', '<ul><li>x</li><li>y</li></ul>'],
        \\  ['<ul><li>a<ul><li>b</ul><li>c</ul>', '<ul><li>a<ul><li>b</li></ul></li><li>c</li></ul>'],
        \\  ['<li><div><li>x', '<li><div></div></li><li>x</li>'],
        \\  ['<li><section><li>x', '<li><section><li>x</li></section></li>'],
        \\  ['<dl><dt>a<dd>b<dt>c</dl>', '<dl><dt>a</dt><dd>b</dd><dt>c</dt></dl>'],
        \\  ['<dl><dd>a<dd>b</dl>', '<dl><dd>a</dd><dd>b</dd></dl>'],
        \\  ['<p>a<li>b', '<p>a</p><li>b</li>'],
        \\  ['<p>a<dd>b', '<p>a</p><dd>b</dd>'],
        \\  ['<p>a<p>b', '<p>a</p><p>b</p>'],
        \\  ['<button>a<button>b', '<button>a</button><button>b</button>'],
        \\  ['<ul><li>a</li>b</ul>', '<ul><li>a</li>b</ul>'],
        \\  ['<li>a</dd>b', '<li>ab</li>'],
        \\  ['<dl><dt>a</dt><dd>b</dd></dl>', '<dl><dt>a</dt><dd>b</dd></dl>'],
        \\]
    );
}

test "li, dd, dt, p and button start tags close what they imply, live and in DOMParser" {
    try onFreshThread(listsDefinitionsAndButtons);
}
