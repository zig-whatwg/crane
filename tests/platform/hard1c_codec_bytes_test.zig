//! Allocator hardening, batch C, item 3: Brotli and zlib C-library callback
//! allocations (`Memory.alloc`/`Memory.free`) route to the `.bytes` partition
//! (alignment < `@alignOf(usize)`), while keeping the pointer-bearing Zig
//! wrapper struct (`Decoder`/`Encoder`) pointer-aligned (`.objects`) and
//! handing the C library strictly 16-byte-aligned buffers.
//!
//! Design: tmp/plans/allocator-hardening-design.md §§1.2 row 42, 3.1, 7 Batch C
//! item 3.
//!
//! RED on main `7cec3d819`: `kit/brotli/root.zig` and `kit/inflate/zlib.zig`
//! call `rawAlloc(total, .@"16", ...)`, whose alignment >= `@alignOf(usize)`
//! sends every C buffer into the `.objects` partition (with zeroing and
//! quarantine) instead of `.bytes`.

const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

/// Minimal valid Brotli stream encoding "foo" (pv1_brotli_test.zig).
const brotli_foo = [_]u8{ 0x21, 0x08, 0x00, 0x04, 0x66, 0x6f, 0x6f, 0x03 };

/// Minimal valid raw DEFLATE stream encoding "foo" (stored block).
const deflate_foo = [_]u8{ 0x01, 0x03, 0x00, 0xfc, 0xff, 'f', 'o', 'o' };

/// Counts allocations by whether `heap.general.partitionFor(alignment)` sends
/// them to `.bytes` (`< @alignOf(usize)`) or `.objects` (`>= @alignOf(usize)`).
const PartitionAuditAllocator = struct {
    child: std.mem.Allocator,
    objects_allocs: usize = 0,
    objects_bytes: usize = 0,
    bytes_allocs: usize = 0,
    bytes_bytes: usize = 0,

    fn allocator(self: *PartitionAuditAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *PartitionAuditAllocator = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawAlloc(len, alignment, ra) orelse return null;
        if (alignment.toByteUnits() < @alignOf(usize)) {
            self.bytes_allocs += 1;
            self.bytes_bytes += len;
        } else {
            self.objects_allocs += 1;
            self.objects_bytes += len;
        }
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *PartitionAuditAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(memory, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *PartitionAuditAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(memory, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *PartitionAuditAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
    }
};

test "item 3: Brotli decoder routes C callback buffers to bytes, wrapper struct to objects" {
    if (platform.capabilities.brotli == .unsupported) return;
    var audit: PartitionAuditAllocator = .{ .child = testing.allocator };
    const decoder = try platform.createBrotliDecoder(audit.allocator());
    defer platform.destroyBrotliDecoder(decoder);

    var out: [32]u8 = undefined;
    const progress = try platform.decompressBrotli(decoder, .from(&brotli_foo), &out);
    try testing.expectEqual(platform.CodecStatus.finished, progress.status);
    try testing.expectEqualStrings("foo", out[0..progress.produced]);

    // Only the small Zig Decoder wrapper struct belongs in `.objects`.
    try testing.expectEqual(@as(usize, 1), audit.objects_allocs);
    // Every Brotli C callback allocation (state + ring buffer) routes to `.bytes`.
    try testing.expect(audit.bytes_allocs >= 1);
    try testing.expect(audit.bytes_bytes > audit.objects_bytes);
}

test "item 3: Brotli encoder routes C callback buffers to bytes, wrapper struct to objects" {
    if (platform.capabilities.brotli == .unsupported) return;
    var audit: PartitionAuditAllocator = .{ .child = testing.allocator };
    const encoder = try platform.createBrotliEncoder(audit.allocator());
    defer platform.destroyBrotliEncoder(encoder);

    var out: [128]u8 = undefined;
    const progress = try platform.compressBrotli(encoder, .from("hello brotli bytes partition"), &out, true);
    try testing.expectEqual(platform.CodecStatus.finished, progress.status);
    try testing.expect(progress.produced > 0);

    try testing.expectEqual(@as(usize, 1), audit.objects_allocs);
    try testing.expect(audit.bytes_allocs >= 1);
    try testing.expect(audit.bytes_bytes > audit.objects_bytes);
}

test "item 3: zlib deflate decoder routes C callback buffers to bytes, wrapper struct to objects" {
    if (platform.capabilities.deflate_decoding == .unsupported) return;
    var audit: PartitionAuditAllocator = .{ .child = testing.allocator };
    const decoder = try platform.createDeflateDecoder(audit.allocator());
    defer platform.destroyDeflateDecoder(decoder);

    var out: [32]u8 = undefined;
    const progress = try platform.decompressDeflate(decoder, .from(&deflate_foo), &out);
    try testing.expectEqual(platform.CodecStatus.finished, progress.status);
    try testing.expectEqualStrings("foo", out[0..progress.produced]);

    try testing.expectEqual(@as(usize, 1), audit.objects_allocs);
    try testing.expect(audit.bytes_allocs >= 1);
    try testing.expect(audit.bytes_bytes > audit.objects_bytes);
}
