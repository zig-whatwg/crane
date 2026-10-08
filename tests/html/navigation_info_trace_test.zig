//! Navigation tracker info stays distinct through reentrant events and GC.
const std = @import("std");
const browser_mod = @import("browser");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/start" });
    try page.runScript(
        \\globalThis.seen = 0;
        \\globalThis.failures = [];
        \\globalThis.weakInfo = [];
        \\for (let i = 0; i < 32; ++i) {
        \\  const outer = {kind: 'outer', cycle: navigation};
        \\  const inner = {kind: 'inner', cycle: navigation};
        \\  weakInfo.push(new WeakRef(outer), new WeakRef(inner));
        \\  navigation.onnavigate = event => {
        \\    ++seen;
        \\    TestUtils.gc();
        \\    if (event.info === outer) {
        \\      const result = navigation.navigate('#inner', {info: inner});
        \\      result.committed.catch(() => {});
        \\      result.finished.catch(() => {});
        \\      TestUtils.gc();
        \\      if (event.info !== outer) failures.push('outer info overwritten');
        \\    } else if (event.info !== inner) failures.push('inner info lost');
        \\    event.preventDefault();
        \\  };
        \\  const result = navigation.navigate('#outer', {info: outer});
        \\  result.committed.catch(() => {});
        \\  result.finished.catch(() => {});
        \\}
        \\navigation.onnavigate = null;
        \\if (seen !== 64 || failures.length) throw new Error('reentrant info: ' + seen + '/' + failures);
    );
    // Leave the creating job before collecting WeakRef targets.
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weakInfo.some(ref => ref.deref() !== undefined))
        \\  throw new Error('completed tracker retains info');
    );
}

test "reentrant navigation keeps each info identity then releases completed tracker values" {
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
