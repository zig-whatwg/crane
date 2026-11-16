//! What the OS charges the process for ArrayBuffer memory that was freed and
//! allocated again (lane ab1; a Memory-kind test, tests/AGENTS.md).
//!
//! macOS counts a page in a task's phys_footprint - the figure Activity
//! Monitor and /performance/ report - until it is given back with
//! madvise(MADV_FREE_REUSABLE), and counts it AGAIN only after
//! madvise(MADV_FREE_REUSE): a page written again without that call stays out
//! of the footprint (crbug.com/823915; tests/platform/h1_address_space_test.zig
//! pins the same fact for the platform's own pages). V8 15.7's default
//! in-sandbox allocator (src/sandbox/sandbox.cc DefaultInSandboxAllocator)
//! discards every fully free 1 MiB chunk and hands it out again with a memset
//! and no recommit, so 64 MiB of ArrayBuffers freed and allocated again read
//! as about 1 MiB (lane mem2: fetch.loopback-gzip 100 MB against 139 MB).
//! Crane's own allocator (src/runtime/engines/v8/sandbox_allocator.zig)
//! recommits discarded pages before it hands out a byte of them, as
//! PartitionAlloc does for Chrome's ArrayBuffers - and only the pages a block
//! uses: MADV_FREE_REUSE counts every page of its range that still holds its
//! old bytes, written again or not, so a recommit of whole 1 MiB chunks
//! counted memory no buffer used (fetch.loopback-gzip: 142 MB against the
//! 115 MB its buffers and the rest of the process held).
//!
//! On Linux a discarded page (MADV_DONTNEED) is counted again when it is
//! written, so the test passes there with either allocator.

const std = @import("std");
const builtin = @import("builtin");
const test_process = @import("test_process.zig");
const v8 = @import("v8");
const ffi = v8.ffi;

const testing = std.testing;

const MiB: usize = 1024 * 1024;

/// The memory the OS charges this process for: darwin's phys_footprint,
/// Linux's resident set (as tests/platform/h1_address_space_test.zig reads
/// it; the platform protocol has the resident size only).
fn footprint() usize {
    if (comptime builtin.os.tag.isDarwin()) {
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

/// How far a step's rise or fall of the footprint may miss the 64 MiB it
/// moves. Each step is read as a difference over the few milliseconds it
/// takes, never against a reading from an earlier step: the rest of the
/// process moves the footprint too - libc malloc gives large freed blocks
/// back late, and a repeated run (verify mode) starts beside what the run
/// before left to be released (seen: 10 MiB leaving in the middle of a run).
/// With V8's default allocator the last step's rise is under 1 MiB.
const slack = 16 * MiB;

/// How many bytes the footprint rose from `from` to `to` (0 when it fell).
fn counted(from: usize, to: usize) usize {
    return to -| from;
}

const buffer_count = 64;
const buffer_bytes = MiB;
const total = buffer_count * buffer_bytes;

/// One ArrayBuffer of `bytes` in each place of `buffers`, every byte written
/// with `value`. Each handle is OWNED by the caller (v8_ArrayBuffer_Dispose);
/// on an error none is left.
fn makeBuffers(isolate: *ffi.Isolate, buffers: []*ffi.ArrayBuffer, bytes: usize, value: u8) !void {
    var made: usize = 0;
    errdefer for (buffers[0..made]) |buffer| ffi.v8_ArrayBuffer_Dispose(buffer);
    while (made < buffers.len) : (made += 1) {
        const buffer = ffi.v8_ArrayBuffer_New(isolate, bytes) orelse return error.ArrayBufferAllocationFailed;
        buffers[made] = buffer;
        const data: [*]u8 = @ptrCast(ffi.v8_ArrayBuffer_Data(buffer) orelse return error.ArrayBufferHasNoData);
        // A zero-initialised ArrayBuffer reads zero wherever its memory was before.
        try testing.expectEqual(@as(u8, 0), data[0]);
        try testing.expectEqual(@as(u8, 0), data[bytes / 2]);
        try testing.expectEqual(@as(u8, 0), data[bytes - 1]);
        @memset(data[0..bytes], value);
    }
}

/// Detach every buffer - which frees its backing store at once, with no
/// collection (V8 JSArrayBuffer::Detach drops the store's last reference) -
/// and release the handles.
fn freeBuffers(buffers: []const *ffi.ArrayBuffer) void {
    for (buffers) |buffer| {
        ffi.v8_ArrayBuffer_Detach(buffer);
        ffi.v8_ArrayBuffer_Dispose(buffer);
    }
}

/// Live allocations above `buffers`, each OWNED by the caller: the range
/// `buffers` free then lies below a live block and is DISCARDED (the path
/// that loses the bytes with V8's default allocator, and the one a recommit
/// follows), not decommitted as a free range at the top is. A small block
/// may land in a hole below them, so larger ones follow until one is above
/// (a best-fit allocator puts a block no hole fits at the top); with none
/// above, a test still holds for the path taken.
fn guardAbove(isolate: *ffi.Isolate, buffers: []const *ffi.ArrayBuffer, guards: *[3]?*ffi.ArrayBuffer) !void {
    var highest: usize = 0;
    for (buffers) |buffer| highest = @max(highest, @intFromPtr(ffi.v8_ArrayBuffer_Data(buffer).?));
    for ([_]usize{ 4096, 2 * MiB, 16 * MiB }, guards) |size, *guard| {
        guard.* = ffi.v8_ArrayBuffer_New(isolate, size) orelse return error.ArrayBufferAllocationFailed;
        if (@intFromPtr(ffi.v8_ArrayBuffer_Data(guard.*.?).?) > highest) break;
    }
}

test "ArrayBuffer memory freed and allocated again is counted in the process footprint" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    const before = footprint();
    if (before == 0) return error.SkipZigTest;

    var buffers: [buffer_count]*ffi.ArrayBuffer = undefined;
    try makeBuffers(isolate, &buffers, buffer_bytes, 1);
    var guards: [3]?*ffi.ArrayBuffer = @splat(null);
    defer for (guards) |guard| if (guard) |g| ffi.v8_ArrayBuffer_Dispose(g);
    guardAbove(isolate, &buffers, &guards) catch |err| {
        freeBuffers(&buffers);
        return err;
    };
    const fresh = footprint();
    try testing.expect(counted(before, fresh) >= total - slack);

    // Freed: the memory goes back to the OS (all of it but what the
    // allocator may keep for the next allocation, 1 MiB at most).
    freeBuffers(&buffers);
    const released = footprint();
    try testing.expect(counted(released, fresh) >= total - slack);

    // Allocated and written again: the footprint rises by what was written,
    // as it did the first time.
    try makeBuffers(isolate, &buffers, buffer_bytes, 2);
    const reused = footprint();
    freeBuffers(&buffers);
    if (counted(released, reused) < total - slack) {
        std.debug.print("footprint: before {d} MiB, 64 MiB written {d} MiB, freed {d} MiB, written again {d} MiB\n", .{ before / MiB, fresh / MiB, released / MiB, reused / MiB });
        return error.ReusedArrayBufferMemoryIsNotCounted;
    }
}

test "an ArrayBuffer made where larger ones were freed is counted for its own bytes, not for the pages freed beside it" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    if (footprint() == 0) return error.SkipZigTest;

    // 32 buffers of 2 MiB, every byte written, freed below a live block: 64
    // MiB given back, its pages still holding their bytes until the OS needs
    // them.
    var large: [32]*ffi.ArrayBuffer = undefined;
    try makeBuffers(isolate, &large, 2 * MiB, 1);
    var guards: [3]?*ffi.ArrayBuffer = @splat(null);
    defer for (guards) |guard| if (guard) |g| ffi.v8_ArrayBuffer_Dispose(g);
    guardAbove(isolate, &large, &guards) catch |err| {
        freeBuffers(&large);
        return err;
    };
    freeBuffers(&large);
    const released = footprint();

    // 32 buffers of 1 MiB and 7 bytes (the body fetch.loopback-gzip reads),
    // every byte written: 32 MiB. Each takes the place of a 2 MiB one; the
    // megabyte beside it that it does not use stays given back. V8's default
    // allocator counts none of the 32 MiB; a recommit of whole 1 MiB chunks
    // counts 64.
    var bodies: [32]*ffi.ArrayBuffer = undefined;
    try makeBuffers(isolate, &bodies, MiB + 7, 2);
    const reused = footprint();
    freeBuffers(&bodies);
    const rise = counted(released, reused);
    if (rise < 32 * MiB - slack or rise > 32 * MiB + slack) {
        std.debug.print("footprint: 64 MiB freed {d} MiB, 32 buffers of 1 MiB + 7 bytes written there {d} MiB: a rise of {d} MiB, not 32\n", .{ released / MiB, reused / MiB, rise / MiB });
        return if (rise < 32 * MiB) error.ReusedArrayBufferMemoryIsNotCounted else error.FreedMemoryBesideABufferIsCounted;
    }
}

test "small ArrayBuffers on chunks given back are counted for their own pages, not for the megabyte each chunk held" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    if (footprint() == 0) return error.SkipZigTest;

    // 64 MiB written and freed below a live block, as in the first test.
    var buffers: [buffer_count]*ffi.ArrayBuffer = undefined;
    try makeBuffers(isolate, &buffers, buffer_bytes, 1);
    var guards: [3]?*ffi.ArrayBuffer = @splat(null);
    defer for (guards) |guard| if (guard) |g| ffi.v8_ArrayBuffer_Dispose(g);
    guardAbove(isolate, &buffers, &guards) catch |err| {
        freeBuffers(&buffers);
        return err;
    };
    freeBuffers(&buffers);
    const released = footprint();

    // 48 small buffers, each of a size class of its own (320 bytes to 18
    // KiB: 220 KiB in all), so each class takes a chunk that was given back.
    // Recommitted whole, every such chunk was counted for the megabyte
    // written there before: 48 MiB for 220 KiB of buffers.
    var small: [48]*ffi.ArrayBuffer = undefined;
    var made: usize = 0;
    defer freeBuffers(small[0..made]);
    while (made < small.len) : (made += 1) {
        try makeBuffers(isolate, small[made..][0..1], v8.sandbox_allocator.class_sizes[17 + made], 3);
    }
    const reused = footprint();
    const rise = counted(released, reused);
    if (rise > slack) {
        std.debug.print("footprint: 64 MiB freed {d} MiB, 48 small buffers made there {d} MiB: a rise of {d} MiB for under 1 MiB of buffers\n", .{ released / MiB, reused / MiB, rise / MiB });
        return error.FreedMemoryBesideABufferIsCounted;
    }
}
