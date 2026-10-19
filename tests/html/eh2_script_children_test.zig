//! Browser-agreed script preparation triggers (DOM 808/1261, HTML 10188/4354).
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(
        \\(() => {
        \\  window.__childrenRuns = 0;
        \\  const s = document.createElement('script');
        \\  s.type = 'inert';
        \\  s.textContent = '__childrenRuns++';
        \\  const child = s.appendChild(document.createElement('i'));
        \\  document.body.append(s);
        \\  s.type = '';
        \\  child.remove();
        \\  if (__childrenRuns !== 0) return false;
        \\  s.appendChild(document.createTextNode(';'));
        \\  if (__childrenRuns !== 1) return false;
        \\  const second = document.createElement('script');
        \\  const text = second.appendChild(document.createTextNode(''));
        \\  document.body.append(second);
        \\  text.data = '__childrenRuns++';
        \\  return __childrenRuns === 2;
        \\})()
    );
    defer result.release();
    try std.testing.expect(engine.toBoolean(browser.getRealm() orelse return error.NoRealm, result.borrow()));
}

test "script preparation skips child removal and retains insertion and text replacement" {
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
