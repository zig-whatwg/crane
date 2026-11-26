//! FileAPI "process blob parts" for a JavaScript `sequence<BlobPart>`: the
//! first step of both the Blob and the File constructor. A shared step, so it
//! lives here rather than in Blob's impl (AGENTS.md, the impls boundary rule
//! 3; impls batch 7): it converts each part with the engine protocol and
//! retains a Blob part's `BlobData` through Blob's own step (dom.blob_bytes),
//! so file-backed parts stay lazy without disk I/O at construction time.
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

/// FileAPI "process blob parts" for a JS `sequence<BlobPart>` returning a new
/// `*file.BlobData` with `mime_type` (constructor-normalized).
///
/// File-backed Blob parts are retained lazily in a `.parts` `BlobData` (Blink
/// `BlobData` parts model, zero disk reads at construction); pure in-memory
/// inputs stay on the `.memory` fast path.
pub fn processToData(realm: runtime.Context, parts: ?runtime.JSValue, endings: Endings, mime_type: []const u8) !*file.BlobData {
    const value = parts orelse return file.BlobData.init(realm.allocator, "", mime_type);
    var converted: BlobPartSequence = .{ .realm = realm, .allocator = realm.allocator };
    defer converted.deinit();
    // 3.2.21: not an Object (step 1), or one with no @@iterator (step 3),
    // is a TypeError.
    if (!try engine.iterate(realm, value, BlobPartSequence.each, &converted)) return error.TypeError;
    return file.algorithms.processBlobPartsToData(realm.allocator, converted.parts.items, .{ .endings = endings }, mime_type);
}

/// A `sequence<BlobPart>` as it is converted, item by item: buffer and string
/// parts are copied and Blob parts retain their `*file.BlobData`, as a later
/// item's conversion runs script that can drop the last reference to an
/// earlier Blob or detach an earlier buffer.
const BlobPartSequence = struct {
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    parts: std.ArrayListUnmanaged(file.algorithms.BlobPart) = .empty,

    fn deinit(self: *BlobPartSequence) void {
        for (self.parts.items) |part| switch (part) {
            .blob => |data| @constCast(data).deinit(),
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
/// OWNED by `allocator` (or retained `*BlobData` released in `deinit`).
fn convertBlobPart(realm: runtime.Context, item: runtime.JSValue, allocator: std.mem.Allocator) engine.Error!file.algorithms.BlobPart {
    // 4. A platform object that implements Blob is the Blob: its BlobData
    //    (retained, so file-backed Blobs stay lazy without reading disk). Any
    //    other platform object is no member here but the string (12).
    if (engine.convertToPlatformObject(realm, item)) |object| {
        if (object.stateAs(interfaces.Blob.State) != null) {
            if (blob_bytes.dataOf(object)) |data| {
                return .{ .blob = data.retain() };
            }
            return .{ .buffer = try allocator.alloc(u8, 0) };
        }
    }
    // 5-9. An ArrayBuffer or ArrayBufferView: a copy of the bytes it holds
    //      (a view on a shared buffer is a TypeError - BufferSource is not
    //      [AllowShared]).
    if (try engine.getCopyOfBufferSourceBytes(realm, item, allocator)) |bytes| return .{ .buffer = bytes };
    // 12. Anything else is the USVString it converts to, as UTF-8.
    return .{ .string = try engine.convertToUSVString(realm, item, allocator) };
}
