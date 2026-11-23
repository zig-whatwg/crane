//! HTML 6.12.6: popoverTargetAction reflects popovertargetaction, limited to
//! only known values (toggle, show, hide), whose missing value default and
//! invalid value default are both the Toggle state - on button and input
//! elements (PopoverTargetAttributes). All three browsers (wpt.fyi
//! 2358bd4835, html/dom/idlharness.https.html?include=HTML.+ "must inherit
//! property popoverTargetAction with the proper type").
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
        \\  for (const make of [() => document.createElement('button'), () => { const i = document.createElement('input'); i.type = 'button'; return i; }]) {
        \\    const e = make();
        \\    if (e.popoverTargetAction !== 'toggle') return false;
        \\    e.popoverTargetAction = 'SHOW';
        \\    if (e.getAttribute('popovertargetaction') !== 'SHOW' || e.popoverTargetAction !== 'show') return false;
        \\    e.setAttribute('popovertargetaction', 'hide');
        \\    if (e.popoverTargetAction !== 'hide') return false;
        \\    e.setAttribute('popovertargetaction', 'bogus');
        \\    if (e.popoverTargetAction !== 'toggle') return false;
        \\    e.setAttribute('popovertargetaction', '');
        \\    if (e.popoverTargetAction !== 'toggle') return false;
        \\  }
        \\  return true;
        \\})()
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

test "popoverTargetAction reflects popovertargetaction, limited to toggle, show and hide" {
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
