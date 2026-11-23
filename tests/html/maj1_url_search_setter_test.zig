//! URL's search setter step 6 (url.spec.whatwg.org, 2026): "Set this's query
//! object's list to the result of parsing url's query" - the query the basic
//! URL parser left, from which it removed every ASCII tab or newline - not the
//! given input. A searchParams obtained before the set sees the same list as
//! one obtained after it. Firefox and Safari ship this (wpt.fyi 2358bd4835,
//! url/url-setters-stripping.any.html "updates previously obtained
//! searchParams": Firefox and Safari PASS, Chrome FAIL).
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(
        \\(() => {
        \\  for (const input of ['\ntest', 'te\tst', 'test\r', '?te\nst=1']) {
        \\    const url = new URL('https://example.com/');
        \\    const before = url.searchParams;
        \\    url.search = input;
        \\    if ([...before.keys()].join() !== 'test') return false;
        \\    if ([...url.searchParams.keys()].join() !== 'test') return false;
        \\  }
        \\  // The value is stripped as well, and the empty string empties the list.
        \\  const url = new URL('https://example.com/?a=1');
        \\  const params = url.searchParams;
        \\  url.search = 'b=x\ny';
        \\  if (params.get('b') !== 'xy') return false;
        \\  url.search = '';
        \\  return params.size === 0 && url.href === 'https://example.com/';
        \\})()
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

test "the search setter's list is parsed from the URL's query, tabs and newlines removed" {
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
