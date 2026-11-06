//! A window timer is a TASK on the timer task source, queued when its timeout
//! completes, in order with every other task (HTML 8.6 "timer initialization
//! steps" 10-13: "run steps after a timeout ... queue a global task on the
//! timer task source given global to run task"; 8.1.7.3: the event loop runs
//! the oldest runnable task). A zero-delay timer has nothing to wait for: its
//! task is queued at the setTimeout call, as Chromium (DOMTimer's
//! kJavascriptTimerImmediate, posted as an immediate task) and Gecko
//! (TimeoutExecutor's immediate dispatch) queue it - after the tasks queued
//! before the call, before the ones queued after - and a timer whose task is
//! queued but has not run is still
//! cleared by clearTimeout (step 8.2: "If id does not exist in global's map of
//! setTimeout and setInterval IDs, then abort these steps") and dropped with a
//! window that is gone (8.1.7.1: a task whose document can never be fully
//! active again is never run).
//!
//! Lane loadpath1: Crane fired a due timer from a poll of its own after the
//! turn's tasks, ahead of the tasks the code that armed it had queued. Each
//! page here comes over the network, as a WPT page does, and its script runs
//! in that navigation's commit - where the WPT toggle, selectionchange,
//! detached-frame and navigation-API files lost their order once every page
//! load became a navigation. (A page loaded from markup commits from a queued
//! task, which the old poll happened to keep in order.)
//!
//! Each test's Browser allocates from std.testing.allocator: a timer record a
//! path forgets to free fails the test as a leak.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const Site = @import("site.zig").Site;

fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

const DoneGoal = struct {
    browser: *Browser,
    fn met(context: *anyopaque) bool {
        const self: *DoneGoal = @ptrCast(@alignCast(context));
        const answer = evaluate(self.browser, "String(globalThis.done === true)") catch return false;
        defer testing.allocator.free(answer);
        return std.mem.eql(u8, answer, "true");
    }
};

/// Navigate a Browser to `path` on the test site, run the loop until the
/// page's script sets `done`, and expect its `log`.
fn expectLog(path: []const u8, expected: []const u8) !void {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const url = try site.url(testing.allocator, path);
    defer testing.allocator.free(url);
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateInPlace(url);
    var goal: DoneGoal = .{ .browser = browser };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = DoneGoal.met }, 15_000);
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    const log = try evaluate(browser, "globalThis.log.join()");
    defer testing.allocator.free(log);
    try testing.expectEqualStrings(expected, log);
}

test "a zero-delay timer runs after the task its setter queued before it" {
    // The details element's toggle task is queued first ("queue a details
    // toggle event task"), the timer's task when its zero timeout completes.
    try expectLog("/timer-order.html", "toggle,timeout");
}

test "a zero-delay timer's task is queued at the call: it runs before a task queued after it" {
    // setTimeout(0), then the details element's toggle task: the timer's
    // task was queued first (Chromium and Gecko; Crane queued it only when
    // the loop's poll found it due, behind the toggle).
    try expectLog("/timer-call-order.html", "timeout,toggle");
}

test "the ids of zero-delay timers and of armed timers are one space, each cleared by its own" {
    try expectLog("/timer-ids.html", "true,a");
}

test "window.close() queues its close as a task: a zero-delay timer set before it runs first" {
    // The popup's onload sets a zero-delay timer, then closes the popup: the
    // timer's task was queued before the close's (Chromium's Page::CloseSoon
    // posts its close task, Gecko's FinalClose dispatches its nsCloseEvent),
    // so it runs, then the popup unloads.
    try expectLog("/timer-close-opener.html", "timeout,unload");
}

test "a timer whose task is queued is still cleared by clearTimeout, and freed" {
    // The toggle task, queued before the timer's, runs first and clears the
    // timer, whose task is queued: it finds no id in the map (step 8.2) and
    // runs nothing; its record goes with it (std.testing.allocator).
    try expectLog("/timer-clear-queued.html", "cleared");
}

test "an interval that clears itself stops, and is freed" {
    try expectLog("/timer-interval.html", "tick1,tick2,tick3");
}

test "a detached frame's timer whose task is queued is dropped with the frame, and freed" {
    // The frame's timer task is queued at its call, after the toggle task,
    // which removes the frame - its window's map of active timers cleared,
    // its document destroyed - so the frame's timer task never runs
    // (8.1.7.1), and its record goes (std.testing.allocator).
    try expectLog("/timer-frame-queued.html", "removed");
}

test "a frame removed in the task that set its timer never runs it (settimeout-detached-iframe)" {
    try expectLog("/timer-detached-frame.html", "attached");
}
