//! Lane mp2: the Linux memory-pressure rule inside a cgroup with a memory
//! limit - a container, a systemd unit or scope with MemoryMax= or
//! MemoryHigh=.
//!
//! /proc/meminfo describes the machine. A process whose cgroup is limited to
//! a part of it is short of memory long before the machine is, so the level
//! is judged against the cgroup's limit and usage too: WebKit's reading
//! (Source/WebKit/UIProcess/linux/MemoryPressureMonitor.cpp at 9e896da4cf9f,
//! BSD-2, Igalia: systemMemoryUsedAsPercentage, CGroupMemoryController,
//! getCgroupControllerPath), reproduced in src/platform/kit/posix/meminfo.zig
//! and tested here through the testing platform's controls
//! `platform.adapter.memoryPressureLevelOfMeminfoAndCgroup` and
//! `platform.adapter.memoryPressureCgroupPath`. Firefox reads no cgroup (its
//! extra is a 200 MB floor, which the user declined on 2026-11-17) and
//! Chromium has no monitor on desktop Linux.
//!
//!   used % = the larger of the machine's (meminfo) and the cgroup's
//!   cgroup % = 100 * (usage / limit) in 32-bit floats, cut to a whole number
//!   limit  = memory.memsw.max, else the smaller of memory.max and
//!            memory.high (either alone when the other is not a number),
//!            else cgroup v1's memory.memsw.limit_in_bytes, else its
//!            memory.limit_in_bytes
//!   usage  = memory.current, else cgroup v1's memory.memsw.usage_in_bytes,
//!            else its memory.usage_in_bytes
//!
//! A file that is missing, or whose first line is not a whole number of
//! bytes ("max"), is not set. With no limit or no usage the machine's
//! figures decide alone, as before.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");

const Level = platform.MemoryPressureLevel;

const mib: u64 = 1024 * 1024;
const gib: u64 = 1024 * mib;

/// A machine with memory to spare (server1's figures, about 61 % available):
/// the normal level by itself.
const roomy_meminfo =
    \\MemTotal:       65804256 kB
    \\MemFree:         1903284 kB
    \\MemAvailable:   40221168 kB
    \\Buffers:          911292 kB
    \\Cached:         36654120 kB
    \\
;
/// A machine at 92 % used: the warning by itself.
const warning_meminfo = "MemTotal: 1000000 kB\nMemAvailable: 80000 kB\n";
/// A machine at 97 % used: critical by itself.
const critical_meminfo = "MemTotal: 1000000 kB\nMemAvailable: 30000 kB\n";

/// A cgroup file's text: the number and the newline the kernel writes.
fn bytes(buffer: []u8, value: u64) []const u8 {
    return std.fmt.bufPrint(buffer, "{d}\n", .{value}) catch unreachable;
}

/// The level of a roomy machine inside a cgroup v2 with these files.
fn levelV2(max: ?[]const u8, high: ?[]const u8, current: ?[]const u8) ?Level {
    return platform.adapter.memoryPressureLevelOfMeminfoAndCgroup(roomy_meminfo, .{
        .memory_max = max,
        .memory_high = high,
        .memory_current = current,
    });
}

test "cgroup v2: the level is judged against memory.max when the cgroup has a limit" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    // A container limited to 1 GiB (MemoryMax=1G; memory.high stays "max")
    // on a machine with 38 GiB to spare.
    const max = bytes(&a, gib);
    try testing.expectEqual(Level.normal, levelV2(max, "max\n", bytes(&b, 512 * mib)).?);
    try testing.expectEqual(Level.normal, levelV2(max, "max\n", bytes(&b, 900 * mib)).?);
    try testing.expectEqual(Level.warning, levelV2(max, "max\n", bytes(&b, 930 * mib)).?);
    try testing.expectEqual(Level.warning, levelV2(max, "max\n", bytes(&b, 960 * mib)).?);
    try testing.expectEqual(Level.critical, levelV2(max, "max\n", bytes(&b, 980 * mib)).?);
    try testing.expectEqual(Level.critical, levelV2(max, "max\n", bytes(&b, gib)).?);
    // An empty cgroup.
    try testing.expectEqual(Level.normal, levelV2(max, "max\n", "0\n").?);
}

test "cgroup v2: \"max\" in both limits is no limit - the machine's figures decide" {
    var b: [32]u8 = undefined;
    // What every cgroup with no limit reads: a session scope, a user slice.
    try testing.expectEqual(Level.normal, levelV2("max\n", "max\n", bytes(&b, 60 * gib)).?);
    try testing.expectEqual(
        Level.warning,
        platform.adapter.memoryPressureLevelOfMeminfoAndCgroup(warning_meminfo, .{
            .memory_max = "max\n",
            .memory_high = "max\n",
            .memory_current = "4096\n",
        }).?,
    );
    try testing.expectEqual(
        Level.critical,
        platform.adapter.memoryPressureLevelOfMeminfoAndCgroup(critical_meminfo, .{
            .memory_max = "max\n",
            .memory_high = "max\n",
            .memory_current = "4096\n",
        }).?,
    );
}

test "cgroup v2: the limit is the smaller of memory.max and memory.high, or the one that is set" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    var c: [32]u8 = undefined;
    // MemoryHigh=1G under MemoryMax=2G: 980 MiB is 95 % of the 1 GiB.
    try testing.expectEqual(Level.critical, levelV2(bytes(&a, 2 * gib), bytes(&b, gib), bytes(&c, 980 * mib)).?);
    // The other way round: memory.max the smaller.
    try testing.expectEqual(Level.critical, levelV2(bytes(&a, gib), bytes(&b, 2 * gib), bytes(&c, 980 * mib)).?);
    try testing.expectEqual(Level.normal, levelV2(bytes(&a, 2 * gib), bytes(&b, 4 * gib), bytes(&c, 980 * mib)).?);
    // memory.high alone (MemoryHigh=1G, no MemoryMax).
    try testing.expectEqual(Level.warning, levelV2("max\n", bytes(&b, gib), bytes(&c, 930 * mib)).?);
    try testing.expectEqual(Level.warning, levelV2(null, bytes(&b, gib), bytes(&c, 930 * mib)).?);
    // memory.max alone, with no memory.high file at all.
    try testing.expectEqual(Level.warning, levelV2(bytes(&a, gib), null, bytes(&c, 930 * mib)).?);
    // memory.high is a throttle, not a wall: a cgroup may stand over it, and
    // over 100 % is critical.
    try testing.expectEqual(Level.critical, levelV2("max\n", bytes(&b, gib), bytes(&c, 3 * gib)).?);
}

test "cgroup: the level is the higher of the machine's and the cgroup's" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    const levelOf = platform.adapter.memoryPressureLevelOfMeminfoAndCgroup;
    // A machine short of memory around a cgroup with room: the machine's.
    try testing.expectEqual(Level.critical, levelOf(critical_meminfo, .{
        .memory_max = bytes(&a, gib),
        .memory_high = "max\n",
        .memory_current = bytes(&b, 100 * mib),
    }).?);
    try testing.expectEqual(Level.warning, levelOf(warning_meminfo, .{
        .memory_max = bytes(&a, gib),
        .memory_high = "max\n",
        .memory_current = bytes(&b, 100 * mib),
    }).?);
    // A machine at the warning around a cgroup at its limit: the cgroup's.
    try testing.expectEqual(Level.critical, levelOf(warning_meminfo, .{
        .memory_max = bytes(&a, gib),
        .memory_high = "max\n",
        .memory_current = bytes(&b, 1000 * mib),
    }).?);
}

test "cgroup: with files missing the machine's figures decide" {
    var a: [32]u8 = undefined;
    const levelOf = platform.adapter.memoryPressureLevelOfMeminfoAndCgroup;
    // No cgroup file at all: the root cgroup, a kernel with no memory
    // controller, a path that is not under /sys/fs/cgroup.
    try testing.expectEqual(Level.normal, levelOf(roomy_meminfo, .{}).?);
    try testing.expectEqual(Level.warning, levelOf(warning_meminfo, .{}).?);
    try testing.expectEqual(Level.critical, levelOf(critical_meminfo, .{}).?);
    // A limit with no usage file, and a usage with no limit: no cgroup
    // percentage.
    try testing.expectEqual(Level.normal, levelV2("1024\n", "max\n", null).?);
    try testing.expectEqual(Level.normal, levelV2(null, null, bytes(&a, 60 * gib)).?);
    // A limit of nothing is no reading: there is no percentage of 0 bytes.
    try testing.expectEqual(Level.normal, levelV2("0\n", "max\n", "4096\n").?);
    try testing.expectEqual(Level.normal, levelV2("0\n", "0\n", "0\n").?);
}

test "cgroup: no level without the machine's figures, whatever the cgroup says" {
    // WebKit's reading fails before it looks at the cgroup when
    // /proc/meminfo does not give both figures.
    const levelOf = platform.adapter.memoryPressureLevelOfMeminfoAndCgroup;
    try testing.expect(levelOf("", .{ .memory_max = "1000\n", .memory_current = "990\n" }) == null);
    try testing.expect(levelOf("MemTotal: 1000 kB\n", .{ .memory_max = "1000\n", .memory_current = "990\n" }) == null);
}

test "cgroup v1: the limit and usage files of the memory controller" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    var c: [32]u8 = undefined;
    var d: [32]u8 = undefined;
    const levelOf = platform.adapter.memoryPressureLevelOfMeminfoAndCgroup;
    // docker run -m 1g on a cgroup v1 host.
    try testing.expectEqual(Level.critical, levelOf(roomy_meminfo, .{
        .memory_limit_in_bytes = bytes(&a, gib),
        .memory_usage_in_bytes = bytes(&b, 980 * mib),
    }).?);
    try testing.expectEqual(Level.normal, levelOf(roomy_meminfo, .{
        .memory_limit_in_bytes = bytes(&a, gib),
        .memory_usage_in_bytes = bytes(&b, 500 * mib),
    }).?);
    // With swap accounting, the memory+swap pair is read before the plain
    // pair: 1.9 of 2 GiB is the warning though 980 MiB of 1 GiB would be
    // critical.
    try testing.expectEqual(Level.warning, levelOf(roomy_meminfo, .{
        .memory_memsw_limit_in_bytes = bytes(&a, 2 * gib),
        .memory_memsw_usage_in_bytes = bytes(&b, 1900 * mib),
        .memory_limit_in_bytes = bytes(&c, gib),
        .memory_usage_in_bytes = bytes(&d, 980 * mib),
    }).?);
    // cgroup v1 writes no "max": a cgroup with no limit reads the largest
    // page-rounded number, and any usage is 0 % of it.
    try testing.expectEqual(Level.normal, levelOf(roomy_meminfo, .{
        .memory_memsw_limit_in_bytes = "9223372036854771712\n",
        .memory_memsw_usage_in_bytes = bytes(&b, 60 * gib),
        .memory_limit_in_bytes = "9223372036854771712\n",
        .memory_usage_in_bytes = bytes(&d, 60 * gib),
    }).?);
}

test "cgroup: the order the files are read in - memory.memsw.max, cgroup v2, then cgroup v1" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    var c: [32]u8 = undefined;
    const levelOf = platform.adapter.memoryPressureLevelOfMeminfoAndCgroup;
    // memory.memsw.max is the first limit WebKit asks for (no kernel's
    // cgroup v2 writes a file of that name; the order is kept whole).
    try testing.expectEqual(Level.normal, levelOf(roomy_meminfo, .{
        .memory_memsw_max = bytes(&a, 4 * gib),
        .memory_max = bytes(&b, gib),
        .memory_high = bytes(&b, gib),
        .memory_current = bytes(&c, 980 * mib),
    }).?);
    // cgroup v2's limit and usage are read before cgroup v1's.
    try testing.expectEqual(Level.critical, levelOf(roomy_meminfo, .{
        .memory_max = bytes(&a, gib),
        .memory_current = bytes(&b, 980 * mib),
        .memory_limit_in_bytes = bytes(&c, 4 * gib),
        .memory_usage_in_bytes = "4096\n",
    }).?);
    // Each of the two is found by itself: a v2 limit with a v1 usage.
    try testing.expectEqual(Level.critical, levelOf(roomy_meminfo, .{
        .memory_max = bytes(&a, gib),
        .memory_usage_in_bytes = bytes(&b, 980 * mib),
    }).?);
    // A v2 limit that is "max" falls through to cgroup v1's.
    try testing.expectEqual(Level.critical, levelOf(roomy_meminfo, .{
        .memory_max = "max\n",
        .memory_high = "max\n",
        .memory_limit_in_bytes = bytes(&a, gib),
        .memory_usage_in_bytes = bytes(&b, 980 * mib),
    }).?);
}

test "cgroup: a file's value is its first line, a whole number of bytes and nothing else" {
    // 980 of 1000 bytes: critical when the limit is read, normal when not.
    const current = "980\n";
    try testing.expectEqual(Level.critical, levelV2("1000\n", null, current).?);
    // No last newline; leading blanks and a plus sign (strtol's).
    try testing.expectEqual(Level.critical, levelV2("1000", null, current).?);
    try testing.expectEqual(Level.critical, levelV2("  1000\n", null, current).?);
    try testing.expectEqual(Level.critical, levelV2("\t+1000\n", null, current).?);
    // Only the first line.
    try testing.expectEqual(Level.critical, levelV2("1000\n999999\n", null, current).?);
    // Not a value: no first line, a word, a number with anything after it,
    // a negative one, one too large for a signed 64-bit word, digits with
    // separators.
    for ([_][]const u8{
        "",        "\n",                    "\n1000\n",               "max\n",
        "1000 \n", "1000 kB\n",             "1000.5\n",               "0x3e8\n",
        "-1000\n", "9223372036854775808\n", "99999999999999999999\n", "1_000\n",
        " \n",     "+\n",                   "-\n",
    }) |text| {
        try testing.expectEqual(Level.normal, levelV2(text, null, current).?);
    }
    // The largest value there is.
    try testing.expectEqual(Level.normal, levelV2("9223372036854775807\n", null, current).?);
    // The usage file is read the same way.
    try testing.expectEqual(Level.normal, levelV2("1000\n", null, "max\n").?);
    try testing.expectEqual(Level.normal, levelV2("1000\n", null, "980 \n").?);
    try testing.expectEqual(Level.critical, levelV2("1000\n", null, " 980").?);
}

test "cgroup: the percentage is WebKit's, in 32-bit floats" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    // 899,999,999 of 1,000,000,000 bytes is 89.9999999 %: whole-number
    // arithmetic says 89, the normal level. As 32-bit floats the usage is
    // 900,000,000 (the nearest one), the quotient 0.9 and its hundredfold
    // exactly 90: the warning. Likewise 949,999,999 is critical.
    const limit = bytes(&a, 1_000_000_000);
    try testing.expectEqual(Level.warning, levelV2(limit, null, bytes(&b, 899_999_999)).?);
    try testing.expectEqual(Level.warning, levelV2(limit, null, bytes(&b, 900_000_000)).?);
    try testing.expectEqual(Level.critical, levelV2(limit, null, bytes(&b, 949_999_999)).?);
    try testing.expectEqual(Level.normal, levelV2(limit, null, bytes(&b, 899_999_900)).?);
    // 1 GiB: 966,367,641 bytes is under 90 % by half a byte.
    try testing.expectEqual(Level.warning, levelV2(bytes(&a, gib), null, bytes(&b, 966_367_641)).?);
    // No pair of values overflows: the largest usage of the smallest limit.
    try testing.expectEqual(Level.critical, levelV2("1\n", null, "9223372036854775807\n").?);
    try testing.expectEqual(Level.normal, levelV2("9223372036854775807\n", null, "1\n").?);
}

test "cgroup path: the first memory, name=systemd or cgroup v2 line of /proc/self/cgroup" {
    const pathOf = platform.adapter.memoryPressureCgroupPath;
    // cgroup v2 alone (every current distribution): one line, hierarchy 0,
    // no controller list.
    try testing.expectEqualStrings(
        "/user.slice/user-1000.slice/user@1000.service/app.slice/run-r1f0c.scope",
        pathOf("0::/user.slice/user-1000.slice/user@1000.service/app.slice/run-r1f0c.scope\n").?,
    );
    // The root cgroup, and a container's own root in its cgroup namespace.
    try testing.expectEqualStrings("/", pathOf("0::/\n").?);
    // cgroup v1: the memory controller's line, wherever it is.
    const v1 =
        \\12:hugetlb:/
        \\11:rdma:/
        \\10:net_cls,net_prio:/
        \\9:devices:/user.slice
        \\8:memory:/user.slice/user-1000.slice
        \\7:freezer:/user/someone/0
        \\6:pids:/user.slice/user-1000.slice/user@1000.service
        \\5:blkio:/user.slice
        \\4:perf_event:/
        \\3:cpu,cpuacct:/user.slice
        \\2:cpuset:/
        \\1:name=systemd:/user.slice/user-1000.slice/user@1000.service/term.service
        \\0::/user.slice/user-1000.slice/user@1000.service/term.service
        \\
    ;
    try testing.expectEqualStrings("/user.slice/user-1000.slice", pathOf(v1).?);
    // A docker container on a cgroup v1 host.
    try testing.expectEqualStrings(
        "/docker/4f6a1c0e9b7d",
        pathOf("3:cpu,cpuacct:/docker/4f6a1c0e9b7d\n2:memory:/docker/4f6a1c0e9b7d\n1:name=systemd:/docker/4f6a1c0e9b7d\n").?,
    );
    // No memory line: systemd's own hierarchy, then the v2 line - whichever
    // comes first.
    try testing.expectEqualStrings(
        "/a.service",
        pathOf("3:cpu,cpuacct:/x\n1:name=systemd:/a.service\n0::/b.service\n").?,
    );
    try testing.expectEqualStrings(
        "/b.service",
        pathOf("3:cpu,cpuacct:/x\n0::/b.service\n1:name=systemd:/a.service\n").?,
    );
    // A list that only holds "memory" beside another controller is not the
    // name "memory".
    try testing.expectEqualStrings(
        "/s.service",
        pathOf("4:cpu,memory:/m\n3:memory,pids:/n\n1:name=systemd:/s.service\n").?,
    );
    // No last newline; a path with a colon and blanks in it.
    try testing.expectEqualStrings("/a b:c", pathOf("0::/a b:c").?);
}

test "cgroup path: none when no line names one, or a line is not in the kernel's form" {
    const pathOf = platform.adapter.memoryPressureCgroupPath;
    try testing.expect(pathOf("") == null);
    try testing.expect(pathOf("\n") == null);
    // Only other controllers.
    try testing.expect(pathOf("3:cpu,cpuacct:/x\n2:cpuset:/\n") == null);
    // Text that is not `number:controllers:path` ends the search where
    // WebKit's scan (fscanf) fails on it - even before a line that would
    // match.
    try testing.expect(pathOf("garbage\n0::/x\n") == null);
    // That scan reads a controller list up to the next colon, not to the
    // line's end: a line with no list takes the next line's number for one,
    // and that line's match with it.
    try testing.expect(pathOf("3\n0::/x\n") == null);
    try testing.expect(pathOf("3:cpu\n0::/x\n") == null);
    try testing.expect(pathOf("3:cpu\n8:memory:/m\n") == null);
    try testing.expectEqualStrings("/y", pathOf("3:cpu\n8:x\n0::/y\n").?);
    // Hierarchy 0 has no controller list; another hierarchy has one.
    try testing.expect(pathOf("0:memory:/x\n") == null);
    try testing.expect(pathOf("5::/x\n0::/y\n") == null);
    // No path.
    try testing.expect(pathOf("0::\n") == null);
    try testing.expect(pathOf("8:memory:\n0::/y\n") == null);
    // WebKit reads a controller list of at most 40 bytes; a longer one ends
    // the search. 40 bytes are read.
    try testing.expect(pathOf("2:name=a-hierarchy-with-a-very-long-name-of-its-own:/x\n0::/y\n") == null);
    try testing.expectEqualStrings("/y", pathOf("2:name=a-hierarchy-whose-name-is-40-bytes!:/x\n0::/y\n").?);
}
