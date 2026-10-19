const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn detachesXHRFrame() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "https://pm2.test/index.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    const result = try browser.evaluateScript(
        \\(() => {
        \\  const frame = document.createElement('iframe');
        \\  document.body.appendChild(frame);
        \\  const xhr = new frame.contentWindow.XMLHttpRequest();
        \\  let detached = false;
        \\  const events = [];
        \\  xhr.open('GET', 'pm2-unsupported-scheme://network-error', false);
        \\  xhr.addEventListener('readystatechange', () => {
        \\    if (xhr.readyState === 4) events.push('done');
        \\  });
        \\  xhr.addEventListener('error', () => {
        \\    events.push('error');
        \\    frame.remove();
        \\    detached = true;
        \\  });
        \\  xhr.addEventListener('loadend', () => events.push('loadend'));
        \\  try { xhr.send(); } catch (_) {}
        \\  return (detached ? 'detached:' : 'attached:') + events.join(',');
        \\})()
    );
    defer result.release();
    const observed = try engine.convertToDOMString(browser.getRealm().?, result.borrow(), std.testing.allocator);
    defer std.testing.allocator.free(observed);
    // Q13: a reachable frame realm survives removal until collection or
    // page end. This is the event control, not the defensive guard's proof.
    try std.testing.expectEqualStrings("detached:done,error,loadend", observed);
}

test "a synchronous XHR network error handler can detach its frame and finish terminal events" {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            detachesXHRFrame() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
