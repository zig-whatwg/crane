//! An engine's process set and what it uses: CPU time, instructions retired,
//! phys_footprint and resident size, read per process with macOS's
//! proc_pid_rusage (RUSAGE_INFO_V4) and summed over the set - the method of
//! lane chromeref1's sampler (wpt-results/lanes/chromeref/scripts/
//! chrome-ref.sh, `sample_tree`), in Zig.
//!
//! phys_footprint is what Activity Monitor calls Memory: a process's own
//! dirty pages, anonymous and compressed. The kernel charges a shared page to
//! one owner, so a sum over processes counts it once - unlike resident size,
//! which counts a shared page in every process that maps it (kept for
//! reference only).
//!
//! The set is the launched process and all its descendants
//! (proc_listchildpids, recursively), plus - for an engine whose processes
//! launchd starts, Safari's WebKit processes - every process with one of the
//! given names. CPU is summed per pid between two readings, so a process
//! that starts between them counts from zero; one that ends between them
//! loses what it used since the first reading (the sampler's 50 ms readings
//! keep that loss small; the report says so).

const std = @import("std");
const builtin = @import("builtin");

pub const supported = builtin.os.tag == .macos;

const RusageInfoV4 = extern struct {
    uuid: [16]u8,
    user_time: u64,
    system_time: u64,
    pkg_idle_wkups: u64,
    interrupt_wkups: u64,
    pageins: u64,
    wired_size: u64,
    resident_size: u64,
    phys_footprint: u64,
    proc_start_abstime: u64,
    proc_exit_abstime: u64,
    child_user_time: u64,
    child_system_time: u64,
    child_pkg_idle_wkups: u64,
    child_interrupt_wkups: u64,
    child_pageins: u64,
    child_elapsed_abstime: u64,
    diskio_bytesread: u64,
    diskio_byteswritten: u64,
    cpu_time_qos_default: u64,
    cpu_time_qos_maintenance: u64,
    cpu_time_qos_background: u64,
    cpu_time_qos_utility: u64,
    cpu_time_qos_legacy: u64,
    cpu_time_qos_user_initiated: u64,
    cpu_time_qos_user_interactive: u64,
    billed_system_time: u64,
    serviced_system_time: u64,
    logical_writes: u64,
    lifetime_max_phys_footprint: u64,
    instructions: u64,
    cycles: u64,
    billed_energy: u64,
    serviced_energy: u64,
    interval_max_phys_footprint: u64,
    runnable_time: u64,
};

comptime {
    // <sys/resource.h>: 16 bytes of uuid and 35 u64 fields.
    std.debug.assert(@sizeOf(RusageInfoV4) == 16 + 35 * 8);
    std.debug.assert(@offsetOf(RusageInfoV4, "phys_footprint") == 72);
}

const RUSAGE_INFO_V4 = 4;

const MachTimebase = extern struct { numer: u32, denom: u32 };

extern "c" fn proc_pid_rusage(pid: c_int, flavor: c_int, buffer: *RusageInfoV4) c_int;
extern "c" fn proc_listchildpids(ppid: c_int, buffer: ?*anyopaque, buffersize: c_int) c_int;
extern "c" fn proc_listallpids(buffer: ?*anyopaque, buffersize: c_int) c_int;
extern "c" fn proc_name(pid: c_int, buffer: [*]u8, buffersize: u32) c_int;
extern "c" fn mach_timebase_info(info: *MachTimebase) c_int;
extern "c" fn mach_absolute_time() u64;

/// Now, in the clock rusage's `proc_start_abstime` uses.
pub fn absoluteNow() u64 {
    if (!supported) return 0;
    return mach_absolute_time();
}

/// One process's figures at one moment.
pub const Usage = struct {
    pid: i32,
    /// User + system CPU, nanoseconds.
    cpu_ns: u64,
    instructions: u64,
    footprint: u64,
    resident: u64,
    /// When the process started (mach absolute time).
    start_abs: u64 = 0,
};

/// rusage times are mach absolute time units (24 MHz ticks on Apple
/// silicon, nanoseconds on Intel): `ns = ticks * numer / denom`.
fn ticksToNs(ticks: u64) u64 {
    var tb: MachTimebase = .{ .numer = 1, .denom = 1 };
    _ = mach_timebase_info(&tb);
    if (tb.denom == 0) return ticks;
    return @intCast(@as(u128, ticks) * tb.numer / tb.denom);
}

pub fn usageOf(pid: i32) ?Usage {
    if (!supported) return null;
    var info: RusageInfoV4 = undefined;
    if (proc_pid_rusage(pid, RUSAGE_INFO_V4, &info) != 0) return null;
    return .{
        .pid = pid,
        .cpu_ns = ticksToNs(info.user_time + info.system_time),
        .instructions = info.instructions,
        .footprint = info.phys_footprint,
        .resident = info.resident_size,
        .start_abs = info.proc_start_abstime,
    };
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
    /// at or after `started_after` (mach absolute time): another app's WebKit
    /// processes, there before the launch, are not the engine's.
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
        var kids: [max_processes]c_int = undefined;
        const got = proc_listchildpids(out[i], &kids, @intCast(@sizeOf(@TypeOf(kids))));
        if (got <= 0) continue;
        // proc_listchildpids returns a count of pids (not bytes) on current
        // macOS; clamp either way.
        const count: usize = @min(@as(usize, @intCast(got)), kids.len);
        for (kids[0..count]) |k| {
            if (k <= 0 or n >= out.len) continue;
            if (std.mem.indexOfScalar(i32, out[0..n], k) != null) continue;
            out[n] = k;
            n += 1;
        }
    }
    if (sel.names.len > 0) {
        var all: [4096]c_int = undefined;
        const got = proc_listallpids(&all, @intCast(@sizeOf(@TypeOf(all))));
        if (got > 0) {
            const count: usize = @min(@as(usize, @intCast(got)), all.len);
            for (all[0..count]) |p| {
                if (p <= 0 or n >= out.len) continue;
                if (std.mem.indexOfScalar(i32, out[0..n], p) != null) continue;
                var name_buf: [256]u8 = undefined;
                const len = proc_name(p, &name_buf, name_buf.len);
                if (len <= 0) continue;
                const name = name_buf[0..@intCast(len)];
                for (sel.names) |want| if (std.mem.eql(u8, name, want)) {
                    const u = usageOf(p) orelse break;
                    if (u.start_abs < sel.started_after) break;
                    out[n] = p;
                    n += 1;
                    break;
                };
            }
        }
    }
    return n;
}

// RED STUB
pub fn nameOf(pid: i32, buf: []u8) ![]const u8 {
    _ = pid;
    return buf[0..0];
}

// RED STUB
pub fn named(names: []const []const u8, started_after: u64, out: []i32) usize {
    _ = names;
    _ = started_after;
    _ = out;
    return 0;
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

test "this process reads: CPU, instructions and a footprint" {
    if (!supported) return error.SkipZigTest;
    const me: i32 = @intCast(std.c.getpid());
    const a = usageOf(me) orelse return error.TestUnexpectedResult;
    try testing.expect(a.footprint > 0);
    try testing.expect(a.resident > 0);
    // Burn a little CPU; the reading moves forward.
    var x: u64 = 0;
    for (0..20_000_000) |i| x +%= i *% 2654435761;
    std.mem.doNotOptimizeAway(x);
    const b = usageOf(me) orelse return error.TestUnexpectedResult;
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

test "a process named but started before the launch is not the engine's" {
    if (!supported) return error.SkipZigTest;
    // This process's own name, with a launch time after it started: not in
    // the set; with a launch time of 0: in it.
    const me: i32 = @intCast(std.c.getpid());
    var name_buf: [256]u8 = undefined;
    const len = proc_name(me, &name_buf, name_buf.len);
    try testing.expect(len > 0);
    const names = [_][]const u8{name_buf[0..@intCast(len)]};
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
    var name_buf: [256]u8 = undefined;
    const len = proc_name(me, &name_buf, name_buf.len);
    try testing.expect(len > 0);
    const names = [_][]const u8{name_buf[0..@intCast(len)]};
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
