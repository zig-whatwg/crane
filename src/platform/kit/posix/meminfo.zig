//! Linux memory pressure from /proc/meminfo and the process's cgroup: the
//! rule a platform's observer polls
//! (src/platform/adapters/linux/memory_pressure.zig), as pure functions of
//! the files' texts, and the reads.
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
//!
//! Inside a cgroup with a memory limit - a container, a systemd unit or
//! scope with MemoryMax= or MemoryHigh= - the machine's figures say too
//! little: the process is short of memory when its cgroup is, however much
//! the machine has. WebKit's monitor reads the cgroup too (the same file, at
//! 9e896da4cf9f: getCgroupControllerPath, CGroupMemoryController,
//! systemMemoryUsedAsPercentage), and Crane's rule is that reading, in its
//! arithmetic and its order (the user, 2026-11-17; Firefox reads no cgroup -
//! its extra is a floor of 200 MB available, which the user declined):
//!
//!   used %   = the larger of the machine's (above) and the cgroup's
//!   cgroup % = 100 * (usage / limit), computed in 32-bit floats and cut to
//!              a whole number
//!   limit    = memory.memsw.max, else the smaller of memory.max and
//!              memory.high (either alone when the other is not set), else
//!              cgroup v1's memory.memsw.limit_in_bytes, else its
//!              memory.limit_in_bytes
//!   usage    = memory.current, else cgroup v1's
//!              memory.memsw.usage_in_bytes, else its memory.usage_in_bytes
//!
//! A file is not set when it is missing or its first line is not a whole
//! number of bytes: cgroup v2 writes "max" for no limit. With no limit or
//! no usage the machine's figures decide alone. The cgroup is the one
//! /proc/self/cgroup names (`cgroupPath`); its cgroup v2 files are under
//! /sys/fs/cgroup/<path>/, its cgroup v1 files under
//! /sys/fs/cgroup/memory/<path>/, and all eight are asked for whichever the
//! machine runs. memory.current counts the page cache charged to the
//! cgroup, which the kernel gives back under pressure: a cgroup that reads
//! and writes files stands near its limit by design, and reads as short of
//! memory here as it does to WebKit.
//!
//! Three places where this is not WebKit's result, none on a figure a
//! kernel writes:
//! - MemAvailable over MemTotal is 0 % used here; WebKit takes no reading.
//! - A limit of 0 bytes gives no cgroup percentage here; WebKit divides by
//!   it and converts the result to an integer, which C leaves undefined.
//! - A percentage past what an integer holds is cut off here; undefined
//!   there.

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
        return levelOfUsedPercent(self.usedPercent());
    }
};

/// The level at `used` percent of memory used.
pub fn levelOfUsedPercent(used: u32) platform.MemoryPressureLevel {
    if (used >= critical_used_percent) return .critical;
    if (used >= warning_used_percent) return .warning;
    return .normal;
}

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

// ---------------------------------------------------------------------------
// The cgroup
// ---------------------------------------------------------------------------

/// The texts of a cgroup's memory files, each null when the file is not
/// there: the eight WebKit's CGroupMemoryController opens.
pub const CgroupFiles = struct {
    // cgroup v2: /sys/fs/cgroup/<path>/
    /// "memory.memsw.max": the first limit WebKit asks for. No kernel's
    /// cgroup v2 writes a file of this name (its swap limit is
    /// memory.swap.max); the order is kept whole.
    memory_memsw_max: ?[]const u8 = null,
    /// "memory.max": the hard limit (systemd's MemoryMax=), or "max".
    memory_max: ?[]const u8 = null,
    /// "memory.high": the throttle limit (MemoryHigh=), or "max".
    memory_high: ?[]const u8 = null,
    /// "memory.current": what the cgroup and its descendants use.
    memory_current: ?[]const u8 = null,
    // cgroup v1: /sys/fs/cgroup/memory/<path>/
    /// "memory.memsw.limit_in_bytes": the memory + swap limit.
    memory_memsw_limit_in_bytes: ?[]const u8 = null,
    /// "memory.limit_in_bytes".
    memory_limit_in_bytes: ?[]const u8 = null,
    /// "memory.memsw.usage_in_bytes": memory + swap in use.
    memory_memsw_usage_in_bytes: ?[]const u8 = null,
    /// "memory.usage_in_bytes".
    memory_usage_in_bytes: ?[]const u8 = null,
};

/// The most bytes of a cgroup file's first line that are read: WebKit's
/// buffer (VALUE_BUFFER_SIZE).
pub const cgroup_value_bytes = 128;

/// A cgroup file's value: its first line as a whole number of bytes, or
/// null - not set - for a missing file, an empty first line, and a line
/// that is anything but a number that fits a signed 64-bit word and is not
/// negative ("max").
///
/// WebKit's CGroupMemoryController::getCgroupFileValue: the line is read
/// with `%[^\n]` (so it must have a byte) and converted with strtol, whose
/// leading white space and sign are accepted, and nothing may follow the
/// digits.
pub fn cgroupValue(text: ?[]const u8) ?u64 {
    const whole = text orelse return null;
    var line = whole[0 .. std.mem.findScalar(u8, whole, '\n') orelse whole.len];
    if (line.len == 0) return null;
    if (line.len > cgroup_value_bytes) line = line[0..cgroup_value_bytes];
    // strtol's white space: isspace in the C locale.
    var at: usize = 0;
    while (at < line.len and (line[at] == ' ' or (line[at] >= '\t' and line[at] <= '\r'))) at += 1;
    var negative = false;
    if (at < line.len and (line[at] == '+' or line[at] == '-')) {
        negative = line[at] == '-';
        at += 1;
    }
    if (at == line.len) return null;
    var value: u64 = 0;
    for (line[at..]) |byte| {
        if (!std.ascii.isDigit(byte)) return null;
        value = std.math.mul(u64, value, 10) catch return null;
        value = std.math.add(u64, value, byte - '0') catch return null;
    }
    // "-0" is 0; any other negative number is not a value. LONG_MAX is the
    // largest (strtol's ERANGE past it).
    if (negative) return if (value == 0) 0 else null;
    if (value > std.math.maxInt(i64)) return null;
    return value;
}

/// A cgroup's limit and usage, in bytes.
pub const CgroupReading = struct {
    limit_bytes: u64,
    usage_bytes: u64,

    /// The cgroup's memory used, in percent of its limit, or null for a
    /// limit of 0 bytes. WebKit's arithmetic (systemMemoryUsedAsPercentage:
    /// `100 * ((float) memoryUsage / (float) memoryTotal)` converted to
    /// int): both figures become 32-bit floats, rounded to the nearest; the
    /// quotient and its hundredfold are 32-bit floats; the fraction is cut
    /// off. So 899,999,999 bytes of 1,000,000,000 is 90 %, not 89. A cgroup
    /// may stand over its memory.high, so the figure may pass 100.
    pub fn usedPercent(self: CgroupReading) ?u32 {
        if (self.limit_bytes == 0) return null;
        const usage: f32 = @floatFromInt(self.usage_bytes);
        const limit: f32 = @floatFromInt(self.limit_bytes);
        const percent: f32 = 100 * (usage / limit);
        // Never negative and never NaN: the usage is not negative and the
        // limit is over 0.
        const most: f32 = 1_000_000;
        if (percent >= most) return 1_000_000;
        return @intFromFloat(percent);
    }
};

/// The cgroup's limit: WebKit's
/// CGroupMemoryController::getMemoryTotalWithCgroup, in its order.
pub fn cgroupLimit(files: CgroupFiles) ?u64 {
    // cgroup v2.
    if (cgroupValue(files.memory_memsw_max)) |value| return value;
    const max = cgroupValue(files.memory_max);
    const high = cgroupValue(files.memory_high);
    if (max != null and high != null) return @min(max.?, high.?);
    if (high) |value| return value;
    if (max) |value| return value;
    // cgroup v1: memory + swap, else memory.
    if (cgroupValue(files.memory_memsw_limit_in_bytes)) |value| return value;
    return cgroupValue(files.memory_limit_in_bytes);
}

/// The cgroup's usage: WebKit's
/// CGroupMemoryController::getMemoryUsageWithCgroup, in its order.
pub fn cgroupUsage(files: CgroupFiles) ?u64 {
    if (cgroupValue(files.memory_current)) |value| return value;
    if (cgroupValue(files.memory_memsw_usage_in_bytes)) |value| return value;
    return cgroupValue(files.memory_usage_in_bytes);
}

/// The limit and the usage `files` give, or null when either is not set.
pub fn parseCgroup(files: CgroupFiles) ?CgroupReading {
    const limit = cgroupLimit(files) orelse return null;
    const usage = cgroupUsage(files) orelse return null;
    return .{ .limit_bytes = limit, .usage_bytes = usage };
}

/// The memory used, in percent: the larger of the machine's and the
/// cgroup's, the machine's alone when the cgroup has no limit or no usage
/// (WebKit's systemMemoryUsedAsPercentage).
pub fn usedPercentWithCgroup(machine: Reading, files: CgroupFiles) u32 {
    const used: u32 = machine.usedPercent();
    const cgroup = parseCgroup(files) orelse return used;
    return @max(used, cgroup.usedPercent() orelse return used);
}

/// The level a /proc/meminfo's `text` and a cgroup's `files` are at, or
/// null when the meminfo does not say: without the machine's figures
/// WebKit's reading fails before it looks at the cgroup.
pub fn levelWithCgroup(text: []const u8, files: CgroupFiles) ?platform.MemoryPressureLevel {
    const machine = parse(text) orelse return null;
    return levelOfUsedPercent(usedPercentWithCgroup(machine, files));
}

/// The most bytes of a controller list WebKit's scan reads
/// (CGROUP_NAME_BUFFER_SIZE).
const cgroup_name_bytes = 40;
/// The most bytes of a cgroup's path it reads (PATH_MAX).
pub const cgroup_path_bytes = 4096;

/// The path of the cgroup whose memory files are read, from the text of
/// /proc/self/cgroup: a slice of `text`, or null when no entry names one.
///
/// The file has a line per hierarchy, `hierarchy-ID:controller-list:path`;
/// cgroup v2's is hierarchy 0 with an empty list (`0::/a/b`). The path is
/// that of the FIRST entry whose list is exactly "memory" (cgroup v1's
/// memory controller) or "name=systemd" (systemd's own v1 hierarchy), or
/// that is cgroup v2's.
///
/// WebKit's getCgroupControllerPath, whose scan is fscanf's and is kept
/// byte for byte where the text is not in the kernel's form: white space is
/// skipped before the number only; a list runs to the next colon, a line's
/// end included, and has from 1 to 40 bytes; a path runs to the line's end
/// and has from 1 to 4096 bytes; the first entry that does not scan ends
/// the search with no path. (fscanf's `%u` also takes a sign; a kernel
/// writes none, and none is taken here.)
pub fn cgroupPath(text: []const u8) ?[]const u8 {
    var at: usize = 0;
    while (true) {
        // `%u:` - the number; the colon after it is taken when it is there.
        while (at < text.len and (text[at] == ' ' or (text[at] >= '\t' and text[at] <= '\r'))) at += 1;
        const number_start = at;
        var hierarchy_is_zero = true;
        while (at < text.len and std.ascii.isDigit(text[at])) : (at += 1) {
            if (text[at] != '0') hierarchy_is_zero = false;
        }
        if (at == number_start) return null;
        if (at < text.len and text[at] == ':') at += 1;

        var name: []const u8 = "";
        if (!hierarchy_is_zero) {
            // `%40[^:]` - the controller list.
            const name_start = at;
            while (at < text.len and text[at] != ':' and at - name_start < cgroup_name_bytes) at += 1;
            if (at == name_start) return null;
            name = text[name_start..at];
        }
        // `:` - a list of more than 40 bytes fails here.
        if (at == text.len or text[at] != ':') return null;
        at += 1;
        // `%4096[^\n]` - the path.
        const path_start = at;
        while (at < text.len and text[at] != '\n' and at - path_start < cgroup_path_bytes) at += 1;
        if (at == path_start) return null;
        const path = text[path_start..at];

        if (std.mem.eql(u8, name, "memory") or std.mem.eql(u8, name, "name=systemd") or name.len == 0) return path;
    }
}

// ---------------------------------------------------------------------------
// The reads
// ---------------------------------------------------------------------------

/// The start of the file at `path`, read into `buffer`: null when it does
/// not open or a read fails. Plain libc calls, as src/platform/memory.zig
/// reads /proc/self/statm: a procfs or cgroupfs read has no failure worth
/// more than "no answer", and the observer's thread reads with no
/// allocation.
fn readStart(path: [*:0]const u8, buffer: []u8) ?[]const u8 {
    const fd = std.c.open(path, .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    var length: usize = 0;
    while (length < buffer.len) {
        const count = std.c.read(fd, buffer[length..].ptr, buffer.len - length);
        if (count < 0) return null;
        if (count == 0) break;
        length += @intCast(count);
    }
    return buffer[0..length];
}

/// This machine's reading now; null where there is no /proc/meminfo (any OS
/// but Linux) or it does not say. Both figures are in the file's first
/// lines; 2 KiB holds them on every kernel that writes MemAvailable (it is
/// the third line).
pub fn read() ?Reading {
    if (comptime builtin.os.tag != .linux) return null;
    var buffer: [2048]u8 = undefined;
    return parse(readStart("/proc/meminfo", &buffer) orelse return null);
}

/// One of a cgroup's files: `directory` (WebKit's "/sys/fs/cgroup/" and its
/// controller name), the cgroup's `path`, `name`. Null when the file is not
/// there, or the whole name is longer than any path the kernel opens.
fn readCgroupFile(comptime directory: []const u8, path: []const u8, comptime name: []const u8, buffer: *[cgroup_value_bytes]u8) ?[]const u8 {
    var file: [directory.len + cgroup_path_bytes + 1 + name.len + 1]u8 = undefined;
    const whole = std.mem.printSentinel(&file, "{s}{s}/{s}", .{ directory, path, name }, 0) catch return null;
    return readStart(whole.ptr, buffer);
}

/// The level this process is at now - its machine's /proc/meminfo and its
/// own cgroup's memory files, read afresh - or null where there is no
/// /proc/meminfo (any OS but Linux) or it does not say. What the linux
/// platform's observer polls.
///
/// WebKit keeps the files open between polls and opens a cgroup's again
/// when /proc/self/cgroup names another path; opening them at each poll
/// reads the same bytes, and a poll is every 5 s, every 1 s under pressure.
pub fn readLevel() ?platform.MemoryPressureLevel {
    if (comptime builtin.os.tag != .linux) return null;
    const machine = read() orelse return null;
    var files: CgroupFiles = .{};
    // One entry is at most a number, 40 bytes of list and 4096 of path, and
    // a cgroup v1 machine has about a dozen entries with short paths.
    var entries: [16 * 1024]u8 = undefined;
    var values: [8][cgroup_value_bytes]u8 = undefined;
    if (readStart("/proc/self/cgroup", &entries)) |all| {
        // A text that fills the buffer may end inside an entry: keep the
        // whole lines.
        const text = if (all.len < entries.len) all else all[0..(std.mem.findScalarLast(u8, all, '\n') orelse 0)];
        if (cgroupPath(text)) |path| {
            // cgroup v2's files: WebKit's controller name for them is "/".
            const v2 = "/sys/fs/cgroup///";
            // cgroup v1's, under the memory controller's mount.
            const v1 = "/sys/fs/cgroup/memory/";
            files = .{
                .memory_memsw_max = readCgroupFile(v2, path, "memory.memsw.max", &values[0]),
                .memory_max = readCgroupFile(v2, path, "memory.max", &values[1]),
                .memory_high = readCgroupFile(v2, path, "memory.high", &values[2]),
                .memory_current = readCgroupFile(v2, path, "memory.current", &values[3]),
                .memory_memsw_limit_in_bytes = readCgroupFile(v1, path, "memory.memsw.limit_in_bytes", &values[4]),
                .memory_limit_in_bytes = readCgroupFile(v1, path, "memory.limit_in_bytes", &values[5]),
                .memory_memsw_usage_in_bytes = readCgroupFile(v1, path, "memory.memsw.usage_in_bytes", &values[6]),
                .memory_usage_in_bytes = readCgroupFile(v1, path, "memory.usage_in_bytes", &values[7]),
            };
        }
    }
    return levelOfUsedPercent(usedPercentWithCgroup(machine, files));
}
