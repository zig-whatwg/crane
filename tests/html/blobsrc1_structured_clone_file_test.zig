//! Structured clone (html_core walker) file-backed File/Blob reference,
//! snapshot metadata, and webkitRelativePath preservation (lane blobsrc1).

const std = @import("std");
const testing = std.testing;
const structured_clone = @import("html_core").structured_clone;

const FakeRef = struct {
    refs: i32 = 1,

    fn retain(ctx: *anyopaque) void {
        const self: *FakeRef = @ptrCast(@alignCast(ctx));
        self.refs += 1;
    }

    fn release(ctx: *anyopaque) void {
        const self: *FakeRef = @ptrCast(@alignCast(ctx));
        self.refs -= 1;
    }

    fn asFileRef(self: *FakeRef, size: u64, mtime: i64) structured_clone.types.FileRef {
        return .{
            .ctx = self,
            .retain_fn = &retain,
            .release_fn = &release,
            .snapshot_size = size,
            .snapshot_modified_ns = mtime,
        };
    }
};

test "structured clone of file-backed File keeps file_ref, snapshot, and webkitRelativePath without reading" {
    const a = testing.allocator;
    var ref: FakeRef = .{};
    const orig: structured_clone.JSValue = .{
        .file = .{
            .name = "leaf.txt",
            .content_type = "text/plain",
            .last_modified = 1700000000000,
            .webkit_relative_path = "dir/sub/leaf.txt",
            .file_ref = ref.asFileRef(42, 1700000000000000000),
        },
    };
    const serialized = try structured_clone.structuredSerialize(a, &orig);
    try testing.expectEqual(@as(i32, 2), ref.refs);

    const cloned = try structured_clone.structuredDeserialize(a, serialized);
    try testing.expectEqual(@as(i32, 3), ref.refs);

    // Release serialized record: cloned still holds its own ref.
    serialized.deinit();
    a.destroy(serialized);
    try testing.expectEqual(@as(i32, 2), ref.refs);

    try testing.expectEqualStrings("leaf.txt", cloned.file.name);
    try testing.expectEqualStrings("text/plain", cloned.file.content_type);
    try testing.expectEqual(@as(i64, 1700000000000), cloned.file.last_modified);
    try testing.expectEqualStrings("dir/sub/leaf.txt", cloned.file.webkit_relative_path);
    try testing.expect(cloned.file.file_ref != null);
    try testing.expectEqual(@as(u64, 42), cloned.file.file_ref.?.snapshot_size);
    try testing.expectEqual(@as(i64, 1700000000000000000), cloned.file.file_ref.?.snapshot_modified_ns);

    structured_clone.deserialize.freeJSValue(a, cloned);
    try testing.expectEqual(@as(i32, 1), ref.refs);
}
