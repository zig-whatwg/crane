//! Lane mp1: the Linux memory-pressure rule, over the text of /proc/meminfo.
//!
//! The linux platform's observer (src/platform/adapters/linux/
//! memory_pressure.zig) is a thread that reads /proc/meminfo and posts a
//! `memory_pressure` event when the level changes. The level is a pure
//! function of the file's text (src/platform/kit/posix/meminfo.zig), tested
//! here through the testing platform's control
//! `platform.adapter.memoryPressureLevelOfMeminfo`:
//!
//!   used % = (MemTotal - MemAvailable) * 100 / MemTotal, in whole percent
//!   critical at 95 % used and above, warning at 90 % and above
//!
//! WebKit's rule and numbers for Linux (Source/WebKit/UIProcess/linux/
//! MemoryPressureMonitor.cpp: the same integer percentage, a notice at 90 %,
//! critical at 95 %); Firefox's critical number is the same 5 % of MemTotal
//! left (xpcom/base/AvailableMemoryWatcherLinux.cpp,
//! browser.low_commit_space_threshold_percent). Chromium has no monitor on
//! desktop Linux. No answer - null - when the text does not say both
//! figures: the observer then posts nothing.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");

const Level = platform.MemoryPressureLevel;

fn levelOf(text: []const u8) ?Level {
    return platform.adapter.memoryPressureLevelOfMeminfo(text);
}

/// A /proc/meminfo with `total` and `available` kB, between the lines a
/// kernel writes around them.
fn meminfo(buffer: []u8, total: u64, available: u64) []const u8 {
    return std.fmt.bufPrint(buffer,
        \\MemTotal:       {d: >8} kB
        \\MemFree:          412340 kB
        \\MemAvailable:   {d: >8} kB
        \\Buffers:          183492 kB
        \\Cached:          9120468 kB
        \\SwapCached:            0 kB
        \\SwapTotal:       8388604 kB
        \\SwapFree:        8388604 kB
        \\
    , .{ total, available }) catch unreachable;
}

test "meminfo: a machine with memory to spare is at the normal level" {
    // server1's own figures, about 61 % available.
    const text =
        \\MemTotal:       65804256 kB
        \\MemFree:         1903284 kB
        \\MemAvailable:   40221168 kB
        \\Buffers:          911292 kB
        \\Cached:         36654120 kB
        \\
    ;
    try testing.expectEqual(Level.normal, levelOf(text).?);
}

test "meminfo: warning at 90 % used, critical at 95 % used, in whole percent" {
    var buffer: [512]u8 = undefined;
    const total: u64 = 1_000_000;
    // 89.9999 % used is 89: normal. 90 % is the warning.
    try testing.expectEqual(Level.normal, levelOf(meminfo(&buffer, total, 100_001)).?);
    try testing.expectEqual(Level.warning, levelOf(meminfo(&buffer, total, 100_000)).?);
    // 94.9999 % used is 94: still the warning. 95 % is critical.
    try testing.expectEqual(Level.warning, levelOf(meminfo(&buffer, total, 50_001)).?);
    try testing.expectEqual(Level.critical, levelOf(meminfo(&buffer, total, 50_000)).?);
    try testing.expectEqual(Level.critical, levelOf(meminfo(&buffer, total, 1)).?);
    try testing.expectEqual(Level.critical, levelOf(meminfo(&buffer, total, 0)).?);
    // All of it available, and more than all (a kernel's estimate may pass
    // the total by a page): normal, never a wrapped subtraction.
    try testing.expectEqual(Level.normal, levelOf(meminfo(&buffer, total, total)).?);
    try testing.expectEqual(Level.normal, levelOf(meminfo(&buffer, total, total + 4)).?);
}

test "meminfo: the rule holds for a machine of any size" {
    var buffer: [512]u8 = undefined;
    // 4 GiB and 4 TiB, each with 6 % and with 4 % available.
    inline for (.{ 4 * 1024 * 1024, 4 * 1024 * 1024 * 1024 }) |total| {
        try testing.expectEqual(Level.warning, levelOf(meminfo(&buffer, total, total / 100 * 6)).?);
        try testing.expectEqual(Level.critical, levelOf(meminfo(&buffer, total, total / 100 * 4)).?);
    }
    // No figure a kernel can write overflows the percentage.
    const huge: u64 = std.math.maxInt(u64) / 2;
    try testing.expectEqual(Level.normal, levelOf(meminfo(&buffer, huge, huge / 2)).?);
    try testing.expectEqual(Level.critical, levelOf(meminfo(&buffer, huge, huge / 100)).?);
}

test "meminfo: the two figures are found wherever their lines are, and only as whole keys" {
    // Another order, tabs for the padding, no unit, no last newline.
    try testing.expectEqual(Level.critical, levelOf("Cached: 5 kB\nMemAvailable:\t40 kB\nMemFree: 900 kB\nMemTotal:\t1000").?);
    // A key that only ends in, or begins with, the name is another key.
    try testing.expect(levelOf("XMemTotal: 1000 kB\nMemAvailable: 40 kB\n") == null);
    try testing.expect(levelOf("MemTotal: 1000 kB\nMemAvailableHuge: 40 kB\n") == null);
    // The first line of each name is the one read.
    try testing.expectEqual(Level.normal, levelOf("MemTotal: 1000 kB\nMemAvailable: 900 kB\nMemAvailable: 1 kB\n").?);
}

test "meminfo: no level without both figures" {
    // A kernel before 3.14 has no MemAvailable line.
    try testing.expect(levelOf("MemTotal: 1000 kB\nMemFree: 10 kB\n") == null);
    try testing.expect(levelOf("MemAvailable: 10 kB\n") == null);
    try testing.expect(levelOf("") == null);
    // Figures that are not numbers, and a total of nothing.
    try testing.expect(levelOf("MemTotal: lots kB\nMemAvailable: 10 kB\n") == null);
    try testing.expect(levelOf("MemTotal: 1000 kB\nMemAvailable: kB\n") == null);
    try testing.expect(levelOf("MemTotal: 0 kB\nMemAvailable: 0 kB\n") == null);
    try testing.expect(levelOf("MemTotal: -5 kB\nMemAvailable: 1 kB\n") == null);
}
