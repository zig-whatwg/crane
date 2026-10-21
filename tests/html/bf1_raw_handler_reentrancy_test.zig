//! Compiling a raw handler settles the value before reporting a syntax error.
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
        \\  const button = document.createElement('button');
        \\  const order = [];
        \\  let errors = 0, reentrantValue;
        \\  button.setAttribute('onclick', ')');
        \\  button.addEventListener('click', () => order.push('listener'));
        \\  addEventListener('error', e => {
        \\    ++errors;
        \\    reentrantValue = button.onclick;
        \\    button.onclick = () => order.push('handler');
        \\    e.preventDefault();
        \\  }, {once: true});
        \\  const recovered = button.onclick;
        \\  button.dispatchEvent(new Event('click'));
        \\  return errors === 1 && reentrantValue === null && typeof recovered === 'function' &&
        \\    order.join(',') === 'handler,listener';
        \\})()
    );
    defer result.release();
    try std.testing.expect(engine.toBoolean(browser.getRealm() orelse return error.NoRealm, result.borrow()));
}

test "raw handler syntax-error reentry preserves replacement and listener order" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = exercise();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
