//! IndexedDB serialization of file-backed Blobs/Files (lane blobsrc1):
//! - Stores bytes at put time and preserves webkitRelativePath through Codec
//! - Fails with UnknownError when reading a missing or modified backing file

const std = @import("std");
const testing = std.testing;
const idb = @import("storage").indexeddb;
const ser = idb.serialization;

const MockReader = struct {
    bytes: []const u8 = "stored-bytes",
    fail: ?error{ NotFoundError, NotReadableError } = null,

    fn read(ctx: *anyopaque, allocator: std.mem.Allocator) error{ NotFoundError, NotReadableError, OutOfMemory }![]u8 {
        const self: *MockReader = @ptrCast(@alignCast(ctx));
        if (self.fail) |err| return err;
        return allocator.dupe(u8, self.bytes);
    }

    fn reader(self: *MockReader) ser.FileByteReader {
        return .{ .ctx = self, .read_fn = &read };
    }
};

test "IndexedDB File serialization stores bytes, preserves webkitRelativePath, and fails with UnknownError on read error" {
    const a = testing.allocator;
    var serializer = ser.Serializer.init(a, true);
    defer serializer.deinit();

    var mock: MockReader = .{ .bytes = "leaf-payload" };
    var val = try serializer.serializeFileFromReader("leaf.txt", "text/plain", 1700000000000, "dir/sub/leaf.txt", mock.reader());
    defer val.deinit();

    const encoded = try ser.BinaryFormat.encode(a, val);
    defer a.free(encoded);

    var decoded = try ser.BinaryFormat.decode(a, encoded);
    defer decoded.deinit();

    try testing.expectEqual(ser.SerializedType.file, decoded.type_tag);
    try testing.expectEqualStrings("leaf.txt", decoded.data.file.name);
    try testing.expectEqualStrings("text/plain", decoded.data.file.type);
    try testing.expectEqual(@as(i64, 1700000000000), decoded.data.file.last_modified);
    try testing.expectEqualStrings("dir/sub/leaf.txt", decoded.data.file.webkit_relative_path);
    try testing.expectEqualStrings("leaf-payload", decoded.data.file.bytes);

    mock.fail = error.NotFoundError;
    try testing.expectError(error.UnknownError, serializer.serializeFileFromReader("gone.txt", "text/plain", 0, "", mock.reader()));

    mock.fail = error.NotReadableError;
    try testing.expectError(error.UnknownError, serializer.serializeBlobFromReader("text/plain", mock.reader()));
}
