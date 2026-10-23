//! Blob URL Support
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#concept-url-blob-entry
//! File API: https://w3c.github.io/FileAPI/#blob-url-entry
//! Spec Reference: Lines 819-821, 1025, 1602
//!
//! Blob URLs are special URLs that refer to Blob objects. The actual blob URL
//! store and resolution logic is defined in the File API specification, not
//! the URL Standard: the store is the file module's (file.BlobURLStore, one
//! per Browser). This module gives the URL record its blob URL entry type.
//! (Its second, process-wide store - a resolver hook nothing installed or
//! called - was deleted with instances B3.)

const std = @import("std");
const Origin = @import("origin").Origin;

/// File API 8.2: the entry belongs to a parsed URL, even after its store
/// mapping is revoked. Each URL/request and the store owns a reference.
/// The immutable payload is owned through file's callbacks, never through
/// a realm or a platform object. References may cross worker threads.
pub const BlobURLEntry = struct {
    allocator: std.mem.Allocator,
    refs: std.atomic.Value(u32) = .init(1),
    storage_key: []const u8,
    /// A slice of storage_key; public serialization remains "null".
    origin: []const u8,
    origin_nonce: ?u128,
    payload: *anyopaque,
    operations: Operations,

    pub const Access = union(enum) {
        environment: []const u8,
        top_level_navigation,
        top_level_self_fetch,
    };

    pub const Data = struct {
        bytes: []u8,
        content_type: []u8,

        pub fn deinit(self: Data, allocator: std.mem.Allocator) void {
            allocator.free(self.bytes);
            allocator.free(self.content_type);
        }
    };

    pub const Operations = struct {
        retain: *const fn (*anyopaque) void,
        release: *const fn (*anyopaque) void,
        read: *const fn (*anyopaque, std.mem.Allocator) error{OutOfMemory}!Data,
    };

    pub fn create(allocator: std.mem.Allocator, storage_key: []const u8, origin_nonce: ?u128, payload: *anyopaque, operations: Operations) error{OutOfMemory}!*BlobURLEntry {
        const entry = try allocator.create(BlobURLEntry);
        errdefer allocator.destroy(entry);
        const key = try allocator.dupe(u8, storage_key);
        entry.* = .{
            .allocator = allocator,
            .storage_key = key,
            .origin = key[0 .. std.mem.indexOfScalar(u8, key, ' ') orelse key.len],
            .origin_nonce = origin_nonce,
            .payload = payload,
            .operations = operations,
        };
        operations.retain(payload);
        return entry;
    }

    pub fn retain(self: *BlobURLEntry) *BlobURLEntry {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *BlobURLEntry) void {
        const previous = self.refs.fetchSub(1, .release);
        std.debug.assert(previous > 0);
        if (previous != 1) return;
        _ = self.refs.load(.acquire);
        self.operations.release(self.payload);
        self.allocator.free(self.storage_key);
        self.allocator.destroy(self);
    }

    /// File API "obtain a blob object": authorize when obtaining bytes,
    /// not when parsing the URL. Capturing a URL grants no access by itself.
    pub fn read(self: *const BlobURLEntry, allocator: std.mem.Allocator, access: Access) error{ OutOfMemory, WrongPartition }!Data {
        switch (access) {
            .environment => |key| {
                if (!std.mem.eql(u8, key, self.storage_key)) return error.WrongPartition;
                if (std.mem.eql(u8, self.origin, "null") and self.origin_nonce == null) return error.WrongPartition;
                var parts = std.mem.splitScalar(u8, self.storage_key, ' ');
                _ = parts.next();
                if (parts.next()) |site| if (std.mem.eql(u8, site, "null")) {
                    _ = parts.next();
                    _ = parts.next();
                    const nonce = parts.next() orelse return error.WrongPartition;
                    if (std.mem.eql(u8, nonce, "-") or std.mem.eql(u8, nonce, "0")) return error.WrongPartition;
                };
            },
            .top_level_navigation, .top_level_self_fetch => {},
        }
        return self.operations.read(self.payload, allocator);
    }

    /// URL "origin", blob step 1: the captured entry's environment origin.
    pub fn getOrigin(self: *const BlobURLEntry, allocator: std.mem.Allocator) error{ OutOfMemory, InvalidOrigin }!Origin {
        if (std.mem.eql(u8, self.origin, "null")) return .{ .opaque_origin = {} };
        var url = @import("api_url_parser").parseURL(allocator, self.origin, null) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidOrigin,
        };
        defer url.deinit();
        return @import("origin").getOrigin(allocator, &url) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidOrigin,
        };
    }
};
