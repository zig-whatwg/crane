//! HTML 8.1.8.1: raw handlers own their source until first use.
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
        \\  let errors = 0;
        \\  addEventListener('error', e => { errors++; e.preventDefault(); });
        \\  const a = document.createElement('button');
        \\  a.setAttribute('onclick', ')');
        \\  if (errors !== 0) return false;
        \\  if (a.onclick !== null || errors !== 1) return false;
        \\  a.setAttribute('onclick', 'return 1');
        \\  a.setAttribute('onclick', 'return 2');
        \\  if (a.onclick() !== 2) return false;
        \\  a.setAttribute('onclick', 'return 3');
        \\  a.removeAttribute('onclick');
        \\  if (a.onclick !== null) return false;
        \\  a.setAttribute('onclick', 'return 4');
        \\  a.onclick = null;
        \\  // Both a detached and an attached raw handler survive until teardown.
        \\  a.setAttribute('onclick', 'return 5');
        \\  document.body.setAttribute('onresize', 'return 6');
        \\  return true;
        \\})()
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

test "raw handler replacement compilation removal and teardown release their source" {
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
