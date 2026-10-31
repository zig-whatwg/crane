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
//! - One store for the user agent - here, for each Browser
//! - A blob URL is used only from an environment whose storage key equals its
//!   creator's (File API 8.3.2): the same origin, under the same top-level
//!   site, with the same has-cross-site-ancestor bit - except by a top-level
//!   navigation or a top-level self-fetch
//! - URLs are revoked when their entry is removed
//! - URLs can be revoked manually or when document unloads
//!
//! ## Thread Safety
//!
//! One store per Browser, reached from its window thread and its workers'
//! threads: every method locks it (see `BlobURLStore`). Cross-origin access
//! is blocked by URL resolution.

const std = @import("std");
const clock = @import("clock");
/// getentropy(2). POSIX-ish: Linux 3.17+/glibc 2.25+, macOS 10.12+, the BSDs.
/// Returns 0 on success. Declared here because Zig 0.16's std.c does not expose it
/// and std.Io.random requires an Io value that is not available at these call sites.
extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;

const BlobData = @import("blob_internals.zig").BlobData;
const CapturedEntry = @import("blob_url").BlobURLEntry;

/// Entry in the blob URL store.
pub const BlobURLEntry = struct {
    /// Owns the immutable payload and key. The fields below borrow them.
    captured: *CapturedEntry,
    /// The blob's data: a reference of the entry's own (`BlobData.retain`),
    /// released when the entry leaves the store. The Blob object script made
    /// may be collected first.
    blob: *BlobData,

    /// The storage key for non-storage purposes of the environment that
    /// created this URL, serialized (`BlobURLStore`'s doc). OWNED.
    storage_key: []const u8,

    /// The origin that created this URL: the key's origin part, a slice of
    /// `storage_key`.
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

/// The user agent's blob URL store (File API 8.1: "The user agent must
/// maintain a blob URL store").
///
/// Maps blob URLs to their associated Blob objects.
/// Per spec, each origin should have its own store, but for simplicity
/// we use a single store with origin validation.
///
/// One per Browser: a supplement of its scope (runtime.BrowserScope - `init`
/// and `deinit` are the supplement's), which every realm of the Browser
/// reaches (dom.browser_state.blobURLStoreOf), and which ends with the
/// Browser, releasing every entry still in it. A blob URL made in one Browser
/// resolves in no other Browser of the process.
///
/// Every thread of a Browser reaches it (a page makes a URL, its worker
/// fetches it - docs/instances.md), so every method takes `mutex`, and
/// `resolve` hands out a reference of the caller's own, which a revoke on
/// another thread cannot free under it.
///
/// Storage keys arrive serialized ("<origin> <top-level site> <0|1>",
/// storage.StorageKey.serialize - this module does not import storage): the
/// form is canonical, so equal keys are equal bytes, and the origin is the
/// text before the first space.
pub const BlobURLStore = struct {
    /// Protects `entries` and `prng`; held for one store operation, never
    /// across a call out of this file.
    mutex: std.Io.Mutex = .init,

    /// Map from UUID string to blob entry
    entries: std.StringHashMap(BlobURLEntry),

    /// Under `mutex`: bounds `entries`' tombstones. The store is its
    /// Browser's, alive for every page, and each URL is a fresh UUID that
    /// leaves at its revoke or its page's end, so std's map never grows and
    /// kept every removal's tombstone (src/infra/tombstones.zig). Entries
    /// are read by copy, and `removeEntriesFor` collects before it removes.
    guard: @import("infra").tombstones.TombstoneGuard = .{},

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
            entry.value_ptr.captured.release();
        }
        self.entries.deinit();
    }

    /// Who asks for a blob URL's blob: File API "obtain a blob object"'s
    /// environment, or one of the two strings it takes instead.
    pub const Access = union(enum) {
        /// An environment, by its storage key for non-storage purposes,
        /// serialized: File API 8.3.2 "check for same-partition blob URL
        /// usage" lets it obtain only an entry made under an equal key.
        environment: []const u8,
        /// "top-level-navigation" (Fetch scheme fetch "blob" step 6.1: the
        /// request's destination is "document"): not checked.
        top_level_navigation,
        /// "top-level-self-fetch" (step 6.2: a top-level Window fetching its
        /// own creation URL): not checked.
        top_level_self_fetch,
    };

    /// Create a new blob URL for the given blob.
    ///
    /// Per spec §8.3.1 (createObjectURL):
    /// 1. Generate a new UUID
    /// 2. Create blob URL: "blob:" + origin + "/" + uuid
    /// 3. Add entry to store
    /// 4. Return the URL
    ///
    /// `storage_key` is the current settings object's storage key for
    /// non-storage purposes, serialized; its origin part is the URL's.
    ///
    /// Returns the full blob URL string (caller owns memory).
    /// Returns `[]u8`: the caller OWNS the returned URL and must free it. The store
    /// keeps `uuid` and its copy of the key, not this string. The mutable slice says so in
    /// the type, which is what lets `DOMString.initOwned` accept it.
    pub fn createObjectURL(self: *BlobURLStore, blob: *BlobData, storage_key: []const u8, environment: ?*const anyopaque) ![]u8 {
        return self.createObjectURLWithOrigin(blob, storage_key, null, environment);
    }

    /// The settings object's opaque origin crosses threads only as a value.
    /// The existing native API keeps its unknown-identity default.
    pub fn createObjectURLWithOrigin(self: *BlobURLStore, blob: *BlobData, storage_key: []const u8, origin_nonce: ?u128, environment: ?*const anyopaque) ![]u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const origin = originOfKey(storage_key);

        // Generate UUID
        const uuid = try self.generateUUID();
        errdefer self.allocator.free(uuid);

        // Create the full URL
        const url = try std.fmt.allocPrint(self.allocator, "blob:{s}/{s}", .{ origin, uuid });
        errdefer self.allocator.free(url);

        const captured = try CapturedEntry.create(self.allocator, storage_key, origin_nonce, blob, .{
            .retain = &retainPayload,
            .release = &releasePayload,
            .read = &readPayload,
        });
        errdefer captured.release();

        // Store the entry. It holds the blob for as long as it is in the
        // store: a reference of its own, which revoking releases - taken
        // only once nothing below can fail.
        try self.entries.ensureUnusedCapacity(1);
        // A rehash keeps the capacity just ensured.
        self.guard.beforeInsert(&self.entries);
        self.entries.putAssumeCapacity(uuid, .{
            .captured = captured,
            .blob = blob,
            .storage_key = captured.storage_key,
            .origin = captured.origin,
            .environment = environment,
            .valid = true,
        });

        return url;
    }

    /// File API "resolve a blob URL": capture the complete URL, excluding
    /// its fragment. Access is checked later by the retained entry's read.
    pub fn capture(self: *BlobURLStore, url: []const u8) ?*CapturedEntry {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const key = url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
        const uuid = self.extractUUID(key) orelse return null;
        const entry = self.entries.get(uuid) orelse return null;
        if (!entry.valid or !matchesEntryURL(key, uuid, entry.origin)) return null;
        return entry.captured.retain();
    }

    fn retainPayload(ptr: *anyopaque) void {
        const blob: *BlobData = @ptrCast(@alignCast(ptr));
        _ = blob.retain();
    }

    fn releasePayload(ptr: *anyopaque) void {
        const blob: *BlobData = @ptrCast(@alignCast(ptr));
        blob.deinit();
    }

    fn readPayload(ptr: *anyopaque, allocator: std.mem.Allocator) error{OutOfMemory}!CapturedEntry.Data {
        // BlobData's bytes and MIME type are immutable; its atomic retained
        // reference outlives this read even when another thread revokes.
        const blob: *BlobData = @ptrCast(@alignCast(ptr));
        const bytes = try allocator.dupe(u8, blob.bytes);
        errdefer allocator.free(bytes);
        return .{ .bytes = bytes, .content_type = try allocator.dupe(u8, blob.mime_type) };
    }

    /// Revoke a blob URL, for the current settings object whose storage key
    /// for non-storage purposes is `storage_key` (serialized).
    ///
    /// File API 8.4 revokeObjectURL steps 3-7: "Let entry be urlRecord's blob
    /// URL entry. If entry is null, then return. Let isAuthorized be the
    /// result of checking for same-partition blob URL usage with entry and
    /// the current settings object. If isAuthorized is false, then return.
    /// Remove an entry from the Blob URL Store for url." So another
    /// partition's - or another origin's - revoke silently does nothing
    /// (FileAPI/url/cross-global-revoke.sub.html, all three browsers 3/3).
    /// File API §8.2, remove an entry: serialize the URL WITH its fragment,
    /// then remove that exact key. A URL with a fragment revokes no entry.
    pub fn revokeObjectURL(self: *BlobURLStore, url: []const u8, storage_key: []const u8) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        // Extract UUID from URL (after last '/')
        const uuid = self.extractUUID(url) orelse return;
        const entry = self.entries.get(uuid) orelse return;
        if (!matchesEntryURL(url, uuid, entry.origin)) return;
        if (!std.mem.eql(u8, entry.storage_key, storage_key)) return;

        self.removeEntry(uuid);
    }

    /// Whether `url` (serialized, fragment excluded or not) names a live
    /// entry: "url's blob URL entry is not null", which HTML's noopener steps
    /// ask before comparing the entry's environment's origin - the URL's
    /// own - with the source's top-level origin.
    pub fn hasEntry(self: *BlobURLStore, url: []const u8) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const key = url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
        const uuid = self.extractUUID(key) orelse return false;
        const entry = self.entries.get(uuid) orelse return false;
        return entry.valid and matchesEntryURL(key, uuid, entry.origin);
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
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
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

    /// Remove the entry keyed by `uuid`: its key, its storage key (and
    /// origin) and its reference to its blob's data. Called with `mutex`
    /// held.
    fn removeEntry(self: *BlobURLStore, uuid: []const u8) void {
        const kv = self.entries.fetchRemove(uuid) orelse return;
        self.guard.noteRemoval(&self.entries);
        self.allocator.free(kv.key);
        kv.value.captured.release();
    }

    /// Resolve a blob URL to its associated blob, for `access`.
    ///
    /// File API §8.3, resolve a blob URL: step 3 serializes with the exclude
    /// fragment flag; step 4 looks up the complete resulting URL key. Then
    /// "obtain a blob object" given the entry and `access`: an environment
    /// obtains it only when "check for same-partition blob URL usage" holds -
    /// its storage key equals the entry's - and a top-level navigation or
    /// self-fetch always does.
    ///
    /// RETAINED: the caller holds a reference of its own and releases it
    /// (`deinit`) when done with the bytes. A borrowed pointer could be freed
    /// by a revoke on another thread before the caller had copied them.
    pub fn resolve(self: *BlobURLStore, url: []const u8, access: Access) ?*BlobData {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        // Step 3. Input is a serialized URL; the first '#' begins its
        // fragment, including any slashes or query characters after it.
        const key = url[0 .. std.mem.indexOfScalar(u8, url, '#') orelse url.len];
        const uuid = self.extractUUID(key) orelse return null;

        const entry = self.entries.get(uuid) orelse return null;
        // Step 4. Keep the UUID index, but match the full key, as Chromium's
        // BlobUrlRegistry::GetBlobFromUrl does after ClearUrlFragment.
        if (!matchesEntryURL(key, uuid, entry.origin)) return null;

        // "Obtain a blob object" steps 1-3.
        switch (access) {
            .environment => |storage_key| if (!legacyKeysEqual(entry.storage_key, storage_key)) return null,
            .top_level_navigation, .top_level_self_fetch => {},
        }

        if (!entry.valid) {
            return null;
        }

        return entry.blob.retain();
    }

    /// Navigation still supplies its pre-identity key until streamnav
    /// carries captured entries (row 115 Q18). Preserve that path's old
    /// comparison; fetch/Request/XHR/importScripts authorize through the
    /// captured entry's strict read instead. A key carrying identity is
    /// never reduced to its public serialization here.
    fn legacyKeysEqual(entry_key: []const u8, request_key: []const u8) bool {
        if (std.mem.eql(u8, entry_key, request_key)) return true;
        // A reserved navigation client serializes an unknown opaque
        // identity as "- -" now. That is the old public key, too; a
        // request carrying either identity never takes this fallback.
        const request_prefix = prefix: {
            var spaces: usize = 0;
            for (request_key, 0..) |byte, i| if (byte == ' ') {
                spaces += 1;
                if (spaces == 3) {
                    if (!std.mem.eql(u8, request_key[i..], " - -")) return false;
                    break :prefix request_key[0..i];
                }
            };
            if (spaces != 2) return false;
            break :prefix request_key;
        };
        var spaces: usize = 0;
        for (entry_key, 0..) |byte, i| if (byte == ' ') {
            spaces += 1;
            if (spaces == 3) return std.mem.eql(u8, entry_key[0..i], request_prefix);
        };
        return spaces == 2 and std.mem.eql(u8, entry_key, request_prefix);
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
        // Neither a query nor a fragment is part of a generated entry's
        // key. Resolution removes its fragment before coming here; revoke
        // deliberately does not. Reject before finding '/', since either
        // suffix could itself contain a slash followed by a live UUID.
        if (std.mem.indexOfAny(u8, url, "?#") != null) return null;

        // Find the last '/'
        const last_slash = std.mem.lastIndexOf(u8, url, "/") orelse return null;

        if (last_slash + 1 >= url.len) {
            return null;
        }

        return url[last_slash + 1 ..];
    }

    /// The origin part of a serialized storage key: the text before its
    /// first space (all of it, for a bare origin).
    fn originOfKey(storage_key: []const u8) []const u8 {
        return storage_key[0 .. std.mem.indexOfScalar(u8, storage_key, ' ') orelse storage_key.len];
    }

    /// UUIDs are unique, but a matching suffix alone is not a matching URL.
    /// The rest of the generated key is "blob:" + the stored origin + "/".
    fn matchesEntryURL(url: []const u8, uuid: []const u8, origin: []const u8) bool {
        const origin_end = url.len - uuid.len - 1;
        return std.mem.eql(u8, url["blob:".len..origin_end], origin);
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

    // Should resolve from same origin - a reference of the caller's own
    const resolved = store.resolve(url, .{ .environment = "https://example.com" });
    try std.testing.expect(resolved != null);
    defer resolved.?.deinit();
    try std.testing.expectEqualStrings("Hello", resolved.?.bytes);

    // Should not resolve from different origin
    const cross_origin = store.resolve(url, .{ .environment = "https://other.com" });
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
    const before = store.resolve(url, .{ .environment = "https://example.com" }) orelse return error.TestExpectedEntry;
    before.deinit();

    // Revoke
    store.revokeObjectURL(url, "https://example.com");

    // Should not resolve after revocation
    try std.testing.expect(store.resolve(url, .{ .environment = "https://example.com" }) == null);
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

    const resolved = store.resolve(url, .{ .environment = "https://example.com" }) orelse return error.TestExpectedEntry;
    try std.testing.expectEqual(source.len, resolved.bytes.len);
    try std.testing.expectEqualStrings(source, resolved.bytes);
    try std.testing.expectEqualStrings("text/javascript", resolved.mime_type);
    resolved.deinit();

    // Revoking drops the entry's reference, the last one: the data is freed
    // (std.testing.allocator fails the test on a leak).
    store.revokeObjectURL(url, "https://example.com");
    try std.testing.expect(store.resolve(url, .{ .environment = "https://example.com" }) == null);
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

    store.revokeObjectURL(url1, "https://example.com");
    const resolved = store.resolve(url2, .{ .environment = "https://example.com" }) orelse return error.TestExpectedEntry;
    try std.testing.expectEqual(@as(usize, 6), resolved.bytes.len);
    try std.testing.expectEqualStrings("shared", resolved.bytes);
    resolved.deinit();
    store.revokeObjectURL(url2, "https://example.com");
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
    try std.testing.expect(store.resolve(url_a1, .{ .environment = "https://example.com" }) == null);
    try std.testing.expect(store.resolve(url_a2, .{ .environment = "https://example.com" }) == null);
    const kept = store.resolve(url_b, .{ .environment = "https://example.com" }) orelse return error.TestExpectedEntry;
    try std.testing.expectEqualStrings("page data", kept.bytes);
    kept.deinit();

    // The last entry's end frees the data (std.testing.allocator fails the
    // test on a leak or a second free).
    store.removeEntriesFor(&page_b);
    try std.testing.expect(store.resolve(url_b, .{ .environment = "https://example.com" }) == null);
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
    store.revokeObjectURL(revoked, "https://example.com");
    try std.testing.expect(store.resolve(revoked, .{ .environment = "https://example.com" }) == null);
    const still = store.resolve(live, .{ .environment = "https://example.com" }) orelse return error.TestExpectedEntry;
    still.deinit();

    // The environment's end then takes only what is left.
    store.removeEntriesFor(&page);
    try std.testing.expect(store.resolve(live, .{ .environment = "https://example.com" }) == null);
    try std.testing.expectEqual(@as(usize, 0), store.entries.count());

    // An environment with no entries left, or none ever, is a no-op.
    store.removeEntriesFor(&page);
}

test "BlobURLStore - invalid URL" {
    const allocator = std.testing.allocator;

    var store = BlobURLStore.init(allocator);
    defer store.deinit();

    // Should return null for invalid URLs
    try std.testing.expect(store.resolve("not-a-blob-url", .{ .environment = "https://example.com" }) == null);
    try std.testing.expect(store.resolve("blob:", .{ .environment = "https://example.com" }) == null);
    try std.testing.expect(store.resolve("blob:https://example.com/", .{ .environment = "https://example.com" }) == null);
}

test "BlobURLStore: blob URLs made and revoked page after page keep half the store's unused slots free" {
    // Lane hashmaps1: the store is its Browser's, alive for every page; each
    // URL is a fresh UUID, and leaves at its revoke or its page's end - a
    // removal, which std's map turns into a tombstone it never clears while
    // puts and removes balance (src/infra/tombstones.zig). Entries are read
    // by copy under the lock, and removeEntriesFor collects before it
    // removes, so a rehash moves nothing anyone holds.
    const tombstones = @import("infra").tombstones;
    const allocator = std.testing.allocator;
    var store = BlobURLStore.init(allocator);
    defer store.deinit();
    const blob = try BlobData.init(allocator, "page data", "text/plain");
    defer blob.deinit();
    var page: u8 = 0;
    var starved: usize = 0;
    var worst: usize = 0;
    for (0..300) |_| {
        for (0..16) |i| {
            const url = try store.createObjectURL(blob, "https://example.com", &page);
            if (i % 2 == 0) store.revokeObjectURL(url, "https://example.com");
            allocator.free(url);
            if (i == 0) {
                if (!tombstones.slotCounts(&store.entries).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, tombstones.meanMissProbe(&store.entries));
            }
        }
        // The page ends: the rest leave with it.
        store.removeEntriesFor(&page);
    }
    try std.testing.expectEqual(@as(usize, 0), store.entries.count());
    if (starved != 0 or worst > 8) {
        const counts = tombstones.slotCounts(&store.entries);
        std.debug.print("BlobURLStore.entries: {d} of 300 pages starved; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
}
