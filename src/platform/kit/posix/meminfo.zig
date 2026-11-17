//! Linux memory pressure from /proc/meminfo: the rule a platform's observer
//! polls (src/platform/adapters/linux/memory_pressure.zig), as a pure
//! function of the file's text, and the read.
//!
//! Linux has no notification a browser on a desktop uses. What they do
//! (read 2026-11-16):
//!
//! - WebKit polls. Source/WebKit/UIProcess/linux/MemoryPressureMonitor.cpp
//!   (BSD-2, Igalia): a thread reads MemTotal and MemAvailable from
//!   /proc/meminfo, computes the memory used as a whole percentage, and
//!   notifies its processes at 90 % used, as critical at 95 % used. Its
//!   poll runs every 5 s and faster as memory fills, down to 1 s.
//! - Firefox polls. xpcom/base/AvailableMemoryWatcherLinux.cpp: a thread
//!   reads the same two figures every 5 s, every 1 s while memory is low;
//!   low is MemAvailable at 5 % of MemTotal or under
//!   (browser.low_commit_space_threshold_percent).
//! - Chromium has no monitor on desktop Linux (components/memory_pressure/
//!   system_memory_pressure_evaluator.cc, CreateDefault: none outside
//!   ChromeOS, macOS, Windows and Fuchsia), so it has no number here.
//!
//! Crane's rule is the one both pollers agree on, in WebKit's arithmetic:
//!
//!   used % = (MemTotal - MemAvailable) * 100 / MemTotal, rounded down
//!   critical: 95 % used or more (5 % available or less - both browsers)
//!   warning:  90 % used or more (WebKit's notice level)
//!
//! A kernel with no MemAvailable line (before 3.14) gives no reading, and
//! the observer then posts nothing: WebKit estimates the figure from the
//! zone watermarks there, which no supported kernel needs.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

/// 90 % used: the level at which WebKit's monitor notifies.
pub const warning_used_percent: u8 = 90;
/// 95 % used: the level at which WebKit's notice is critical; the 5 % left
/// is Firefox's low-memory threshold too.
pub const critical_used_percent: u8 = 95;

/// The two figures of /proc/meminfo the rule reads, in kB as written.
pub const Reading = struct {
    total_kb: u64,
    available_kb: u64,

    /// The memory used, in whole percent of the total, rounded down. 0 when
    /// the kernel's estimate of what is available passes the total.
    pub fn usedPercent(self: Reading) u8 {
        const used = self.total_kb -| self.available_kb;
        // Wide: no figure a kernel can write overflows the product.
        return @intCast((@as(u128, used) * 100) / self.total_kb);
    }

    pub fn level(self: Reading) platform.MemoryPressureLevel {
        const used = self.usedPercent();
        if (used >= critical_used_percent) return .critical;
        if (used >= warning_used_percent) return .warning;
        return .normal;
    }
};

/// The figure after `key` (a whole line key, with its colon) in `text`: the
/// first such line's. Null when no line has the key or no number follows it.
fn figure(text: []const u8, comptime key: []const u8) ?u64 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, key)) continue;
        const rest = std.mem.trimStart(u8, line[key.len..], " \t");
        var end: usize = 0;
        while (end < rest.len and std.ascii.isDigit(rest[end])) end += 1;
        if (end == 0) return null;
        return std.fmt.parseInt(u64, rest[0..end], 10) catch null;
    }
    return null;
}

/// MemTotal and MemAvailable of a /proc/meminfo's `text`. Null when either
/// is missing or is not a number, or the total is 0.
pub fn parse(text: []const u8) ?Reading {
    const total = figure(text, "MemTotal:") orelse return null;
    const available = figure(text, "MemAvailable:") orelse return null;
    if (total == 0) return null;
    return .{ .total_kb = total, .available_kb = available };
}

/// The level a /proc/meminfo's `text` is at, or null when it does not say.
pub fn levelOf(text: []const u8) ?platform.MemoryPressureLevel {
    return (parse(text) orelse return null).level();
}

/// This machine's reading now; null where there is no /proc/meminfo (any OS
/// but Linux) or it does not say. Plain libc calls, as
/// src/platform/memory.zig reads /proc/self/statm: a procfs read has no
/// failure worth more than "no answer", and the observer's thread reads it
/// with no allocation. Both figures are in the file's first lines; 2 KiB
/// holds them on every kernel that writes MemAvailable (it is the third
/// line).
pub fn read() ?Reading {
    if (comptime builtin.os.tag != .linux) return null;
    var buffer: [2048]u8 = undefined;
    const fd = std.c.open("/proc/meminfo", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    const count = std.c.read(fd, &buffer, buffer.len);
    if (count <= 0) return null;
    return parse(buffer[0..@intCast(count)]);
}
