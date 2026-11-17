//! Linux's side of proc.zig: one process's figures from /proc/<pid>/stat
//! and /proc/<pid>/status, its children from /proc/<pid>/task/<tid>/children
//! (or, on a kernel without that file, from every process's parent pid),
//! every pid from /proc's directory, a name from /proc/<pid>/comm (lane tl2;
//! lane mem2 read the same files with a makeshift driver,
//! tmp/plans/mem2/scripts/drv.py).
//!
//! What the figures are:
//! - CPU: utime + stime of /proc/<pid>/stat, in clock ticks (sysconf
//!   CLK_TCK, 100 a second on every Linux Crane runs on: 10 ms steps),
//!   the whole process's threads, as nanoseconds;
//! - footprint: RssAnon + VmSwap of /proc/<pid>/status - the process's own
//!   anonymous pages, resident or swapped out. The nearest Linux has to
//!   macOS's phys_footprint (dirty and compressed anonymous memory): it
//!   leaves out the executable's and the libraries' file pages, which a sum
//!   over a process set would count once per process. On a kernel older
//!   than 4.5, which has no RssAnon, it is VmRSS + VmSwap;
//! - resident: VmRSS (anonymous, file and shmem pages; for reference only,
//!   as on macOS);
//! - instructions: not measured. Counting them for a process set from
//!   outside needs a perf_event_open counter on every thread, opened before
//!   the thread runs or it misses what the thread already did; the journal
//!   leaves the field out, and the report prints no instruction ratio for
//!   such rows;
//! - start: starttime of /proc/<pid>/stat, in clock ticks since boot.
//!
//! The parsers take text, so they are tested on every OS; the readers use
//! Linux system calls directly and are referenced on Linux only.

const std = @import("std");
const builtin = @import("builtin");
const proc = @import("proc.zig");
const Usage = proc.Usage;

const linux = std.os.linux;

/// The fields of /proc/<pid>/stat this tool reads.
pub const Stat = struct {
    state: u8,
    ppid: i32,
    /// Clock ticks in user and in kernel mode, all threads.
    utime: u64,
    stime: u64,
    /// Clock ticks from boot to the process's start.
    starttime: u64,
};

/// One /proc/<pid>/stat line. The process's name, field 2, is in
/// parentheses and may itself hold spaces and parentheses, so the fields
/// after it are counted from the LAST `)` (proc(5)).
pub fn parseStat(text: []const u8) ?Stat {
    const close = std.mem.lastIndexOfScalar(u8, text, ')') orelse return null;
    var it = std.mem.tokenizeAny(u8, text[close + 1 ..], " \n");
    // What follows the name starts at field 3: state.
    var fields: [20][]const u8 = undefined;
    var n: usize = 0;
    while (n < fields.len) : (n += 1) fields[n] = it.next() orelse return null;
    if (fields[0].len != 1) return null;
    return .{
        .state = fields[0][0],
        .ppid = std.fmt.parseInt(i32, fields[1], 10) catch return null,
        // Fields 14 and 15, and 22: at 11, 12 and 19 from the state.
        .utime = std.fmt.parseInt(u64, fields[11], 10) catch return null,
        .stime = std.fmt.parseInt(u64, fields[12], 10) catch return null,
        .starttime = std.fmt.parseInt(u64, fields[19], 10) catch return null,
    };
}

/// The memory lines of /proc/<pid>/status, in bytes; a line the file lacks
/// is null (a kernel thread and a zombie have none of them).
pub const Status = struct {
    vm_rss: ?u64 = null,
    rss_anon: ?u64 = null,
    vm_swap: ?u64 = null,

    /// The process's own anonymous memory, resident or swapped.
    pub fn footprint(s: Status) u64 {
        return (s.rss_anon orelse s.vm_rss orelse 0) + (s.vm_swap orelse 0);
    }
};

/// "VmRSS:\t   51204 kB" -> 51204 * 1024.
pub fn parseStatus(text: []const u8) Status {
    var s: Status = .{};
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const field: *?u64 = if (std.mem.eql(u8, line[0..colon], "VmRSS"))
            &s.vm_rss
        else if (std.mem.eql(u8, line[0..colon], "RssAnon"))
            &s.rss_anon
        else if (std.mem.eql(u8, line[0..colon], "VmSwap"))
            &s.vm_swap
        else
            continue;
        var it = std.mem.tokenizeAny(u8, line[colon + 1 ..], " \t");
        const number = it.next() orelse continue;
        const unit = it.next() orelse continue;
        if (!std.mem.eql(u8, unit, "kB")) continue;
        field.* = (std.fmt.parseInt(u64, number, 10) catch continue) * 1024;
    }
    return s;
}

/// The pids of a /proc/<pid>/task/<tid>/children file ("812 815 "), into
/// `out` after its first `n`, none twice; the new count.
pub fn parseChildren(text: []const u8, out: []i32, n: usize) usize {
    var count = n;
    var it = std.mem.tokenizeAny(u8, text, " \n");
    while (it.next()) |word| {
        const pid = std.fmt.parseInt(i32, word, 10) catch continue;
        if (pid <= 0 or count >= out.len) continue;
        if (std.mem.indexOfScalar(i32, out[0..count], pid) != null) continue;
        out[count] = pid;
        count += 1;
    }
    return count;
}

/// A /proc directory entry's name as a pid ("4711"); null for the others
/// ("self", "meminfo").
pub fn pidOfName(name: []const u8) ?i32 {
    if (name.len == 0) return null;
    for (name) |c| if (!std.ascii.isDigit(c)) return null;
    const pid = std.fmt.parseInt(i32, name, 10) catch return null;
    return if (pid > 0) pid else null;
}

/// Clock ticks as nanoseconds, at `per_second` ticks a second.
pub fn ticksToNs(ticks: u64, per_second: u64) u64 {
    if (per_second == 0) return 0;
    return @intCast(@as(u128, ticks) * std.time.ns_per_s / per_second);
}

/// A time on the clock that counts from boot, as clock ticks.
pub fn bootTicks(sec: u64, nsec: u64, per_second: u64) u64 {
    return sec * per_second + @as(u64, @intCast(@as(u128, nsec) * per_second / std.time.ns_per_s));
}

/// The names in a buffer getdents64 filled (linux_dirent64 records: inode,
/// offset, record length, type, then the name, NUL-terminated), each handed
/// to `each`.
pub fn eachDirName(records: []const u8, context: anytype, comptime each: fn (@TypeOf(context), []const u8) void) void {
    const name_offset = 19;
    var at: usize = 0;
    while (at + name_offset <= records.len) {
        const reclen = std.mem.readInt(u16, records[at + 16 ..][0..2], builtin.cpu.arch.endian());
        if (reclen < name_offset or at + reclen > records.len) return;
        const name = std.mem.sliceTo(records[at + name_offset .. at + reclen], 0);
        each(context, name);
        at += reclen;
    }
}

// ---------------------------------------------------------------------------
// The readers (Linux only).

// sysconf(_SC_CLK_TCK): glibc's and musl's name for it is 2.
extern "c" fn sysconf(name: c_int) c_long;
const sc_clk_tck = 2;

fn ticksPerSecond() u64 {
    const t = sysconf(sc_clk_tck);
    return if (t > 0) @intCast(t) else 100;
}

/// A small /proc file, whole, into `buf`; null when it cannot be opened or
/// read (the process ended).
fn readFile(path: [*:0]const u8, buf: []u8) ?[]u8 {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    if (linux.errno(rc) != .SUCCESS) return null;
    const fd: linux.fd_t = @intCast(rc);
    defer _ = linux.close(fd);
    var n: usize = 0;
    while (n < buf.len) {
        const got = linux.read(fd, buf.ptr + n, buf.len - n);
        switch (linux.errno(got)) {
            .SUCCESS => {},
            .INTR => continue,
            else => return null,
        }
        if (got == 0) break;
        n += got;
    }
    return buf[0..n];
}

/// Every name in a directory, each handed to `each`; false when the
/// directory cannot be opened.
fn eachEntry(path: [*:0]const u8, context: anytype, comptime each: fn (@TypeOf(context), []const u8) void) bool {
    const rc = linux.open(path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true }, 0);
    if (linux.errno(rc) != .SUCCESS) return false;
    const fd: linux.fd_t = @intCast(rc);
    defer _ = linux.close(fd);
    var buf: [8192]u8 align(8) = undefined;
    while (true) {
        const got = linux.getdents64(fd, &buf, buf.len);
        if (linux.errno(got) != .SUCCESS or got == 0) return true;
        eachDirName(buf[0..got], context, each);
    }
}

/// Now, in the clock /proc/<pid>/stat's starttime uses: ticks since boot.
pub fn absoluteNow() u64 {
    var ts: linux.timespec = undefined;
    if (linux.errno(linux.clock_gettime(.BOOTTIME, &ts)) != .SUCCESS) return 0;
    return bootTicks(@intCast(ts.sec), @intCast(ts.nsec), ticksPerSecond());
}

pub fn usageOf(pid: i32) ?Usage {
    var path_buf: [64]u8 = undefined;
    var stat_buf: [1024]u8 = undefined;
    const stat_path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/stat", .{pid}) catch return null;
    const stat = parseStat(readFile(stat_path, &stat_buf) orelse return null) orelse return null;
    // A process that ended between the two reads has its CPU and no memory.
    var status_buf: [4096]u8 = undefined;
    const status_path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/status", .{pid}) catch return null;
    const status: Status = if (readFile(status_path, &status_buf)) |text| parseStatus(text) else .{};
    const per_second = ticksPerSecond();
    return .{
        .pid = pid,
        .cpu_ns = ticksToNs(stat.utime + stat.stime, per_second),
        .instructions = 0,
        .footprint = status.footprint(),
        .resident = status.vm_rss orelse 0,
        .start_abs = stat.starttime,
    };
}

const Pids = struct {
    out: []i32,
    n: usize = 0,

    fn add(self: *Pids, name: []const u8) void {
        const pid = pidOfName(name) orelse return;
        if (self.n >= self.out.len) return;
        self.out[self.n] = pid;
        self.n += 1;
    }
};

/// Every pid, into `out`; how many.
pub fn allPids(out: []i32) usize {
    var pids: Pids = .{ .out = out };
    _ = eachEntry("/proc", &pids, Pids.add);
    return pids.n;
}

const Tasks = struct {
    pid: i32,
    out: []i32,
    n: usize = 0,
    /// Whether any thread's children file could be read.
    read_any: bool = false,

    fn add(self: *Tasks, name: []const u8) void {
        const tid = pidOfName(name) orelse return;
        var path_buf: [96]u8 = undefined;
        var buf: [4096]u8 = undefined;
        const path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/task/{d}/children", .{ self.pid, tid }) catch return;
        const text = readFile(path, &buf) orelse return;
        self.read_any = true;
        self.n = parseChildren(text, self.out, self.n);
    }
};

/// The pids of `pid`'s children, into `out`; how many. A child is the child
/// of the THREAD that made it, so every thread's list is read.
pub fn children(pid: i32, out: []i32) usize {
    var path_buf: [64]u8 = undefined;
    const tasks_path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/task", .{pid}) catch return 0;
    var tasks: Tasks = .{ .pid = pid, .out = out };
    if (!eachEntry(tasks_path, &tasks, Tasks.add)) return 0;
    if (tasks.read_any) return tasks.n;
    // A kernel built without CONFIG_PROC_CHILDREN: every process whose
    // parent is `pid`.
    var all: [4096]i32 = undefined;
    const count = allPids(&all);
    var n: usize = 0;
    for (all[0..count]) |p| {
        if (n >= out.len) break;
        var stat_buf: [1024]u8 = undefined;
        const stat_path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/stat", .{p}) catch continue;
        const stat = parseStat(readFile(stat_path, &stat_buf) orelse continue) orelse continue;
        if (stat.ppid != pid) continue;
        out[n] = p;
        n += 1;
    }
    return n;
}

/// A process's name: /proc/<pid>/comm, its executable's name cut to the
/// kernel's 15 characters.
pub fn nameOf(pid: i32, buf: []u8) error{NoSuchProcess}![]const u8 {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buf, "/proc/{d}/comm", .{pid}) catch return error.NoSuchProcess;
    const text = readFile(path, buf) orelse return error.NoSuchProcess;
    const name = std.mem.trimEnd(u8, text, "\n");
    if (name.len == 0) return error.NoSuchProcess;
    return name;
}

const testing = std.testing;

test "a stat line: the fields are counted from the last parenthesis, whatever the name holds" {
    // A console of the pool, cut after its start time.
    const plain = "4711 (repl) S 4700 4711 4700 0 -1 4194304 52981 0 12 0 1834 219 0 0 20 0 23 0 88123456 1291845632 31402 18446744073709551615 1 1 0 0 0 0 0 4096 17642 0 0 0 17 5 0 0 0 0 0\n";
    const s = parseStat(plain).?;
    try testing.expectEqual(@as(u8, 'S'), s.state);
    try testing.expectEqual(@as(i32, 4700), s.ppid);
    try testing.expectEqual(@as(u64, 1834), s.utime);
    try testing.expectEqual(@as(u64, 219), s.stime);
    try testing.expectEqual(@as(u64, 88123456), s.starttime);
    // A name with spaces and parentheses of its own: the same fields.
    const odd = "4711 (a) b (c) R 1 4711 4700 0 -1 4194304 52981 0 12 0 7 3 0 0 20 0 23 0 5 1291845632 31402\n";
    const o = parseStat(odd).?;
    try testing.expectEqual(@as(u8, 'R'), o.state);
    try testing.expectEqual(@as(i32, 1), o.ppid);
    try testing.expectEqual(@as(u64, 7), o.utime);
    try testing.expectEqual(@as(u64, 3), o.stime);
    try testing.expectEqual(@as(u64, 5), o.starttime);
    // A line cut short, and text that is no stat line.
    try testing.expectEqual(@as(?Stat, null), parseStat("4711 (repl) S 4700 4711"));
    try testing.expectEqual(@as(?Stat, null), parseStat(""));
    try testing.expectEqual(@as(?Stat, null), parseStat("no parenthesis"));
}

test "a status file: resident, anonymous and swapped memory in bytes; the footprint is what the process itself holds" {
    const text = "Name:\trepl\nUmask:\t0022\nState:\tS (sleeping)\nVmPeak:\t 1392384 kB\nVmSize:\t 1261568 kB\n" ++
        "VmHWM:\t  153204 kB\nVmRSS:\t  151404 kB\nRssAnon:\t   98432 kB\nRssFile:\t   52844 kB\nRssShmem:\t     128 kB\n" ++
        "VmData:\t  402112 kB\nVmSwap:\t    2048 kB\nThreads:\t23\n";
    const s = parseStatus(text);
    try testing.expectEqual(@as(?u64, 151404 * 1024), s.vm_rss);
    try testing.expectEqual(@as(?u64, 98432 * 1024), s.rss_anon);
    try testing.expectEqual(@as(?u64, 2048 * 1024), s.vm_swap);
    // Anonymous pages, resident or swapped: not the 52.8 MB of file pages.
    try testing.expectEqual(@as(u64, (98432 + 2048) * 1024), s.footprint());
    // A kernel before 4.5 has no RssAnon: the resident size stands in.
    const old = parseStatus("VmRSS:\t  151404 kB\nVmSwap:\t       0 kB\n");
    try testing.expectEqual(@as(?u64, null), old.rss_anon);
    try testing.expectEqual(@as(u64, 151404 * 1024), old.footprint());
    // A zombie's status has no memory lines at all.
    const zombie = parseStatus("Name:\trepl\nState:\tZ (zombie)\nThreads:\t1\n");
    try testing.expectEqual(@as(u64, 0), zombie.footprint());
    try testing.expectEqual(@as(?u64, null), zombie.vm_rss);
}

test "a children file: the pids, none twice, never past the buffer" {
    var out: [4]i32 = undefined;
    try testing.expectEqual(@as(usize, 2), parseChildren("812 815 \n", &out, 0));
    try testing.expectEqualSlices(i32, &.{ 812, 815 }, out[0..2]);
    // A second thread's list: appended, a pid already there once.
    try testing.expectEqual(@as(usize, 3), parseChildren("815 900", &out, 2));
    try testing.expectEqualSlices(i32, &.{ 812, 815, 900 }, out[0..3]);
    try testing.expectEqual(@as(usize, 4), parseChildren("901 902 903", &out, 3));
    try testing.expectEqual(@as(usize, 0), parseChildren("", &out, 0));
}

test "a /proc entry is a process when its name is a number" {
    try testing.expectEqual(@as(?i32, 4711), pidOfName("4711"));
    try testing.expectEqual(@as(?i32, null), pidOfName("self"));
    try testing.expectEqual(@as(?i32, null), pidOfName("thread-self"));
    try testing.expectEqual(@as(?i32, null), pidOfName(""));
    try testing.expectEqual(@as(?i32, null), pidOfName("0"));
    try testing.expectEqual(@as(?i32, null), pidOfName("99999999999999"));
}

test "clock ticks: nanoseconds of CPU, and the time since boot a start time is compared with" {
    try testing.expectEqual(@as(u64, 20_530_000_000), ticksToNs(2053, 100));
    try testing.expectEqual(@as(u64, 0), ticksToNs(2053, 0));
    // 881,234.56 s after boot is tick 88,123,456 at 100 a second.
    try testing.expectEqual(@as(u64, 88_123_456), bootTicks(881_234, 560_000_000, 100));
    try testing.expectEqual(@as(u64, 88_123_456), bootTicks(881_234, 569_999_999, 100));
}

test "directory records: each name, as getdents64 lays them out" {
    // Two linux_dirent64 records: "4711" (24 bytes) and "self" (24 bytes).
    var buf: [48]u8 = @splat(0);
    const endian = builtin.cpu.arch.endian();
    std.mem.writeInt(u16, buf[16..18], 24, endian);
    @memcpy(buf[19..23], "4711");
    std.mem.writeInt(u16, buf[24 + 16 ..][0..2], 24, endian);
    @memcpy(buf[24 + 19 ..][0..4], "self");
    const Seen = struct {
        names: [4][]const u8 = undefined,
        n: usize = 0,
        fn add(self: *@This(), name: []const u8) void {
            self.names[self.n] = name;
            self.n += 1;
        }
    };
    var seen: Seen = .{};
    eachDirName(&buf, &seen, Seen.add);
    try testing.expectEqual(@as(usize, 2), seen.n);
    try testing.expectEqualStrings("4711", seen.names[0]);
    try testing.expectEqualStrings("self", seen.names[1]);
    // A record that runs past the buffer ends the walk.
    var short: Seen = .{};
    eachDirName(buf[0..40], &short, Seen.add);
    try testing.expectEqual(@as(usize, 1), short.n);
}
