//! A Browser's heap on this machine (lane h1, phase H1): runtime.BrowserScope
//! .reserveHeap through the real platform (docs/platform-protocol.md 6.11).
//! The fake-platform tests of the layout and the ladder are
//! tests/runtime/h1_browser_heap_test.zig; the platform's own,
//! tests/platform/h1_address_space_test.zig; a whole Browser's,
//! tests/browser/h1_browser_heap_test.zig.
//!
//! No test here starts the engine: a Browser heap needs none, and the
//! RLIMIT_AS test needs a process that does not hold V8's terabyte of
//! reservations.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");
const platform = @import("platform");

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;

const MiB: usize = 1024 * 1024;
const GiB: usize = 1024 * MiB;

const fault_exit = 42;

fn onFault(_: std.posix.SIG) callconv(.c) void {
    std.c._exit(fault_exit);
}

/// Whether reading a byte at `address` faults in a forked child (which
/// catches the fault, so no crash report is written).
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

/// Linux: whether /proc/self/maps names the VMA holding `address` `name`;
/// null when the kernel names no anonymous VMA at all.
fn linuxNamed(address: usize, name: []const u8) !?bool {
    if (comptime builtin.os.tag != .linux) unreachable;
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
    if (std.mem.indexOf(u8, all.items, "[anon:") == null) return null;
    var lines = std.mem.tokenizeScalar(u8, all.items, '\n');
    while (lines.next()) |line| {
        const dash = std.mem.indexOfScalar(u8, line, '-') orelse continue;
        const space = std.mem.indexOfScalarPos(u8, line, dash, ' ') orelse continue;
        const lo = std.fmt.parseInt(usize, line[0..dash], 16) catch continue;
        const hi = std.fmt.parseInt(usize, line[dash + 1 .. space], 16) catch continue;
        if (address >= lo and address < hi) return std.mem.endsWith(u8, line, name);
    }
    return error.NotMapped;
}

fn vmSize() ?usize {
    if (comptime builtin.os.tag != .linux) return null;
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

test "a scope's heap on this machine: its window aligned to itself, labelled, its header committed, every link below the first node super page inaccessible" {
    defer Heap.releaseKeptReservations();
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    try scope.reserveHeap(platform, null);
    const heap = scope.heap.?;
    const l = Heap.layout;
    try testing.expectEqual(@as(usize, 0), heap.window_base % @as(usize, @intCast(l.window_bytes)));
    try testing.expectEqual(heap, Heap.heapOf(@ptrFromInt(heap.at(l.first_node_offset))));
    try testing.expectEqual(&scope, BrowserScope.ofHeap(heap));

    // R1's red test: every link value below the first node super page
    // decodes into the cage's first super page, which is never committed.
    const L = Heap.Link(u8);
    const holder: *const u8 = @ptrFromInt(heap.at(l.first_node_offset + 64));
    for ([_]u32{ 1, 0x1000, 0x10000, @intCast((l.first_node_offset >> Heap.geometry.cage_shift) - 1) }) |value| {
        const decoded = @intFromPtr((@as(L, @fromBackingInt(value))).get(holder).?);
        try testing.expect(try faultsReading(decoded));
    }
    // So is the cage's top guard, and the first span of the metadata's super
    // page (oss R19).
    try testing.expect(try faultsReading(heap.at(l.cage_top_guard.offset)));
    try testing.expect(try faultsReading(heap.at(l.metadata.offset)));
    try testing.expect(!try faultsReading(@intFromPtr(heap)));

    // What the OS's tools show.
    if (comptime builtin.os.tag.isDarwin()) {
        try testing.expectEqual(@as(u32, 240), try darwinTag(heap.at(l.first_node_offset)));
        try testing.expectEqual(@as(u32, 243), try darwinTag(heap.at(l.metadata.offset)));
        if (heap.rung == .full) {
            try testing.expectEqual(@as(u32, 241), try darwinTag(heap.at(l.objects.offset)));
            try testing.expectEqual(@as(u32, 242), try darwinTag(heap.at(l.bytes.offset)));
        }
    } else if (comptime builtin.os.tag == .linux) {
        if (try linuxNamed(heap.at(l.first_node_offset), "[anon:crane-node-cage]")) |named| {
            try testing.expect(named);
            try testing.expect((try linuxNamed(@intFromPtr(heap), "[anon:crane-heap]")).?);
            if (heap.rung == .full) {
                try testing.expect((try linuxNamed(heap.at(l.objects.offset), "[anon:crane-objects]")).?);
                try testing.expect((try linuxNamed(heap.at(l.bytes.offset), "[anon:crane-bytes]")).?);
            }
        }
    }
}

test "a released heap's window faults, as a stale pointer into the Browser would" {
    defer Heap.releaseKeptReservations();
    var scope = BrowserScope.init(testing.allocator);
    try scope.reserveHeap(platform, null);
    const header = @intFromPtr(scope.heap.?);
    try testing.expect(!try faultsReading(header));
    scope.deinit();
    try testing.expect(try faultsReading(header));
}

test "8 heaps at once on 8 threads are disjoint, and 2,200 in sequence each give their reservation back" {
    defer Heap.releaseKeptReservations();
    const Worker = struct {
        fn run(base: *usize, failed: *bool) void {
            var scope = BrowserScope.init(std.heap.page_allocator);
            defer scope.deinit();
            scope.reserveHeap(platform, null) catch {
                failed.* = true;
                return;
            };
            base.* = scope.heap.?.window_base;
            // Hold it while the others reserve.
            var spin: usize = 0;
            while (spin < 1000) : (spin += 1) std.atomic.spinLoopHint();
        }
    };
    var bases: [8]usize = @splat(0);
    var failed: [8]bool = @splat(false);
    var threads: [8]std.Thread = undefined;
    for (&threads, 0..) |*t, i| t.* = try std.Thread.spawn(.{}, Worker.run, .{ &bases[i], &failed[i] });
    for (threads) |t| t.join();
    for (failed) |f| try testing.expect(!f);
    for (bases, 0..) |a, i| for (bases[i + 1 ..]) |b| try testing.expect(a != b);

    // 2,200 windows of 64 GiB are 137.5 TiB: more than a process's whole
    // address space on either OS (macOS 127.5 TiB, Linux 128 TiB, measured in
    // arch 4.3). If any one end kept its reservation, a later start would
    // find no room. The process's own VA total is not compared: it is every
    // Browser's in the process (lesson
    // testing-a-test-that-measures-a-process-wide-counter-assumes-it-is-alone.md).
    for (0..2200) |_| {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        try scope.reserveHeap(platform, null);
        try testing.expectEqual(Heap.Rung.full, scope.heap.?.rung);
    }
}

test "Linux RLIMIT_AS: at 96 GiB a heap still reserves; at a few GiB a smaller cage; below that a clean OutOfMemory (oss R11)" {
    if (comptime builtin.os.tag != .linux) return error.SkipZigTest; // macOS does not enforce RLIMIT_AS on mmap
    if (Heap.profile != .full) return error.SkipZigTest;
    defer Heap.releaseKeptReservations();
    Heap.releaseKeptReservations();
    const in_use = vmSize() orelse return error.SkipZigTest;
    // A process holding an engine's or a sanitizer's terabytes cannot be
    // limited below them (the many-Browsers variant's busy Browser, TSan).
    if (in_use > 16 * GiB) return error.SkipZigTest;
    var old: std.c.rlimit = undefined;
    try testing.expectEqual(@as(c_int, 0), std.c.getrlimit(.AS, &old));
    defer _ = std.c.setrlimit(.AS, &old);
    var limit = old;

    limit.cur = 96 * GiB;
    try testing.expectEqual(@as(c_int, 0), std.c.setrlimit(.AS, &limit));
    {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        try scope.reserveHeap(platform, null);
        const rung = scope.heap.?.rung;
        try testing.expect(rung == .full or rung == .cage_alone);
    }
    Heap.releaseKeptReservations();

    const l = Heap.layout;
    // Room for the half-size cage and its metadata, not for the whole cage.
    limit.cur = @intCast(in_use + @as(usize, @intCast(l.cage_alone_end - l.cage.bytes / 2)) + 256 * MiB);
    try testing.expectEqual(@as(c_int, 0), std.c.setrlimit(.AS, &limit));
    {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        try scope.reserveHeap(platform, null);
        try testing.expectEqual(Heap.Rung.smaller_cage, scope.heap.?.rung);
        try testing.expect(scope.heap.?.cage_lo >= l.cage.bytes / 2);
    }
    Heap.releaseKeptReservations();

    limit.cur = in_use + 64 * MiB;
    try testing.expectEqual(@as(c_int, 0), std.c.setrlimit(.AS, &limit));
    {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        try testing.expectError(error.OutOfMemory, scope.reserveHeap(platform, null));
        try testing.expect(scope.heap == null);
    }
}
