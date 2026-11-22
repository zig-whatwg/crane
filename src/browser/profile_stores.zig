//! The profile's stores: how a Browser given a profile directory (the
//! user's ruling D6, 2026-11-21: Puppeteer's and Playwright's
//! --user-data-dir fully supported; docs/instances.md) hands its platform
//! state to each part of its web state that persists there, and flushes
//! them at its end. A Browser with no profile directory calls neither, and
//! keeps everything in memory exactly as before.
//!
//! Browser.init calls `attach` once its platform state and its event loop
//! exist and before its first realm; Browser.deinit calls `flush` once its
//! pages have ended and before its event loop and its platform state end.
//! The platform state ends BEFORE the scope's supplements (Browser.deinit),
//! so no supplement touches a store at its own end: what is pending is
//! written here.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const storage = @import("storage");
const EventLoop = @import("event_loop.zig").EventLoop;

/// Hand `browser` - the Browser's platform state, whose stores are under
/// its profile directory - to each persisting part of the Browser's web
/// state, with the Browser's event loop to arm its commits on.
pub fn attach(scope: *runtime.BrowserScope, browser: *platform.BrowserPlatform, loop: *EventLoop) !void {
    // localStorage (D6 step 2): read per area on first use, committed in
    // batches (storage/profile.zig).
    const user_agent_storage = try scope.of(storage.UserAgentStorage);
    try user_agent_storage.attachProfile(browser, commitTimer(loop));
}

/// Write what is pending to the profile: the Browser's end.
pub fn flush(scope: *runtime.BrowserScope) void {
    if (scope.existing(storage.UserAgentStorage)) |user_agent_storage| user_agent_storage.flushProfile();
}

/// The Browser's event loop's timers as storage's commit timer: an owned
/// timer (runtime.TimerInterface.setTimeoutOwned), dropped if the loop
/// ends with it armed. The loop outlives every commit armed on it - it ends
/// after `flush`.
fn commitTimer(loop: *EventLoop) ?storage.profile.CommitTimer {
    if (loop.timerInterface() == null) return null;
    return .{ .context = loop, .arm = arm, .cancel = cancel };
}

fn loopOf(context: *anyopaque) *EventLoop {
    return @ptrCast(@alignCast(context));
}

fn arm(context: *anyopaque, ms: u64, run: *const fn (?*anyopaque) void, data: ?*anyopaque, drop: *const fn (?*anyopaque) void) u64 {
    const timers = loopOf(context).timerInterface() orelse return 0;
    return timers.setTimeoutOwned(ms, run, data, drop);
}

fn cancel(context: *anyopaque, id: u64) bool {
    const timers = loopOf(context).timerInterface() orelse return false;
    return timers.clearTimeout(id);
}
