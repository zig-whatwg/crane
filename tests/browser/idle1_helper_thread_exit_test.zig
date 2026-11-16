//! Lane idle1: a host that never ends the process (crane.Process.deinit ->
//! platform.deinitializePlatform) still exits cleanly with the platform's
//! helper thread parked.
//!
//! The thread that returns the allocator's free memory
//! (src/platform/kit/posix/free_memory.zig) is started by the first request
//! and joined by deinitializePlatform. The repl and the WPT runner end the
//! process themselves; a host that only makes Browsers does not - a test
//! executable under the launcher, and an embedder through the C API
//! (src/lib_exports.zig: whatwg_browser_create is Browser.init, which starts
//! the process for itself, and whatwg_runtime_shutdown ends the engine, not
//! the platform). Such a process ends with the thread still parked on its
//! futex, and must end as any other: this test starts the thread through a
//! Browser made the C API's way, ends the Browser, and returns. The launcher
//! runs it in a process of its own (the suite's batch is 1), so its verdict
//! is that process's exit: no hang, no crash, no leak under
//! std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const memory_release = browser_mod.memory_release;

test "a process that never ends the platform exits cleanly with the helper thread parked" {
    // A gate of the test's own, on the platform's clock and allocator: the
    // process's gate may be held off by an earlier release in this process.
    var gate: memory_release.Gate = .{};
    defer gate.settle();
    // As whatwg_browser_create: Browser.init, nothing started beforehand.
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = &gate;

    // The Browser idles: after 200 ms its loop posts a request, the
    // platform starts its thread, and the thread tells the gate when the
    // release has ended. A turn with nothing pending takes about a
    // millisecond.
    var turns: usize = 0;
    while (gate.count() == 0) : (turns += 1) {
        if (turns > 60_000) return error.NeverReleased;
        _ = loop.runOnceBlocking(5);
    }
    try testing.expectEqual(@as(u64, 1), gate.count());
    // No Process.deinit, no deinitializePlatform: the thread stays parked,
    // and the process ends with it.
}
