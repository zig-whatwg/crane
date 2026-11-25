//! Unit tests for file-backed BlobData sources (lane blobsrc1):
//! - Lazy reads (0 reads at initFile, sliceBlob, processBlobPartsToData,
//!   BlobURLStore.createObjectURL)
//! - NotFoundError (missing) and NotReadableError (modified snapshot)
//! - 0-byte file snapshot validation
//! - Sliced file-backed blobs and composite mixed-parts blobs
//! - Thread-safe atomic FileBacking refcounting (0 leaked tokens!)
//! - BlobURLStore read failure on missing/modified file backing

const std = @import("std");
const testing = std.testing;
const file = @import("file");

const MockFile = struct {
    bytes: []const u8,
    state: State = .ok,
    reads: std.atomic.Value(u32) = .init(0),
    releases: std.atomic.Value(u32) = .init(0),

    const State = enum { ok, missing, modified };

    const ops: file.FileSourceOps = .{
        .read = &read,
        .release = &release,
    };

    fn read(ctx: *anyopaque, offset: u64, length: u32, allocator: std.mem.Allocator) file.FileReadError![]u8 {
        const self: *MockFile = @ptrCast(@alignCast(ctx));
        _ = self.reads.fetchAdd(1, .acq_rel);
        switch (self.state) {
            .missing => return error.NotFoundError,
            .modified => return error.NotReadableError,
            .ok => {},
        }
        if (offset >= self.bytes.len or length == 0) return allocator.alloc(u8, 0);
        const start: usize = @intCast(offset);
        const take = @min(@as(usize, length), self.bytes.len - start);
        return allocator.dupe(u8, self.bytes[start..][0..take]);
    }

    fn release(ctx: *anyopaque) void {
        const self: *MockFile = @ptrCast(@alignCast(ctx));
        _ = self.releases.fetchAdd(1, .acq_rel);
    }
};

test "file-backed BlobData reads lazily, validates snapshots, and releases token exactly once" {
    const a = testing.allocator;
    var mock: MockFile = .{ .bytes = "abcdefghij" };
    const backing = try file.FileBacking.init(a, &mock, &MockFile.ops, 10, 123456);
    const blob = try file.BlobData.initFile(a, backing, "text/plain");
    backing.release();

    // Construction, size(), getType() must NOT read the file.
    try testing.expectEqual(@as(u32, 0), mock.reads.load(.acquire));
    try testing.expectEqual(@as(u64, 10), blob.size());
    try testing.expectEqualStrings("text/plain", blob.getType());
    try testing.expect(!blob.isMemoryOnly());
    try testing.expect(blob.memoryBytes() == null);
    try testing.expectEqual(@as(u32, 0), mock.reads.load(.acquire));

    // Materialize succeeds while unchanged.
    const bytes = try blob.materialize(a);
    defer a.free(bytes);
    try testing.expectEqualStrings("abcdefghij", bytes);
    try testing.expectEqual(@as(u32, 1), mock.reads.load(.acquire));

    // Snapshot modified -> NotReadableError.
    mock.state = .modified;
    try testing.expectError(error.NotReadableError, blob.materialize(a));

    // File deleted -> NotFoundError.
    mock.state = .missing;
    try testing.expectError(error.NotFoundError, blob.materialize(a));

    // Token still held until blob.deinit().
    try testing.expectEqual(@as(u32, 0), mock.releases.load(.acquire));
    blob.deinit();
    try testing.expectEqual(@as(u32, 1), mock.releases.load(.acquire));
}

test "0-byte file-backed BlobData still probes snapshot on materialize and readRange" {
    const a = testing.allocator;
    var mock: MockFile = .{ .bytes = "" };
    const backing = try file.FileBacking.init(a, &mock, &MockFile.ops, 0, 100);
    const blob = try file.BlobData.initFile(a, backing, "");
    backing.release();
    defer blob.deinit();

    // Unchanged 0-byte file reads as empty.
    const ok_bytes = try blob.materialize(a);
    defer a.free(ok_bytes);
    try testing.expectEqual(@as(usize, 0), ok_bytes.len);
    try testing.expectEqual(@as(u32, 1), mock.reads.load(.acquire));

    // Deleted 0-byte file -> NotFoundError on both materialize and readRange.
    mock.state = .missing;
    try testing.expectError(error.NotFoundError, blob.materialize(a));
    try testing.expectError(error.NotFoundError, blob.readRange(a, 0, 64));

    // Modified 0-byte file -> NotReadableError on both materialize and readRange.
    mock.state = .modified;
    try testing.expectError(error.NotReadableError, blob.materialize(a));
    try testing.expectError(error.NotReadableError, blob.readRange(a, 0, 64));
}

test "sliceBlob and processBlobPartsToData keep lazy file ranges without reading disk" {
    const a = testing.allocator;
    var mock: MockFile = .{ .bytes = "0123456789" };
    const backing = try file.FileBacking.init(a, &mock, &MockFile.ops, 10, 500);
    const base = try file.BlobData.initFile(a, backing, "text/plain");
    backing.release();

    const slice1 = try file.algorithms.sliceBlob(a, base, 2, 7, "application/octet-stream");
    const composed = try file.algorithms.processBlobPartsToData(a, &.{
        .{ .string = "<<" },
        .{ .blob = slice1 },
        .{ .buffer = ">>" },
    }, .{}, "text/plain");
    const composed_slice = try file.algorithms.sliceBlob(a, composed, 1, 8, null);
    const memory_only_slice = try file.algorithms.sliceBlob(a, composed, 0, 2, null);

    // Zero reads up to this point!
    try testing.expectEqual(@as(u32, 0), mock.reads.load(.acquire));
    try testing.expectEqual(@as(u64, 5), slice1.size());
    try testing.expectEqual(@as(u64, 9), composed.size());
    try testing.expectEqual(@as(u64, 7), composed_slice.size());
    try testing.expect(memory_only_slice.isMemoryOnly());
    try testing.expectEqualStrings("<<", memory_only_slice.memoryBytes().?);

    // Drop the original base blob: slice1, composed, composed_slice keep backing alive.
    base.deinit();
    try testing.expectEqual(@as(u32, 0), mock.releases.load(.acquire));

    const b1 = try slice1.materialize(a);
    defer a.free(b1);
    try testing.expectEqualStrings("23456", b1);

    const b2 = try composed.materialize(a);
    defer a.free(b2);
    try testing.expectEqualStrings("<<23456>>", b2);

    const b3 = try composed_slice.materialize(a);
    defer a.free(b3);
    try testing.expectEqualStrings("<23456>", b3);

    // Chunked readRange across memory + file + memory boundaries.
    const r1 = try composed.readRange(a, 0, 4);
    defer a.free(r1);
    try testing.expectEqualStrings("<<23", r1);
    const r2 = try composed.readRange(a, 4, 4);
    defer a.free(r2);
    try testing.expectEqualStrings("456>", r2);
    const r3 = try composed.readRange(a, 8, 4);
    defer a.free(r3);
    try testing.expectEqualStrings(">", r3);

    // Deleting underlying file causes subsequent reads on slice & composite to fail.
    mock.state = .missing;
    try testing.expectError(error.NotFoundError, slice1.materialize(a));
    try testing.expectError(error.NotFoundError, composed.materialize(a));
    try testing.expectError(error.NotFoundError, composed_slice.readRange(a, 0, 4));

    memory_only_slice.deinit();
    composed_slice.deinit();
    composed.deinit();
    try testing.expectEqual(@as(u32, 0), mock.releases.load(.acquire));
    slice1.deinit();
    try testing.expectEqual(@as(u32, 1), mock.releases.load(.acquire));
}

test "BlobURLStore captured entry fails with ReadFailed when file backing is gone or modified" {
    const a = testing.allocator;
    var store = file.BlobURLStore.init(a);
    defer store.deinit();

    var mock: MockFile = .{ .bytes = "url-payload" };
    const backing = try file.FileBacking.init(a, &mock, &MockFile.ops, 11, 777);
    const blob = try file.BlobData.initFile(a, backing, "text/plain");
    backing.release();

    const key = "https://example.test https://example.test 0";
    const url = try store.createObjectURL(blob, key, null);
    defer a.free(url);
    blob.deinit();

    // No read at createObjectURL time.
    try testing.expectEqual(@as(u32, 0), mock.reads.load(.acquire));

    const entry = store.capture(url) orelse return error.TestExpectedEntry;
    defer entry.release();

    const ok_data = try entry.read(a, .{ .environment = key });
    defer ok_data.deinit(a);
    try testing.expectEqualStrings("url-payload", ok_data.bytes);
    try testing.expectEqualStrings("text/plain", ok_data.content_type);

    mock.state = .missing;
    try testing.expectError(error.ReadFailed, entry.read(a, .{ .environment = key }));

    mock.state = .modified;
    try testing.expectError(error.ReadFailed, entry.read(a, .{ .environment = key }));

    store.revokeObjectURL(url, key);
    try testing.expectEqual(@as(u32, 0), mock.releases.load(.acquire));
    // Releasing `entry` in defer drops the final ref -> releases FileBacking once.
}

test "multi-threaded FileBacking retain/release releases token exactly once" {
    const a = testing.allocator;
    var mock: MockFile = .{ .bytes = "threaded" };
    const backing = try file.FileBacking.init(a, &mock, &MockFile.ops, 8, 999);
    const blob = try file.BlobData.initFile(a, backing, "application/octet-stream");
    backing.release();

    const Worker = struct {
        fn run(shared: *file.BlobData) void {
            defer shared.deinit();
            var i: usize = 0;
            while (i < 32) : (i += 1) {
                const extra = shared.retain();
                extra.deinit();
            }
        }
    };

    var threads: [4]std.Thread = undefined;
    for (&threads) |*t| {
        t.* = try std.Thread.spawn(.{}, Worker.run, .{blob.retain()});
    }
    blob.deinit();
    for (threads) |t| t.join();
    try testing.expectEqual(@as(u32, 1), mock.releases.load(.acquire));
}
