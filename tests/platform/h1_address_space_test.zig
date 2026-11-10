//! The platform's address space (docs/platform-protocol.md 6.11): what a
//! Browser's heap is made of (runtime.BrowserScope.Heap; lane h1, phase H1 of
//! tmp/redesign/node-memory-architecture.md as amended by
//! node-memory-plan-v2.md). Each red test comes from an OS behaviour the deep
//! review MEASURED on the pool (tmp/redesign/review/oss/appendix-probes.md):
//! P1 (macOS footprint under MADV_FREE_REUSABLE without MADV_FREE_REUSE), P3
//! (Linux transparent huge pages on a sparse super-page pool) and P4 (a
//! released reservation's address handed to the next one).
//!
//! The directory's executable binds the testing platform, whose address space
//! is the build machine's - darwin's path on macOS, linux's on Linux - so
//! each OS's behaviour runs on its own hosts.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");

const testing = std.testing;

const MiB: usize = 1024 * 1024;
const GiB: usize = 1024 * MiB;

const is_darwin = builtin.os.tag.isDarwin();
const is_linux = builtin.os.tag == .linux;

fn supported() !void {
    if (comptime platform.capabilities.address_space == .unsupported) return error.SkipZigTest;
}

/// The exit status of a forked child whose read faulted.
const fault_exit = 42;

fn onFault(_: std.posix.SIG) callconv(.c) void {
    std.c._exit(fault_exit);
}

/// Whether reading one byte at `address` faults (SIGSEGV or SIGBUS) in a
/// forked child: the read a stale pointer would make, without risking this
/// process. The child catches the fault and exits with `fault_exit`, so no
/// crash report is written for it (macOS's ReportCrash).
fn faultsReading(address: usize) !bool {
    const pid = std.c.fork();
    if (pid < 0) return error.ForkFailed;
    if (pid == 0) {
        const act: std.posix.Sigaction = .{ .handler = .{ .handler = onFault }, .mask = std.posix.sigemptyset(), .flags = 0 };
        std.posix.sigaction(.SEGV, &act, null);
        std.posix.sigaction(.BUS, &act, null);
        const p: *const volatile u8 = @ptrFromInt(address);
        _ = p.*;
        std.c._exit(0);
    }
    var status: c_int = 0;
    if (std.c.waitpid(pid, &status, 0) != pid) return error.WaitFailed;
    const s: u32 = @bitCast(status);
    if (!std.c.W.IFEXITED(s)) return error.ChildDidNotExit;
    return switch (std.c.W.EXITSTATUS(s)) {
        0 => false,
        fault_exit => true,
        else => error.ChildFailed,
    };
}

/// The memory the OS charges this process for: darwin's phys_footprint (what
/// /performance/ and Activity Monitor report), Linux's resident set.
fn footprint() usize {
    if (comptime is_darwin) {
        var info: std.c.task_vm_info_data_t = undefined;
        var count: std.c.mach_msg_type_number_t = std.c.TASK.VM.INFO_COUNT;
        if (std.c.task_info(std.c.mach_task_self(), std.c.TASK.VM.INFO, @ptrCast(&info), &count) != 0) return 0;
        return @intCast(info.phys_footprint);
    }
    var buf: [128]u8 = undefined;
    const fd = std.c.open("/proc/self/statm", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return 0;
    defer _ = std.c.close(fd);
    const n = std.c.read(fd, &buf, buf.len);
    if (n <= 0) return 0;
    var it = std.mem.tokenizeScalar(u8, buf[0..@intCast(n)], ' ');
    _ = it.next();
    const pages = std.fmt.parseInt(usize, it.next() orelse return 0, 10) catch return 0;
    return pages * std.heap.pageSize();
}

fn touch(range: platform.AddressRange, offset: usize, length: usize, value: u8) void {
    const bytes: [*]volatile u8 = @ptrFromInt(range.base + offset);
    var i: usize = 0;
    const page = platform.pageSize();
    while (i < length) : (i += page) bytes[i] = value;
}

test "pageSize is this machine's page size, a power of two of at least 4 KiB" {
    try supported();
    const page = platform.pageSize();
    try testing.expectEqual(std.heap.pageSize(), page);
    try testing.expect(std.math.isPowerOfTwo(page));
    try testing.expect(page >= 4096);
}

test "a reservation is aligned to its alignment, at its offset, and inaccessible" {
    try supported();
    const aligned = try platform.reserveAddressSpace(64 * MiB, 64 * MiB, 0, .objects);
    defer platform.releaseAddressSpace(aligned);
    try testing.expectEqual(@as(usize, 64 * MiB), aligned.size);
    try testing.expectEqual(@as(usize, 0), aligned.base % (64 * MiB));
    try testing.expect(try faultsReading(aligned.base));
    try testing.expect(try faultsReading(aligned.base + aligned.size - 1));

    // A range whose base sits 32 MiB above a 64 MiB boundary: a Browser
    // heap's smaller-cage rung, the top part of its cage window.
    const skewed = try platform.reserveAddressSpace(16 * MiB, 64 * MiB, 32 * MiB, .node_cage);
    defer platform.releaseAddressSpace(skewed);
    try testing.expectEqual(@as(usize, 32 * MiB), skewed.base % (64 * MiB));
    try testing.expect(skewed.base + skewed.size <= aligned.base or aligned.base + aligned.size <= skewed.base);
}

test "a 64 GiB reservation aligned to 64 GiB: a Browser heap's full layout" {
    try supported();
    const range = try platform.reserveAddressSpace(64 * GiB, 64 * GiB, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try testing.expectEqual(@as(usize, 0), range.base % (64 * GiB));
}

test "committed pages are writable; decommitted ones stay accessible; Linux reads them as zero" {
    try supported();
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(16 * page, 16 * page, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try platform.commitPages(range, 4 * page, 4 * page);
    touch(range, 4 * page, 4 * page, 0x5a);
    const p: *volatile u8 = @ptrFromInt(range.base + 5 * page);
    try testing.expectEqual(@as(u8, 0x5a), p.*);
    // Pages outside the committed part are still inaccessible.
    try testing.expect(try faultsReading(range.base + 3 * page));
    try testing.expect(try faultsReading(range.base + 8 * page));

    try platform.decommitPages(range, 4 * page, 4 * page);
    // Still mapped: a read after decommit does not fault. On Linux it reads
    // zero; on darwin it may read the old byte (lesson
    // architecture-a-decommitted-page-on-macos-still-reads-its-old-bytes.md).
    try testing.expect(!try faultsReading(range.base + 5 * page));
    if (comptime is_linux) try testing.expectEqual(@as(u8, 0), p.*);

    try platform.commitPages(range, 4 * page, 4 * page);
    p.* = 0x33;
    try testing.expectEqual(@as(u8, 0x33), p.*);
}

test "footprint after decommit and recommit equals a fresh commit's (appendix P1: MADV_FREE_REUSE)" {
    try supported();
    // 64 MiB written, decommitted and written again: P1 measured 65.14 MiB
    // fresh, 1.14 after MADV_FREE_REUSABLE, and STILL 1.14 written again
    // without MADV_FREE_REUSE - a recycled span counted as 0 bytes.
    const size = 64 * MiB;
    const range = try platform.reserveAddressSpace(size, 2 * MiB, 0, .objects);
    defer platform.releaseAddressSpace(range);

    const before = footprint();
    try platform.commitPages(range, 0, size);
    touch(range, 0, size, 1);
    const fresh = footprint();
    try testing.expect(fresh >= before + size - 4 * MiB);

    try platform.decommitPages(range, 0, size);
    const released = footprint();
    try testing.expect(released + size - 8 * MiB <= fresh);

    try platform.commitPages(range, 0, size);
    touch(range, 0, size, 2);
    const reused = footprint();
    // Within 4 MiB of the fresh commit's: the recycled pages are counted.
    try testing.expect(reused + 4 * MiB >= fresh);
}

test "decommit before protect releases the memory and leaves the range inaccessible (oss R3's order)" {
    try supported();
    const size = 32 * MiB;
    const range = try platform.reserveAddressSpace(size, 2 * MiB, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try platform.commitPages(range, 0, size);
    touch(range, 0, size, 7);
    const fresh = footprint();
    try platform.decommitPages(range, 0, size);
    try platform.protectPages(range, 0, size, .none);
    try testing.expect(footprint() + size - 8 * MiB <= fresh);
    try testing.expect(try faultsReading(range.base));
    // And back: committed again, it is writable.
    try platform.commitPages(range, 0, platform.pageSize());
    touch(range, 0, platform.pageSize(), 9);
}

test "decommitPages returns an error when the OS refuses it, instead of failing silently" {
    try supported();
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(4 * page, page, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try platform.commitPages(range, 0, 4 * page);
    // A hole in the middle: neither MADV_FREE_REUSABLE nor MADV_DONTNEED can
    // apply to an unmapped page, so the operation must say it failed.
    try testing.expectEqual(@as(c_int, 0), std.c.munmap(@ptrFromInt(range.base + page), page));
    try testing.expect(std.meta.isError(platform.decommitPages(range, page, page)));
    // Put the page back (fixed, inaccessible), so the release unmaps one range.
    const back = std.c.mmap(@ptrFromInt(range.base + page), page, .{}, .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .FIXED = true }, -1, 0);
    try testing.expectEqual(range.base + page, @intFromPtr(back));
}

test "protectPages makes committed pages inaccessible and accessible again" {
    try supported();
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(4 * page, page, 0, .bytes);
    defer platform.releaseAddressSpace(range);
    try platform.commitPages(range, 0, 4 * page);
    touch(range, 0, 4 * page, 1);
    try platform.protectPages(range, page, page, .none);
    try testing.expect(try faultsReading(range.base + page));
    try testing.expect(!try faultsReading(range.base));
    try platform.protectPages(range, page, page, .read);
    try testing.expect(!try faultsReading(range.base + page));
    try platform.protectPages(range, page, page, .read_write);
    touch(range, page, page, 2);
}

/// Whether no page of [address, address + length) is mapped: msync answers
/// ENOMEM for an unmapped range on both OSes, and makes no mapping itself.
fn unmapped(address: usize, length: usize) bool {
    if (std.c.msync(@ptrFromInt(address), length, std.c.MSF.ASYNC) == 0) return false;
    const err: std.c.E = @fromBackingInt(@intCast(std.c._errno().*));
    return err == .NOMEM;
}

test "a released range is unmapped, and a read of it faults (a forked child), as a stale pointer would" {
    try supported();
    // The size of a Browser heap's window: a small released range is handed
    // to the next small mapping at once (appendix P4) - under
    // ThreadSanitizer the fork interceptor's own was enough to land on a
    // 4-page one (lane h1's TSAN verify on chat2, 2026-11-10).
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(64 * GiB, 64 * GiB, 0, .heap_metadata);
    try platform.commitPages(range, 0, 4 * page);
    touch(range, 0, 4 * page, 0x7f);
    try testing.expect(!unmapped(range.base, page));
    platform.releaseAddressSpace(range);
    // Checked before anything else maps: the whole range is gone.
    try testing.expect(unmapped(range.base, 4 * page));
    try testing.expect(unmapped(range.base + range.size / 2, page));
    try testing.expect(try faultsReading(range.base));
    try testing.expect(try faultsReading(range.base + 3 * page));
}

test "consecutive reservations do not reuse the released address (appendix P4: 7 of 7 did)" {
    try supported();
    // Random exact-size hints first: P4's over-reserve-and-trim got the
    // released address back 7 of 7 times on both OSes. ThreadSanitizer builds
    // place reservations where the kernel chooses (no hints: a hint can land
    // outside TSan's application ranges, which kills the process), so they
    // keep P4's behaviour.
    if (builtin.sanitize_thread) return error.SkipZigTest;
    var same: usize = 0;
    var previous = try platform.reserveAddressSpace(64 * GiB, 64 * GiB, 0, .objects);
    platform.releaseAddressSpace(previous);
    for (0..7) |_| {
        const next = try platform.reserveAddressSpace(64 * GiB, 64 * GiB, 0, .objects);
        platform.releaseAddressSpace(next);
        if (next.base == previous.base) same += 1;
        previous = next;
    }
    try testing.expect(same <= 2);
}

// ---------------------------------------------------------------------------
// Labels: what the OS's tools show
// ---------------------------------------------------------------------------

/// darwin: the VM tag of the map entry holding `address` (vmmap's
/// "App-Specific Tag N" is tag 239 + N).
fn darwinTag(address: usize) !u32 {
    if (comptime !builtin.os.tag.isDarwin()) unreachable;
    // VM_REGION_EXTENDED_INFO: every field 4 bytes, so its layout needs none
    // of the `#pragma pack(4)` the submap info's C declaration has.
    var region: std.c.mach_vm_address_t = address;
    var size: std.c.mach_vm_size_t = 0;
    var info: std.c.vm_region_extended_info = undefined;
    var count: std.c.mach_msg_type_number_t = std.c.VM.REGION.EXTENDED_INFO_COUNT;
    var object_name: std.c.mach_port_t = 0;
    if (std.c.mach_vm_region(std.c.mach_task_self(), &region, &size, std.c.VM.REGION.EXTENDED_INFO, @ptrCast(&info), &count, &object_name) != 0) return error.RegionQueryFailed;
    if (region > address) return error.NotMapped;
    return info.user_tag;
}

/// Linux: the /proc/self/maps line of the VMA holding `address`, copied.
fn linuxMapsLine(buffer: []u8, address: usize) ![]const u8 {
    if (comptime !is_linux) unreachable;
    const fd = std.c.open("/proc/self/maps", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return error.OpenFailed;
    defer _ = std.c.close(fd);
    var all: std.ArrayList(u8) = .empty;
    defer all.deinit(testing.allocator);
    var chunk: [65536]u8 = undefined;
    while (true) {
        const n = std.c.read(fd, &chunk, chunk.len);
        if (n <= 0) break;
        try all.appendSlice(testing.allocator, chunk[0..@intCast(n)]);
    }
    var lines = std.mem.tokenizeScalar(u8, all.items, '\n');
    while (lines.next()) |line| {
        const dash = std.mem.indexOfScalar(u8, line, '-') orelse continue;
        const space = std.mem.indexOfScalarPos(u8, line, dash, ' ') orelse continue;
        const lo = try std.fmt.parseInt(usize, line[0..dash], 16);
        const hi = try std.fmt.parseInt(usize, line[dash + 1 .. space], 16);
        if (address >= lo and address < hi) {
            const n = @min(line.len, buffer.len);
            @memcpy(buffer[0..n], line[0..n]);
            return buffer[0..n];
        }
    }
    return error.NotMapped;
}

test "every label is visible to the OS's tools: darwin VM tags 240-243, Linux [anon:crane-*] names" {
    try supported();
    const page = platform.pageSize();
    const range = try platform.reserveAddressSpace(16 * page, page, 0, .objects);
    defer platform.releaseAddressSpace(range);
    platform.labelAddressSpace(range, 0, 4 * page, .node_cage);
    platform.labelAddressSpace(range, 8 * page, 4 * page, .bytes);
    platform.labelAddressSpace(range, 12 * page, 4 * page, .heap_metadata);
    // Committing does not lose the label (mprotect keeps a map entry's tag
    // and a VMA's name).
    try platform.commitPages(range, 0, page);
    const expected = [_]struct { offset: usize, tag: u32, name: []const u8 }{
        .{ .offset = 0, .tag = 240, .name = "[anon:crane-node-cage]" },
        .{ .offset = 2 * page, .tag = 240, .name = "[anon:crane-node-cage]" },
        .{ .offset = 4 * page, .tag = 241, .name = "[anon:crane-objects]" },
        .{ .offset = 8 * page, .tag = 242, .name = "[anon:crane-bytes]" },
        .{ .offset = 12 * page, .tag = 243, .name = "[anon:crane-heap]" },
    };
    for (expected) |e| {
        if (comptime is_darwin) {
            try testing.expectEqual(e.tag, try darwinTag(range.base + e.offset));
        } else if (comptime is_linux) {
            var buffer: [512]u8 = undefined;
            const line = try linuxMapsLine(&buffer, range.base + e.offset);
            // A kernel without CONFIG_ANON_VMA_NAME (or before 5.17) names
            // nothing; the label is then absent, as in PartitionAlloc.
            if (std.mem.indexOf(u8, line, "[anon:") == null) return error.SkipZigTest;
            try testing.expect(std.mem.endsWith(u8, line, e.name));
        }
    }
}

// ---------------------------------------------------------------------------
// Linux transparent huge pages (appendix P3)
// ---------------------------------------------------------------------------

/// The AnonHugePages of every VMA inside [lo, hi), in kB, from
/// /proc/self/smaps.
fn linuxAnonHugeKb(lo: usize, hi: usize) !usize {
    if (comptime !is_linux) unreachable;
    const fd = std.c.open("/proc/self/smaps", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return error.OpenFailed;
    defer _ = std.c.close(fd);
    var all: std.ArrayList(u8) = .empty;
    defer all.deinit(testing.allocator);
    var chunk: [65536]u8 = undefined;
    while (true) {
        const n = std.c.read(fd, &chunk, chunk.len);
        if (n <= 0) break;
        try all.appendSlice(testing.allocator, chunk[0..@intCast(n)]);
    }
    var total: usize = 0;
    var inside = false;
    var lines = std.mem.tokenizeScalar(u8, all.items, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOfScalar(u8, line, '-')) |dash| if (dash > 0 and std.ascii.isHex(line[0])) {
            const space = std.mem.indexOfScalarPos(u8, line, dash, ' ') orelse continue;
            const start = std.fmt.parseInt(usize, line[0..dash], 16) catch continue;
            const end = std.fmt.parseInt(usize, line[dash + 1 .. space], 16) catch continue;
            inside = start >= lo and end <= hi;
            continue;
        };
        if (inside and std.mem.startsWith(u8, line, "AnonHugePages:")) {
            var fields = std.mem.tokenizeScalar(u8, line["AnonHugePages:".len..], ' ');
            total += try std.fmt.parseInt(usize, fields.next() orelse "0", 10);
        }
    }
    return total;
}

test "Linux: the node cage takes no transparent huge pages, even where every range may (appendix P3)" {
    try supported();
    if (comptime !is_linux) return error.SkipZigTest;
    // The host's THP mode, for the log: P3 ran on server1's `madvise`.
    var mode_buffer: [128]u8 = undefined;
    const mode = blk: {
        const fd = std.c.open("/sys/kernel/mm/transparent_hugepage/enabled", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
        if (fd < 0) return error.SkipZigTest; // no THP in this kernel
        defer _ = std.c.close(fd);
        const n = std.c.read(fd, &mode_buffer, mode_buffer.len);
        if (n <= 0) return error.SkipZigTest;
        break :blk std.mem.trimEnd(u8, mode_buffer[0..@intCast(n)], "\n");
    };
    std.log.warn("h1 THP test: transparent_hugepage/enabled = {s}", .{mode});
    if (std.mem.indexOf(u8, mode, "[never]") != null) return error.SkipZigTest;

    // P3's shape: 32 super pages of 2 MiB, committed one at a time, one 16
    // KiB span written in each - 512 kB live. THP `always` (emulated, as P3
    // did, with MADV_HUGEPAGE on the range: what `always` applies to every
    // mapping) gave 64 MiB of huge pages. The cage label must exclude the
    // range whatever the system setting.
    const super = 2 * MiB;
    const supers = 32;
    const range = try platform.reserveAddressSpace(supers * super, super, 0, .objects);
    defer platform.releaseAddressSpace(range);
    try testing.expectEqual(@as(c_int, 0), std.c.madvise(@ptrFromInt(range.base), range.size, std.os.linux.MADV.HUGEPAGE));
    platform.labelAddressSpace(range, 0, range.size, .node_cage);
    for (0..supers) |s| try platform.commitPages(range, s * super, super);
    for (0..supers) |s| touch(range, s * super, 16 * 1024, 1);
    try testing.expectEqual(@as(usize, 0), try linuxAnonHugeKb(range.base, range.base + range.size));
}

// ---------------------------------------------------------------------------
// Out of address space
// ---------------------------------------------------------------------------

test "Linux: a reservation larger than RLIMIT_AS allows fails with OutOfMemory" {
    try supported();
    // macOS accepts RLIMIT_AS but does not enforce it on mmap.
    if (comptime !is_linux) return error.SkipZigTest;
    var old: std.c.rlimit = undefined;
    try testing.expectEqual(@as(c_int, 0), std.c.getrlimit(.AS, &old));
    const in_use = linuxVmSize() orelse return error.SkipZigTest;
    // A process that already holds a sanitizer's or an engine's terabytes
    // cannot be limited to a few GiB more.
    if (in_use > 32 * GiB) return error.SkipZigTest;
    var limit = old;
    limit.cur = in_use + 2 * GiB;
    try testing.expectEqual(@as(c_int, 0), std.c.setrlimit(.AS, &limit));
    defer _ = std.c.setrlimit(.AS, &old);
    try testing.expectError(error.OutOfMemory, platform.reserveAddressSpace(8 * GiB, 64 * GiB, 0, .objects));
    const small = try platform.reserveAddressSpace(64 * MiB, 64 * MiB, 0, .objects);
    platform.releaseAddressSpace(small);
}

/// VmSize from /proc/self/status, in bytes.
fn linuxVmSize() ?usize {
    if (comptime !is_linux) return null;
    var buf: [4096]u8 = undefined;
    const fd = std.c.open("/proc/self/status", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    const n = std.c.read(fd, &buf, buf.len);
    if (n <= 0) return null;
    const text = buf[0..@intCast(n)];
    const at = std.mem.indexOf(u8, text, "VmSize:") orelse return null;
    var fields = std.mem.tokenizeAny(u8, text[at + "VmSize:".len ..], " \t\n");
    const kb = std.fmt.parseInt(usize, fields.next() orelse return null, 10) catch return null;
    return kb * 1024;
}
