//! HTML "report an exception" step 6: a global's "in error reporting mode" is
//! the global's own flag (lane gstate3: the realm's, never a process-wide set).
//! Its error event handler can report another exception for another global,
//! which can report for another, and so on; whatever the depth, a report for a
//! global that is already reporting fires no second error event. Crane kept
//! the flag as eight process-wide slots, shared by every Browser on every
//! thread: the ninth global to nest found the slots full and was not guarded,
//! so its handler's report for itself fired again, and again.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
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

/// Nine frames' windows, each one's error handler reporting for the next; the
/// ninth's reports for itself. Its report from inside its own handler must
/// fire nothing: the ninth window is in error reporting mode.
const nested_reports =
    \\(() => {
    \\  const windows = [];
    \\  for (let i = 0; i < 9; i++) {
    \\    const frame = document.createElement("iframe");
    \\    document.body.appendChild(frame);
    \\    windows.push(frame.contentWindow);
    \\  }
    \\  let last = 0;
    \\  for (let i = 0; i < 8; i++) {
    \\    windows[i].onerror = () => { windows[i + 1].reportError(new Error("next")); return true; };
    \\  }
    \\  windows[8].onerror = () => {
    \\    last++;
    \\    if (last < 20) windows[8].reportError(new Error("again"));
    \\    return true;
    \\  };
    \\  windows[0].reportError(new Error("first"));
    \\  return last === 1 ? "ok" : "the ninth window's handler ran " + last + " times";
    \\})()
;

fn ninthNestedGlobalIsGuarded() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "http://gs3-report.test/page.html";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = url });

    const realm = browser.getRealm() orelse return error.NoRealm;
    const held = try browser.evaluateScript(nested_reports);
    defer held.release();
    const answer = try engine.convertToDOMString(realm, held.borrow(), testing.allocator);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("ok", answer);
}

test "a global nested nine deep in error reporting is still in error reporting mode" {
    try onFreshThread(ninthNestedGlobalIsGuarded);
}
