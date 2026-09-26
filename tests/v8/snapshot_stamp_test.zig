//! Every snapshot blob the generator writes carries a build stamp - a magic
//! and its external-reference count - and the loader refuses a blob without
//! one, or with another count.
//!
//! V8 resolves each callback in a snapshot by its index in the embedder's
//! external-reference table. A blob restored against another build's table
//! wires callbacks to whatever sits at those indices now, and nothing in V8
//! notices: a January snapshot tracked in git was restored by every run from
//! the repo root for nine months (docs/lessons/
//! debugging-a-tracked-build-artifact-shadows-the-build.md).

const std = @import("std");
const v8 = @import("v8");
const loader = v8.snapshot_loader;

test "a stamped blob splits back into the blob and its count" {
    var buffer: [4 + loader.stamp_len]u8 = undefined;
    @memcpy(buffer[0..4], "blob");
    loader.writeStamp(buffer[4..][0..loader.stamp_len], 11506);

    const split = loader.splitStamp(&buffer) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("blob", split.blob);
    try std.testing.expectEqual(@as(u64, 11506), split.reference_count);
}

test "a blob with no stamp is refused, not guessed at" {
    // What the January file looks like: V8's bytes and nothing after them.
    try std.testing.expect(loader.splitStamp("a snapshot from another build") == null);
    try std.testing.expect(loader.splitStamp("") == null);
    try std.testing.expect(loader.splitStamp("CRANESNP") == null);
}

test "only the reference count the runtime registered is accepted" {
    try std.testing.expect(loader.stampMatches(.{ .blob = "", .reference_count = 11506 }, 11506));
    try std.testing.expect(!loader.stampMatches(.{ .blob = "", .reference_count = 11168 }, 11506));
}
