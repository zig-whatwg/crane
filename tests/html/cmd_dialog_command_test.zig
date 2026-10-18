//! Dialog command validity is independent of the target's current open state.
const std = @import("std");
const browser_mod = @import("browser");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><button id=invoker></button><dialog id=target></dialog><div id=invalid></div>", .{ .base_url = "http://example.test/commands" });
    try page.runScript(
        \\const button = document.getElementById('invoker');
        \\const target = document.getElementById('target');
        \\const invalid = document.getElementById('invalid');
        \\const seen = [];
        \\target.addEventListener('command', event => {
        \\  seen.push([event.command, event.source === button, event.cancelable, event.composed]);
        \\  event.preventDefault();
        \\});
        \\button.commandForElement = target;
        \\for (const command of ['show-modal', 'close', 'request-close', 'sHoW-mOdAl']) {
        \\  button.command = command;
        \\  button.click();
        \\}
        \\if (seen.length !== 4) throw new Error('expected four valid dialog commands, received ' + seen.length);
        \\if (seen.some(event => !event[1] || !event[2] || event[3])) throw new Error('incorrect CommandEvent initialization');
        \\if (seen[3][0] !== 'sHoW-mOdAl') throw new Error('command content attribute case lost');
        \\if (target.open) throw new Error('canceled command changed dialog state');
        \\button.commandForElement = invalid;
        \\let invalidEvents = 0;
        \\invalid.addEventListener('command', () => ++invalidEvents);
        \\for (const command of ['show-modal', 'close', 'request-close']) {
        \\  button.command = command;
        \\  button.click();
        \\}
        \\if (invalidEvents) throw new Error('dialog commands dispatched on a div');
    );
}

test "dialog command validation dispatches before cancellation and rejects other elements" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
