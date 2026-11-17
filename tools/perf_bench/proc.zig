//! An engine's process set and what it uses: CPU time, instructions retired
//! where the host counts them, the memory it holds and its resident size,
//! read per process and summed over the set. The reading itself is the
//! operating system's:
//! - macOS (proc_darwin.zig): proc_pid_rusage (RUSAGE_INFO_V4), the method
//!   of lane chromeref1's sampler. The footprint is phys_footprint, what
//!   Activity Monitor calls Memory: a process's own dirty pages, anonymous
//!   and compressed. The kernel charges a shared page to one owner, so a
//!   sum over processes counts it once - unlike resident size, which counts
//!   a shared page in every process that maps it (kept for reference only);
//! - Linux (proc_linux.zig, lane tl2): /proc/<pid>/stat and
//!   /proc/<pid>/status. The footprint is RssAnon + VmSwap, the process's
//!   own anonymous memory, resident or swapped; CPU moves in clock ticks
//!   (10 ms); instructions are not measured (0, which the collector writes
//!   as "not measured"). Every published figure is macOS's: a Linux row is
//!   compared only with a Linux row of the same host.
//!
//! The set is the launched process and all its descendants, plus - for an
//! engine whose processes launchd starts, Safari's WebKit processes - every
//! process with one of the given names. CPU is summed per pid between two
//! readings, so a process that starts between them counts from zero; one
//! that ends between them loses what it used since the first reading (the
//! sampler's 50 ms readings keep that loss small; the report says so).
//!
//! A start time (`Usage.start_abs`, `absoluteNow`) is in the host's own
//! unit and compared only with another of the same host: mach absolute time
//! on macOS, clock ticks since boot on Linux - where a process started in
//! the same 10 ms tick as a reading of `absoluteNow` counts as started
//! after it.

const std = @import("std");
const builtin = @import("builtin");

/// The Linux reader's parsers are text in, figures out: tested on every OS.
pub const linux = @import("proc_linux.zig");

const os = switch (builtin.os.tag) {
    .macos => @import("proc_darwin.zig"),
    .linux => linux,
    else => struct {},
};

pub const supported = switch (builtin.os.tag) {
    .macos, .linux => true,
    else => false,
};

/// Whether the host counts the instructions a process retires
/// (`Usage.instructions`); where it does not, they read 0.
pub const counts_instructions = builtin.os.tag == .macos;

/// Now, in the clock a process's start time uses.
pub fn absoluteNow() u64 {
    if (!supported) return 0;
    return os.absoluteNow();
}

/// One process's figures at one moment.
pub const Usage = struct {
    pid: i32,
    /// User + system CPU, nanoseconds.
    cpu_ns: u64,
    instructions: u64,
    footprint: u64,
    resident: u64,
    /// When the process started (the host's unit: `absoluteNow`).
    start_abs: u64 = 0,
};

pub fn usageOf(pid: i32) ?Usage {
    if (!supported) return null;
    return os.usageOf(pid);
}

/// The most processes one set holds; more are ignored (and the count says
/// so).
pub const max_processes = 256;

/// Which processes belong to an engine.
pub const Selector = struct {
    /// The launched process: it and its descendants.
    root: i32,
    /// Processes outside the tree that belong to the engine, by exact
    /// process name (Safari's: launchd starts them) - and only those started
    /// at or after `started_after` (`absoluteNow`'s clock): another app's
    /// WebKit processes, there before the launch, are not the engine's.
    names: []const []const u8 = &.{},
    started_after: u64 = 0,
};

/// The pids of the set, into `out`; how many.
pub fn members(sel: Selector, out: []i32) usize {
    if (!supported) return 0;
    var n: usize = 0;
    if (sel.root > 0 and usageOf(sel.root) != null) {
        out[0] = sel.root;
        n = 1;
    }
    // Breadth-first over the tree: out[0..n] grows as children are found.
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var kids: [max_processes]i32 = undefined;
        const count = os.children(out[i], &kids);
        for (kids[0..count]) |k| {
            if (k <= 0 or n >= out.len) continue;
            if (std.mem.indexOfScalar(i32, out[0..n], k) != null) continue;
            out[n] = k;
            n += 1;
        }
    }
    if (sel.names.len > 0) {
        var by_name: [max_processes]i32 = undefined;
        const got = named(sel.names, sel.started_after, &by_name);
        for (by_name[0..got]) |p| {
            if (n >= out.len) break;
            if (std.mem.indexOfScalar(i32, out[0..n], p) != null) continue;
            out[n] = p;
            n += 1;
        }
    }
    return n;
}

/// A process's name: its executable's (macOS: at most 2 * MAXCOMLEN
/// characters; Linux: the kernel's 15).
pub fn nameOf(pid: i32, buf: []u8) error{NoSuchProcess}![]const u8 {
    if (!supported) return error.NoSuchProcess;
    return os.nameOf(pid, buf);
}

/// The pids of every process with one of `names` (exact process names)
/// started at or after `started_after` (`absoluteNow`'s clock; 0: any), into
/// `out`; how many.
pub fn named(names: []const []const u8, started_after: u64, out: []i32) usize {
    if (!supported or names.len == 0) return 0;
    var all: [4096]i32 = undefined;
    const count = os.allPids(&all);
    var n: usize = 0;
    for (all[0..count]) |p| {
        if (p <= 0 or n >= out.len) continue;
        var name_buf: [256]u8 = undefined;
        const name = nameOf(p, &name_buf) catch continue;
        for (names) |want| if (std.mem.eql(u8, name, want)) {
            const u = usageOf(p) orelse break;
            if (u.start_abs < started_after) break;
            out[n] = p;
            n += 1;
            break;
        };
    }
    return n;
}

/// The set at one moment: each member's figures.
pub const Reading = struct {
    count: usize = 0,
    usages: [max_processes]Usage = undefined,

    pub fn take(sel: Selector) Reading {
        var r: Reading = .{};
        var pids: [max_processes]i32 = undefined;
        const n = members(sel, &pids);
        for (pids[0..n]) |p| {
            if (usageOf(p)) |u| {
                r.usages[r.count] = u;
                r.count += 1;
            }
        }
        return r;
    }

    pub fn all(r: *const Reading) []const Usage {
        return r.usages[0..r.count];
    }

    pub fn footprint(r: *const Reading) u64 {
        var t: u64 = 0;
        for (r.all()) |u| t += u.footprint;
        return t;
    }

    pub fn resident(r: *const Reading) u64 {
        var t: u64 = 0;
        for (r.all()) |u| t += u.resident;
        return t;
    }

    /// CPU and instructions used from `before` to `r`: per pid, a process
    /// new since `before` counting from zero.
    pub fn since(r: *const Reading, before: *const Reading) Delta {
        var d: Delta = .{};
        for (r.all()) |u| {
            var cpu0: u64 = 0;
            var ins0: u64 = 0;
            for (before.all()) |b| if (b.pid == u.pid) {
                cpu0 = b.cpu_ns;
                ins0 = b.instructions;
                break;
            };
            d.cpu_ns += u.cpu_ns -| cpu0;
            d.instructions += u.instructions -| ins0;
        }
        return d;
    }
};

pub const Delta = struct {
    cpu_ns: u64 = 0,
    instructions: u64 = 0,

    pub fn cpuMs(d: Delta) f64 {
        return @as(f64, @floatFromInt(d.cpu_ns)) / 1e6;
    }
};

const testing = std.testing;

test {
    _ = linux;
}

/// This process's own start, once the clock has moved past it: Linux counts
/// a start in clock ticks, so a process younger than one tick has not
/// "started before now" yet.
fn startedBeforeNow(pid: i32) !void {
    const mine = usageOf(pid) orelse return error.TestUnexpectedResult;
    var spins: u64 = 0;
    while (absoluteNow() <= mine.start_abs) : (spins += 1) {
        if (spins > 2_000_000_000) return error.TestUnexpectedResult;
        std.atomic.spinLoopHint();
    }
}

test "this process reads: CPU and a footprint, and instructions where the host counts them" {
    if (!supported) return error.SkipZigTest;
    const me: i32 = @intCast(std.c.getpid());
    const a = usageOf(me) orelse return error.TestUnexpectedResult;
    try testing.expect(a.footprint > 0);
    try testing.expect(a.resident > 0);
    try testing.expectEqual(counts_instructions, a.instructions > 0);
    // Burn CPU until the reading moves forward: at once on macOS, within a
    // clock tick or two (10 ms each) on Linux.
    var x: u64 = 0;
    var b = a;
    var rounds: u32 = 0;
    while (b.cpu_ns <= a.cpu_ns and rounds < 2000) : (rounds += 1) {
        for (0..20_000_000) |i| x +%= i *% 2654435761;
        std.mem.doNotOptimizeAway(x);
        b = usageOf(me) orelse return error.TestUnexpectedResult;
    }
    try testing.expect(b.cpu_ns > a.cpu_ns);
}

test "a set: the root and its descendants, with no pid twice" {
    if (!supported) return error.SkipZigTest;
    const me: i32 = @intCast(std.c.getpid());
    var pids: [max_processes]i32 = undefined;
    const n = members(.{ .root = me }, &pids);
    try testing.expect(n >= 1);
    try testing.expectEqual(me, pids[0]);
    for (pids[0..n], 0..) |p, i| try testing.expect(std.mem.indexOfScalar(i32, pids[0..i], p) == null);
}

test "a set holds a child the process started, and its child" {
    if (!supported) return error.SkipZigTest;
    const io = testing.io;
    // A shell that starts a sleep of its own and waits for it: a child and
    // a grandchild.
    var child = try std.process.spawn(io, .{ .argv = &.{ "/bin/sh", "-c", "sleep 30 & wait" }, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore });
    const child_pid: i32 = child.id.?;
    defer {
        var all: [max_processes]i32 = undefined;
        const n = members(.{ .root = child_pid }, &all);
        for (all[0..n]) |p| std.posix.kill(p, .KILL) catch {};
        _ = child.wait(io) catch {};
    }
    const me: i32 = @intCast(std.c.getpid());
    var pids: [max_processes]i32 = undefined;
    // Until the shell has started its sleep (bounded).
    var n: usize = 0;
    var tries: u32 = 0;
    while (tries < 500) : (tries += 1) {
        n = members(.{ .root = me }, &pids);
        var under_child: [max_processes]i32 = undefined;
        if (members(.{ .root = child_pid }, &under_child) >= 2) break;
        std.Io.sleep(io, .fromMilliseconds(10), .awake) catch {};
    }
    try testing.expect(std.mem.indexOfScalar(i32, pids[0..n], child_pid) != null);
    var under_child: [max_processes]i32 = undefined;
    const below = members(.{ .root = child_pid }, &under_child);
    try testing.expect(below >= 2);
    // The grandchild is in this process's set too.
    n = members(.{ .root = me }, &pids);
    for (under_child[0..below]) |p| try testing.expect(std.mem.indexOfScalar(i32, pids[0..n], p) != null);
    // And the set's figures are its members': a footprint for each.
    const reading = Reading.take(.{ .root = child_pid });
    try testing.expect(reading.count >= 2);
    try testing.expect(reading.footprint() > 0);
}

test "a process named but started before the launch is not the engine's" {
    if (!supported) return error.SkipZigTest;
    // This process's own name, with a launch time after it started: not in
    // the set; with a launch time of 0: in it.
    const me: i32 = @intCast(std.c.getpid());
    try startedBeforeNow(me);
    var name_buf: [256]u8 = undefined;
    const name = try nameOf(me, &name_buf);
    const names = [_][]const u8{name};
    var pids: [max_processes]i32 = undefined;
    const later = members(.{ .root = 0, .names = &names, .started_after = absoluteNow() }, &pids);
    for (pids[0..later]) |p| try testing.expect(p != me);
    const any = members(.{ .root = 0, .names = &names, .started_after = 0 }, &pids);
    try testing.expect(std.mem.indexOfScalar(i32, pids[0..any], me) != null);
}

test "the processes of a name: every one, or only those started after a time" {
    if (!supported) return error.SkipZigTest;
    // This process, by its own name: found with no start bound, not found
    // when only processes started from now on count.
    const me: i32 = @intCast(std.c.getpid());
    try startedBeforeNow(me);
    var name_buf: [256]u8 = undefined;
    const name = try nameOf(me, &name_buf);
    const names = [_][]const u8{name};
    var pids: [max_processes]i32 = undefined;
    const any = named(&names, 0, &pids);
    try testing.expect(std.mem.indexOfScalar(i32, pids[0..any], me) != null);
    const later = named(&names, absoluteNow(), &pids);
    for (pids[0..later]) |p| try testing.expect(p != me);
    // A name no process has.
    try testing.expectEqual(@as(usize, 0), named(&.{"no-such-process-perf0b"}, 0, &pids));
}

test "a pid that does not exist reads as nothing" {
    if (!supported) return error.SkipZigTest;
    try testing.expectEqual(@as(?Usage, null), usageOf(0x7fff_fff0));
    var pids: [4]i32 = undefined;
    try testing.expectEqual(@as(usize, 0), members(.{ .root = 0x7fff_fff0 }, &pids));
}

test "a delta counts a new process from zero and an old one from its first reading" {
    var before: Reading = .{};
    before.usages[0] = .{ .pid = 1, .cpu_ns = 100, .instructions = 10, .footprint = 0, .resident = 0 };
    before.count = 1;
    var after: Reading = .{};
    after.usages[0] = .{ .pid = 1, .cpu_ns = 150, .instructions = 15, .footprint = 5, .resident = 7 };
    after.usages[1] = .{ .pid = 2, .cpu_ns = 30, .instructions = 3, .footprint = 6, .resident = 8 };
    after.count = 2;
    const d = after.since(&before);
    try testing.expectEqual(@as(u64, 80), d.cpu_ns);
    try testing.expectEqual(@as(u64, 8), d.instructions);
    try testing.expectEqual(@as(u64, 11), after.footprint());
    try testing.expectEqual(@as(u64, 15), after.resident());
}
