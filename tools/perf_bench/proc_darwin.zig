//! macOS's side of proc.zig: one process's figures from proc_pid_rusage
//! (RUSAGE_INFO_V4), its children from proc_listchildpids, every pid from
//! proc_listallpids, a name from proc_name - the method of lane chromeref1's
//! sampler (wpt-results/lanes/chromeref/scripts/chrome-ref.sh,
//! `sample_tree`), in Zig. Imported on macOS only: its externs are
//! libSystem's.

const std = @import("std");
const proc = @import("proc.zig");
const Usage = proc.Usage;

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
    return mach_absolute_time();
}

/// rusage times are mach absolute time units (24 MHz ticks on Apple
/// silicon, nanoseconds on Intel): `ns = ticks * numer / denom`.
fn ticksToNs(ticks: u64) u64 {
    var tb: MachTimebase = .{ .numer = 1, .denom = 1 };
    _ = mach_timebase_info(&tb);
    if (tb.denom == 0) return ticks;
    return @intCast(@as(u128, ticks) * tb.numer / tb.denom);
}

pub fn usageOf(pid: i32) ?Usage {
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

/// The pids of `pid`'s children, into `out`; how many.
pub fn children(pid: i32, out: []i32) usize {
    var kids: [proc.max_processes]c_int = undefined;
    const got = proc_listchildpids(pid, &kids, @intCast(@sizeOf(@TypeOf(kids))));
    if (got <= 0) return 0;
    // proc_listchildpids returns a count of pids (not bytes) on current
    // macOS; clamp either way.
    const count: usize = @min(@as(usize, @intCast(got)), kids.len);
    var n: usize = 0;
    for (kids[0..count]) |k| {
        if (k <= 0 or n >= out.len) continue;
        out[n] = k;
        n += 1;
    }
    return n;
}

/// Every pid, into `out`; how many.
pub fn allPids(out: []i32) usize {
    const got = proc_listallpids(out.ptr, @intCast(out.len * @sizeOf(i32)));
    if (got <= 0) return 0;
    return @min(@as(usize, @intCast(got)), out.len);
}

/// A process's name (proc_name: its executable's, at most 2 * MAXCOMLEN).
pub fn nameOf(pid: i32, buf: []u8) error{NoSuchProcess}![]const u8 {
    const len = proc_name(pid, buf.ptr, @intCast(buf.len));
    if (len <= 0) return error.NoSuchProcess;
    return buf[0..@intCast(len)];
}
