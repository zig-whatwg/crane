//! An idle remote end makes no syscalls (lane tpc, main 2026-11-22 6:07 AM
//! ET): with no client, the acceptor thread blocks in one wait until a
//! connection comes or the server stops - as Chrome's DevToolsHttpHandler's
//! socket watcher on its IO thread's message loop wakes only for a
//! connection or a quit - and Server.stop wakes that wait. Before, the
//! acceptor waited 200 ms at a time to look at whether it was stopping: five
//! wakeups a second for the server's whole life.
//!
//! The measure is Server.accept_waits: how many waits the acceptor began.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const platform = @import("platform");

const BrowserHost = browser_mod.BrowserHost;

test "an idle devtools server's acceptor makes one wait and no more, and stop ends it at once" {
    const allocator = testing.allocator;
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    var stopped = false;
    defer if (!stopped) server.stop();

    // Idle for 700 ms: a polling acceptor would have begun three or four
    // waits by now.
    platform.sleepThread(700 * std.time.ns_per_ms);
    try testing.expectEqual(@as(u32, 1), server.accept_waits.load(.acquire));

    // Stop wakes the blocked wait (it would block for ever otherwise: the
    // test hangs to its timeout).
    server.stop();
    stopped = true;
}
