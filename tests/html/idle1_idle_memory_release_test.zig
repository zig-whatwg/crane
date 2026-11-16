//! Lane idle1: a page that goes idle gives the allocator's free memory back
//! to the OS.
//!
//! The OS allocators keep what a page frees. On glibc a freed block that
//! lies between two live ones stays resident for the life of the process:
//! no malloc threshold reaches inside a heap, only malloc_trim does (lane
//! mem2 measured 221-228 MB of it on perf_bench's streams page, of which
//! malloc_trim(0) returned 188-195 MB). A browser returns such memory away
//! from the allocation path, when the page is idle (Chrome's
//! MemoryReclaimer, Firefox's idle purge task, WebKit's
//! releaseSystemMallocMemory). Crane's window event loop does the same
//! (src/browser/event_loop.zig, the turn's last step;
//! src/browser/memory_release.zig).
//!
//! Each test runs a whole Browser on a thread of its own.

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const platform = @import("platform");
const clock = @import("clock");
const helpers = @import("edges_node_holders_helpers.zig");

const mib = 1024 * 1024;

/// Where freed malloc memory can be seen leaving the process: glibc, whose
/// malloc_trim the platform calls. Not under ThreadSanitizer, whose own
/// allocator serves malloc there, and not on macOS, whose allocator has no
/// public call that returns its free memory (macOS 26 and later:
/// malloc_zone_pressure_relief answers 0; docs/lessons, lane idle1).
const resident_falls = builtin.os.tag == .linux and builtin.abi.isGnu() and !builtin.sanitize_thread;

/// Blocks of 64 KiB - below any mmap threshold glibc can have (its floor is
/// 128 KiB), so each is cut from a heap - written, so their pages are
/// resident; then all but every 64th freed. The kept blocks pin the heap:
/// nothing is at its top, and no threshold returns the rest.
const Fragmented = struct {
    const block_size = 64 * 1024;
    const count = 4000;
    const keep_every = 64;
    const freed_bytes = (count - (count + keep_every - 1) / keep_every) * block_size;

    kept: [count]?[*]u8 = @splat(null),

    fn make(self: *Fragmented) !void {
        for (&self.kept) |*slot| {
            const block: [*]u8 = @ptrCast(std.c.malloc(block_size) orelse return error.OutOfMemory);
            @memset(block[0..block_size], 0x5a);
            slot.* = block;
        }
    }

    fn freeMost(self: *Fragmented) void {
        for (&self.kept, 0..) |*slot, i| {
            if (i % keep_every == 0) continue;
            std.c.free(slot.*);
            slot.* = null;
        }
    }

    fn deinit(self: *Fragmented) void {
        for (&self.kept) |*slot| {
            if (slot.*) |block| std.c.free(block);
            slot.* = null;
        }
    }
};

fn residentBytes() !u64 {
    const reading = platform.residentMemory() orelse return error.NoResidentMemoryReading;
    return reading.resident_bytes;
}

/// Turn the loop for `ms` of real time, as a host with nothing to do does.
fn idleFor(page: helpers.Page, ms: i64) !void {
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const start = clock.monotonicMillis();
    while (clock.monotonicMillis() - start < ms) _ = loop.runOnceBlocking(5);
}

fn residentMemoryFallsWhenThePageGoesIdle() !void {
    const page = try helpers.Page.open();
    defer page.close();

    const fragmented = try testing.allocator.create(Fragmented);
    defer testing.allocator.destroy(fragmented);
    fragmented.* = .{};
    defer fragmented.deinit();
    try fragmented.make();
    const before = try residentBytes();
    fragmented.freeMost();

    // The page does a little work, then nothing: 400 ms is twice the idle
    // delay.
    try page.run("setTimeout(() => { globalThis.worked = true; }, 0);");
    try idleFor(page, 400);

    const after = try residentBytes();
    // 246 MiB were freed; at least half of it has left the process. Without
    // the release the frees return nothing (each freed block lies between
    // two kept ones), and resident memory does not fall at all.
    if (before < after + Fragmented.freed_bytes / 2) {
        std.debug.print("resident {d} MiB before the frees, {d} MiB after 400 ms idle; {d} MiB were freed\n", .{ before / mib, after / mib, Fragmented.freed_bytes / mib });
        return error.FreedMemoryStayedResident;
    }
}

test "malloc memory a page freed leaves the process once its event loop has been idle" {
    if (comptime !resident_falls) return error.SkipZigTest;
    try helpers.onFreshThread(residentMemoryFallsWhenThePageGoesIdle);
}
