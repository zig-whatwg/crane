//! FileAPI "process blob parts" for a JavaScript `sequence<BlobPart>`: the
//! first step of both the Blob and the File constructor. A shared step, so it
//! lives here rather than in Blob's impl (AGENTS.md, the impls boundary rule
//! 3; impls batch 7): it converts each part with the engine protocol and reads
//! a Blob part's bytes through Blob's own step (dom.blob_bytes).
//!
//! Spec: https://w3c.github.io/FileAPI/#process-blob-parts

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const file = @import("file");
const blob_bytes = @import("blob_bytes.zig");

/// The `endings` member of BlobPropertyBag, as "process blob parts" takes it.
pub const Endings = file.algorithms.Endings;

/// FileAPI "process blob parts" for a JS `sequence<BlobPart>`: `parts`
/// converted to the IDL sequence (WebIDL 3.2.21), each item to the union
/// (Blob or BufferSource or USVString) (3.2.24), then their bytes in order,
/// a string's line endings converted when `endings` is native
/// (file.algorithms.processBlobParts). Shared by the Blob and File
/// constructors, whose first step it is. Missing parts are no bytes.
///
/// OWNED by `realm.allocator` when non-empty; an empty result allocates
/// nothing.
pub fn process(realm: runtime.Context, parts: ?runtime.JSValue, endings: Endings) ![]const u8 {
    const value = parts orelse return "";
    var converted: BlobPartSequence = .{ .realm = realm, .allocator = realm.allocator };
    defer converted.deinit();
    // 3.2.21: not an Object (step 1), or one with no @@iterator (step 3),
    // is a TypeError.
    if (!try engine.iterate(realm, value, BlobPartSequence.each, &converted)) return error.TypeError;
    const bytes = try file.algorithms.processBlobParts(realm.allocator, converted.parts.items, .{ .endings = endings });
    if (bytes.len == 0) {
        realm.allocator.free(bytes);
        return "";
    }
    return bytes;
}

/// A `sequence<BlobPart>` as it is converted, item by item: every part's
/// bytes are copied, as a later item's conversion runs script that can drop
/// the last reference to an earlier Blob or detach an earlier buffer.
const BlobPartSequence = struct {
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    parts: std.ArrayListUnmanaged(file.algorithms.BlobPart) = .empty,

    fn deinit(self: *BlobPartSequence) void {
        for (self.parts.items) |part| switch (part) {
            .blob => {},
            .buffer => |bytes| self.allocator.free(bytes),
            .string => |text| self.allocator.free(text),
        };
        self.parts.deinit(self.allocator);
    }

    fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
        const self: *BlobPartSequence = @ptrCast(@alignCast(data.?));
        try self.parts.ensureUnusedCapacity(self.allocator, 1);
        self.parts.appendAssumeCapacity(try convertBlobPart(self.realm, item, self.allocator));
    }
};

/// WebIDL 3.2.24, converting `item` to (Blob or BufferSource or USVString).
/// OWNED by `allocator`.
fn convertBlobPart(realm: runtime.Context, item: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!file.algorithms.BlobPart {
    // 4. A platform object that implements Blob is the Blob: its bytes. Any
    //    other platform object is no member here but the string (12).
    if (engine.convertToPlatformObject(realm, item)) |object| {
        if (object.stateAs(interfaces.Blob.State) != null) {
            // Its bytes, borrowed through Blob's step (none yet: empty).
            const bytes: []const u8 = blob_bytes.bytesOf(object) orelse "";
            return .{ .buffer = try allocator.dupe(u8, bytes) };
        }
    }
    // 5-9. An ArrayBuffer or ArrayBufferView: a copy of the bytes it holds
    //      (a view on a shared buffer is a TypeError - BufferSource is not
    //      [AllowShared]).
    if (try engine.getCopyOfBufferSourceBytes(realm, item, allocator)) |bytes| return .{ .buffer = bytes };
    // 12. Anything else is the USVString it converts to, as UTF-8.
    return .{ .string = try engine.convertToUSVString(realm, item, allocator) };
}
