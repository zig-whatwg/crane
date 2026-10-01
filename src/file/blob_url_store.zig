//! W3C File API - Blob URL Store
//!
//! This module implements the blob URL store for URL.createObjectURL()
//! and URL.revokeObjectURL() operations.
//!
//! Spec: https://www.w3.org/TR/FileAPI/#url
//!
//! ## Blob URL Format
//!
//! Blob URLs have the format: blob:<origin>/<uuid>
//! Example: blob:https://example.com/550e8400-e29b-41d4-a716-446655440000
//!
//! ## Store Semantics
//!
//! Per spec §8:
//! - Each origin has its own blob URL store
//! - URLs are valid only within the creating origin
//! - URLs are revoked when their entry is removed
//! - URLs can be revoked manually or when document unloads
//!
//! ## Thread Safety
//!
//! The store is designed for single-threaded access within an origin.
//! Cross-origin access is blocked by URL resolution.

const std = @import("std");
const clock = @import("clock");
/// getentropy(2). POSIX-ish: Linux 3.17+/glibc 2.25+, macOS 10.12+, the BSDs.
/// Returns 0 on success. Declared here because Zig 0.16's std.c does not expose it
/// and std.Io.random requires an Io value that is not available at these call sites.
extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;

const BlobData = @import("blob_internals.zig").BlobData;

/// Entry in the blob URL store.
pub const BlobURLEntry = struct {
    /// The blob's data: a reference of the entry's own (`BlobData.retain`),
    /// released when the entry leaves the store. The Blob object script made
    /// may be collected first.
    blob: *BlobData,

    /// The origin that created this URL
    origin: []const u8,

    /// The entry's environment: the settings object that was current when the
    /// URL was made, as an opaque key (the caller's realm), compared and never
    /// read. File API: when that environment goes - its document's unloading
    /// document cleanup steps, its worker's end - the entry is removed
    /// (`removeEntriesFor`). Null for an entry no environment owns.
    environment: ?*const anyopaque,

    /// Whether this entry is still valid
    valid: bool,
};

/// Global blob URL store.
///
/// Maps blob URLs to their associated Blob objects.
/// Per spec, each origin should have its own store, but for simplicity
/// we use a single store with origin validation.
pub const BlobURLStore = struct {
    /// Map from UUID string to blob entry
    entries: std.StringHashMap(BlobURLEntry),

    /// Memory allocator
    allocator: std.mem.Allocator,

    /// The generator for UUID generation. Held BY VALUE: a `std.Random` is only a
    /// `{ptr, fillFn}` view onto some generator's state, and this used to store a
    /// view of a generator that lived in `init`'s stack frame. Every UUID then
    /// wrote 32 bytes of xoshiro state into whichever frame had since reused that
    /// address - a return address, a saved register, a live local.
    prng: std.Random.DefaultPrng,

    /// Initialize a new blob URL store.
    pub fn init(allocator: std.mem.Allocator) BlobURLStore {
        const prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            // std.posix.getrandom was removed in Zig 0.16; the replacement is
            // std.Io.random, which needs an Io value this call site does not have.
            // getentropy(2) is the libc primitive underneath both and needs none.
            // Blob URLs must not be guessable, so the clock fallback below is a
            // last resort, not the normal path.
            if (getentropy(std.mem.asBytes(&seed).ptr, @sizeOf(u64)) != 0) {
                seed = @intCast(clock.wallMillis());
            }
            break :blk seed;
        });

        return .{
            .entries = std.StringHashMap(BlobURLEntry).init(allocator),
            .allocator = allocator,
            .prng = prng,
        };
    }

    /// Clean up all resources.
    pub fn deinit(self: *BlobURLStore) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            // Free the UUID key
            self.allocator.free(entry.key_ptr.*);
            // Free the origin
            if (entry.value_ptr.origin.len > 0) {
                self.allocator.free(@constCast(entry.value_ptr.origin));
            }
            // The entry's reference to its blob's data.
            entry.value_ptr.blob.deinit();
        }
        self.entries.deinit();
    }

    /// Create a new blob URL for the given blob.
    ///
    /// Per spec §8.3.1 (createObjectURL):
    /// 1. Generate a new UUID
    /// 2. Create blob URL: "blob:" + origin + "/" + uuid
    /// 3. Add entry to store
    /// 4. Return the URL
    ///
    /// Returns the full blob URL string (caller owns memory).
    /// Returns `[]u8`: the caller OWNS the returned URL and must free it. The store
    /// keeps `uuid` and `owned_origin`, not this string. The mutable slice says so in
    /// the type, which is what lets `DOMString.initOwned` accept it.
    pub fn createObjectURL(self: *BlobURLStore, blob: *BlobData, origin: []const u8, environment: ?*const anyopaque) ![]u8 {
        // Generate UUID
        const uuid = try self.generateUUID();
        errdefer self.allocator.free(uuid);

        // Create the full URL
        const url = try std.fmt.allocPrint(self.allocator, "blob:{s}/{s}", .{ origin, uuid });
        errdefer self.allocator.free(url);

        // Copy origin for storage
        const owned_origin = try self.allocator.dupe(u8, origin);
        errdefer self.allocator.free(owned_origin);

        // Store the entry. It holds the blob for as long as it is in the
        // store: a reference of its own, which revoking releases - taken
        // only once nothing below can fail.
        try self.entries.ensureUnusedCapacity(1);
        self.entries.putAssumeCapacity(uuid, .{
            .blob = blob.retain(),
            .origin = owned_origin,
            .environment = environment,
            .valid = true,
        });

        return url;
    }

    /// Revoke a blob URL.
    ///
    /// Per spec §8.3.2 (revokeObjectURL):
    /// 1. Parse the URL to extract UUID
    /// 2. If entry exists, mark it as invalid
    /// 3. Remove entry from store
    pub fn revokeObjectURL(self: *BlobURLStore, url: []const u8) void {
        // Extract UUID from URL (after last '/')
        const uuid = self.extractUUID(url) orelse return;

        self.removeEntry(uuid);
    }

    /// Remove every entry whose environment is `environment`, releasing each
    /// one's reference to its blob's data.
    ///
    /// File API, the unloading document cleanup steps it adds: "Let
    /// environment be the Document's relevant settings object. Let store be
    /// the user agent's blob URL store; remove from store any entries for
    /// which the value's environment is equal to environment." The same is
    /// run for a worker's global scope when it ends (the File API's own note:
    /// "This needs a similar hook when a worker is unloaded"; Blink's
    /// PublicURLManager::ContextDestroyed does both). An entry holds its
    /// blob's data, so one nothing removes keeps the data for as long as the
    /// store lives - the process, in a browser or a test runner that loads
    /// many pages.
    pub fn removeEntriesFor(self: *BlobURLStore, environment: *const anyopaque) void {
        var doomed: [16][]const u8 = undefined;
        while (true) {
            // Collected first, removed after: removing from a hash map while
            // iterating it is not allowed. Batches of 16, until none is left.
            var found: usize = 0;
            var it = self.entries.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.environment != environment) continue;
                doomed[found] = entry.key_ptr.*;
                found += 1;
                if (found == doomed.len) break;
            }
            if (found == 0) return;
            for (doomed[0..found]) |uuid| self.removeEntry(uuid);
        }
    }

    /// Remove the entry keyed by `uuid`: its key, its origin and its
    /// reference to its blob's data.
    fn removeEntry(self: *BlobURLStore, uuid: []const u8) void {
        const kv = self.entries.fetchRemove(uuid) orelse return;
        self.allocator.free(kv.key);
        if (kv.value.origin.len > 0) self.allocator.free(@constCast(kv.value.origin));
        // The entry's reference to its blob's data: the last one frees it
        // when the Blob object has already been collected.
        kv.value.blob.deinit();
    }

    /// Resolve a blob URL to its associated blob.
    ///
    /// Per spec §8.4:
    /// 1. Parse URL to extract UUID
    /// 2. Look up in store
    /// 3. Verify origin matches
    /// 4. Return blob if valid
    pub fn resolve(self: *BlobURLStore, url: []const u8, requesting_origin: []const u8) ?*BlobData {
        const uuid = self.extractUUID(url) orelse return null;

        const entry = self.entries.get(uuid) orelse return null;

        // Verify origin matches (same-origin policy)
        if (!std.mem.eql(u8, entry.origin, requesting_origin)) {
            return null;
        }

        if (!entry.valid) {
            return null;
        }

        return entry.blob;
    }

    /// Generate a random UUID v4.
    fn generateUUID(self: *BlobURLStore) ![]const u8 {
        var uuid_bytes: [16]u8 = undefined;
        self.prng.random().bytes(&uuid_bytes);

        // Set version (4) and variant (RFC 4122)
        uuid_bytes[6] = (uuid_bytes[6] & 0x0F) | 0x40;
        uuid_bytes[8] = (uuid_bytes[8] & 0x3F) | 0x80;

        // Format as string
        return std.fmt.allocPrint(
            self.allocator,
            "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}",
            .{
                uuid_bytes[0],  uuid_bytes[1],  uuid_bytes[2],  uuid_bytes[3],
                uuid_bytes[4],  uuid_bytes[5],  uuid_bytes[6],  uuid_bytes[7],
                uuid_bytes[8],  uuid_bytes[9],  uuid_bytes[10], uuid_bytes[11],
                uuid_bytes[12], uuid_bytes[13], uuid_bytes[14], uuid_bytes[15],
            },
        );
    }

    /// Extract the UUID from a blob URL.
    fn extractUUID(self: *BlobURLStore, url: []const u8) ?[]const u8 {
        _ = self;

        // URL format: blob:<origin>/<uuid>
        if (!std.mem.startsWith(u8, url, "blob:")) {
            return null;
        }

        // Find the last '/'
        const last_slash = std.mem.lastIndexOf(u8, url, "/") orelse return null;

        if (last_slash + 1 >= url.len) {
            return null;
        }

        return url[last_slash + 1 ..];
    }
};

test "BlobURLStore - createObjectURL and resolve" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const url = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url);

    try std.testing.expect(std.mem.startsWith(u8, url, "blob:https://example.com/"));

    // Should resolve from same origin
    const resolved = store.resolve(url, "https://example.com");
    try std.testing.expect(resolved != null);
    try std.testing.expectEqualStrings("Hello", resolved.?.bytes);

    // Should not resolve from different origin
    const cross_origin = store.resolve(url, "https://other.com");
    try std.testing.expect(cross_origin == null);
}

test "BlobURLStore - consecutive UUIDs differ" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    // The generator's state must persist from one call to the next, which
    // means it must live in the store. A view of a generator that lived in
    // init's stack frame reads whatever the current call chain has put at
    // that dead address - the same bytes each time - and writes its state
    // over it.
    var uuids: [8][]const u8 = undefined;
    for (&uuids) |*uuid| uuid.* = try store.generateUUID();
    defer for (uuids) |uuid| allocator.free(uuid);

    for (uuids[1..], uuids[0 .. uuids.len - 1]) |uuid, previous| {
        try std.testing.expect(!std.mem.eql(u8, previous, uuid));
    }
}

test "BlobURLStore - revokeObjectURL" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "Hello", "text/plain");
    defer blob.deinit();

    const url = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url);

    // Should resolve before revocation
    try std.testing.expect(store.resolve(url, "https://example.com") != null);

    // Revoke
    store.revokeObjectURL(url);

    // Should not resolve after revocation
    try std.testing.expect(store.resolve(url, "https://example.com") == null);
}

/// std.testing.allocator, except that freed memory reads back as 0xAA in
/// every build mode - so a test that reads through a dangling pointer sees
/// garbage rather than the bytes that happened to stay behind.
const PoisoningAllocator = struct {
    child: std.mem.Allocator,

    fn allocator(self: *PoisoningAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *PoisoningAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawAlloc(len, alignment, ret_addr);
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *PoisoningAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(memory, alignment, new_len, ret_addr);
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *PoisoningAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(memory, alignment, new_len, ret_addr);
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *PoisoningAllocator = @ptrCast(@alignCast(ctx));
        @memset(memory, 0xAA);
        self.child.rawFree(memory, alignment, ret_addr);
    }
};

test "BlobURLStore - an entry holds its blob after the Blob lets go of it" {
    // File API "blob URL entry": its object is the Blob, held by the entry for
    // as long as the entry is in the store. Script routinely drops the Blob
    // and keeps only the URL (URL.createObjectURL(new Blob([...]))), so the
    // collector frees the Blob object - and with it the Blob's reference to
    // its data - while the URL can still be fetched or imported. The entry's
    // own reference is what the fetch reads then (a worker's import() of such
    // a URL read freed memory in scheme fetch "blob" before the entry held
    // one).
    var poisoning: PoisoningAllocator = .{ .child = std.testing.allocator };
    const allocator = poisoning.allocator();

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const source = "export const foo = \"bar\";";
    const blob = try BlobData.init(allocator, source, "text/javascript");
    const url = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url);

    // The Blob object is collected: its reference goes.
    blob.deinit();

    const resolved = store.resolve(url, "https://example.com") orelse return error.TestExpectedEntry;
    try std.testing.expectEqual(source.len, resolved.bytes.len);
    try std.testing.expectEqualStrings(source, resolved.bytes);
    try std.testing.expectEqualStrings("text/javascript", resolved.mime_type);

    // Revoking drops the entry's reference, the last one: the data is freed
    // (std.testing.allocator fails the test on a leak).
    store.revokeObjectURL(url);
    try std.testing.expect(store.resolve(url, "https://example.com") == null);
}

test "BlobURLStore - deinit releases the entries it still holds" {
    var poisoning: PoisoningAllocator = .{ .child = std.testing.allocator };
    const allocator = poisoning.allocator();

    var store = BlobURLStore.init(allocator);
    const blob = try BlobData.init(allocator, "kept", "text/plain");
    const url = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url);
    blob.deinit();

    // Never revoked: the store's teardown releases the last reference
    // (std.testing.allocator fails the test on a leak).
    store.deinit();
}

test "BlobURLStore - two URLs for one blob hold it independently" {
    var poisoning: PoisoningAllocator = .{ .child = std.testing.allocator };
    const allocator = poisoning.allocator();

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "shared", "text/plain");
    const url1 = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url1);
    const url2 = try store.createObjectURL(blob, "https://example.com", null);
    defer allocator.free(url2);
    blob.deinit();

    store.revokeObjectURL(url1);
    const resolved = store.resolve(url2, "https://example.com") orelse return error.TestExpectedEntry;
    try std.testing.expectEqual(@as(usize, 6), resolved.bytes.len);
    try std.testing.expectEqualStrings("shared", resolved.bytes);
    store.revokeObjectURL(url2);
}

test "BlobURLStore - an environment's entries go when it ends, and no one else's" {
    // File API: the unloading document cleanup steps "remove from store any
    // entries for which the value's environment is equal to" the document's
    // relevant settings object. An entry holds its blob's data, so an entry
    // nothing removes keeps the data for as long as the store lives - every
    // page that made a URL and never revoked it, for the life of the process.
    var poisoning: PoisoningAllocator = .{ .child = std.testing.allocator };
    const allocator = poisoning.allocator();
    var page_a: u8 = 0;
    var page_b: u8 = 0;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "page data", "text/plain");
    const url_a1 = try store.createObjectURL(blob, "https://example.com", &page_a);
    defer allocator.free(url_a1);
    const url_a2 = try store.createObjectURL(blob, "https://example.com", &page_a);
    defer allocator.free(url_a2);
    const url_b = try store.createObjectURL(blob, "https://example.com", &page_b);
    defer allocator.free(url_b);
    blob.deinit();

    store.removeEntriesFor(&page_a);
    try std.testing.expect(store.resolve(url_a1, "https://example.com") == null);
    try std.testing.expect(store.resolve(url_a2, "https://example.com") == null);
    const kept = store.resolve(url_b, "https://example.com") orelse return error.TestExpectedEntry;
    try std.testing.expectEqualStrings("page data", kept.bytes);

    // The last entry's end frees the data (std.testing.allocator fails the
    // test on a leak or a second free).
    store.removeEntriesFor(&page_b);
    try std.testing.expect(store.resolve(url_b, "https://example.com") == null);
    try std.testing.expectEqual(@as(usize, 0), store.entries.count());
}

test "BlobURLStore - a URL revoked before its environment ends is released once" {
    var poisoning: PoisoningAllocator = .{ .child = std.testing.allocator };
    const allocator = poisoning.allocator();
    var page: u8 = 0;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    const blob = try BlobData.init(allocator, "revoked first", "text/plain");
    const revoked = try store.createObjectURL(blob, "https://example.com", &page);
    defer allocator.free(revoked);
    const live = try store.createObjectURL(blob, "https://example.com", &page);
    defer allocator.free(live);
    blob.deinit();

    // Revoking works as it always has: that URL is gone, the other resolves.
    store.revokeObjectURL(revoked);
    try std.testing.expect(store.resolve(revoked, "https://example.com") == null);
    try std.testing.expect(store.resolve(live, "https://example.com") != null);

    // The environment's end then takes only what is left.
    store.removeEntriesFor(&page);
    try std.testing.expect(store.resolve(live, "https://example.com") == null);
    try std.testing.expectEqual(@as(usize, 0), store.entries.count());

    // An environment with no entries left, or none ever, is a no-op.
    store.removeEntriesFor(&page);
}

test "BlobURLStore - invalid URL" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    // Should return null for invalid URLs
    try std.testing.expect(store.resolve("not-a-blob-url", "https://example.com") == null);
    try std.testing.expect(store.resolve("blob:", "https://example.com") == null);
    try std.testing.expect(store.resolve("blob:https://example.com/", "https://example.com") == null);
}
