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
//! recommits a discarded chunk before it hands out a byte of it, as
//! PartitionAlloc does for Chrome's ArrayBuffers.
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

const buffer_count = 64;
const buffer_bytes = MiB;
const total = buffer_count * buffer_bytes;

/// `buffer_count` ArrayBuffers of 1 MiB, every byte written with `value`.
/// Each handle is OWNED by the caller (v8_ArrayBuffer_Dispose).
fn makeBuffers(isolate: *ffi.Isolate, buffers: *[buffer_count]*ffi.ArrayBuffer, value: u8) !void {
    var made: usize = 0;
    errdefer for (buffers[0..made]) |buffer| ffi.v8_ArrayBuffer_Dispose(buffer);
    while (made < buffer_count) : (made += 1) {
        const buffer = ffi.v8_ArrayBuffer_New(isolate, buffer_bytes) orelse return error.ArrayBufferAllocationFailed;
        buffers[made] = buffer;
        const data: [*]u8 = @ptrCast(ffi.v8_ArrayBuffer_Data(buffer) orelse return error.ArrayBufferHasNoData);
        // A zero-initialised ArrayBuffer reads zero wherever its memory was before.
        try testing.expectEqual(@as(u8, 0), data[0]);
        try testing.expectEqual(@as(u8, 0), data[buffer_bytes / 2]);
        try testing.expectEqual(@as(u8, 0), data[buffer_bytes - 1]);
        @memset(data[0..buffer_bytes], value);
    }
}

/// Detach every buffer - which frees its backing store at once, with no
/// collection (V8 JSArrayBuffer::Detach drops the store's last reference) -
/// and release the handles.
fn freeBuffers(buffers: *[buffer_count]*ffi.ArrayBuffer) void {
    for (buffers) |buffer| {
        ffi.v8_ArrayBuffer_Detach(buffer);
        ffi.v8_ArrayBuffer_Dispose(buffer);
    }
}

test "ArrayBuffer memory freed and allocated again is counted in the process footprint" {
    var agent: test_process.TestAgent = .{};
    const isolate = try agent.open(.{});
    defer agent.close();

    const before = footprint();
    if (before == 0) return error.SkipZigTest;

    var buffers: [buffer_count]*ffi.ArrayBuffer = undefined;
    try makeBuffers(isolate, &buffers, 1);
    // One live allocation above the 64: with V8's default allocator the freed
    // range then lies below a live block and is DISCARDED (the path that
    // loses the bytes), not decommitted as a free range at the top is. A
    // small block may land in a hole below them, so larger ones follow until
    // one is above (a best-fit allocator puts a block no hole fits at the
    // top); with none above, the test still holds for the path taken.
    var highest: usize = 0;
    for (buffers) |buffer| highest = @max(highest, @intFromPtr(ffi.v8_ArrayBuffer_Data(buffer).?));
    var guards: [3]?*ffi.ArrayBuffer = @splat(null);
    defer for (guards) |guard| if (guard) |g| ffi.v8_ArrayBuffer_Dispose(g);
    for ([_]usize{ 4096, 2 * MiB, 16 * MiB }, &guards) |size, *guard| {
        guard.* = ffi.v8_ArrayBuffer_New(isolate, size) orelse return error.ArrayBufferAllocationFailed;
        if (@intFromPtr(ffi.v8_ArrayBuffer_Data(guard.*.?).?) > highest) break;
    }
    const fresh = footprint();
    try testing.expect(fresh >= before + total - 4 * MiB);

    // Freed: the memory goes back to the OS (all of it but what the
    // allocator may keep for the next allocation, 256 KiB at most).
    freeBuffers(&buffers);
    const released = footprint();
    try testing.expect(released + total - 8 * MiB <= fresh);

    // Allocated and written again: within 4 MiB of the first time.
    try makeBuffers(isolate, &buffers, 2);
    const reused = footprint();
    freeBuffers(&buffers);
    if (reused + 4 * MiB < fresh) {
        std.debug.print("footprint: before {d} MiB, 64 MiB written {d} MiB, freed {d} MiB, written again {d} MiB\n", .{ before / MiB, fresh / MiB, released / MiB, reused / MiB });
        return error.ReusedArrayBufferMemoryIsNotCounted;
    }
}
