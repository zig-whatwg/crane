//! A Browser's Cache Storage (Service Workers 5): for each storage key, its
//! name to cache map; for each cache, its request response list - kept in
//! the Browser's store through the platform protocol's storage engine
//! (docs/platform-protocol.md 6.6), so a page, its workers and its service
//! worker, each on a thread of its own, see one map; and with a profile
//! directory, a later Browser sees it too.
//!
//! The algorithms that read and change the lists - Query Cache, Request
//! Matches Cached Item, Batch Cache Operations - run here, engine-free, in
//! one store transaction each, under the Browser's cache lock (`Storage`,
//! a BrowserScope supplement): Batch Cache Operations is atomic, and a
//! failure aborts its transaction, which is the spec's roll back to
//! backupCache.
//!
//! The store's keys, in byte order:
//!   0x00                                  the next id (u64, big-endian)
//!   0x01 storage key 0x00 order (u64 BE)  a name to cache map entry:
//!                                         cache id (u64 BE) ++ cache name
//!   0x02 cache id (u64 BE) seq (u64 BE)   a request response list's entry
//!                                         (records.encode), in list order
//!
//! A cache deleted from its map while Cache objects still represent it stays
//! functional for them ("the existing DOM objects ... should remain
//! functional"): its entries live on until the last such object has gone
//! (`retain` / `release`), then the next operation removes them.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-objects

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const records = @import("records.zig");

pub const Entry = records.Entry;
pub const StoredRequest = records.StoredRequest;
pub const StoredResponse = records.StoredResponse;
pub const Header = records.Header;

const store_name = "cache_storage";

pub const Error = error{
    OutOfMemory,
    /// The store failed (platform.StoreError other than OutOfMemory).
    StoreFailed,
    /// Batch Cache Operations' TypeErrors.
    TypeError,
    /// Batch Cache Operations step 4.2.3: two puts of one request in a
    /// batch.
    InvalidStateError,
    QuotaExceeded,
};

/// CacheQueryOptions.
pub const QueryOptions = struct {
    ignore_search: bool = false,
    ignore_method: bool = false,
    ignore_vary: bool = false,
};

/// What Query Cache matches against: a request's URL, method and headers.
/// BORROWED.
pub const Query = struct {
    url: []const u8,
    method: []const u8 = "GET",
    headers: []const Header = &.{},

    pub fn of(request: *const StoredRequest) Query {
        return .{ .url = request.url, .method = request.method, .headers = request.headers };
    }
};

/// A cache batch operation (5.4). BORROWED.
pub const Operation = struct {
    kind: enum { put, delete },
    /// A put's request (all of it is stored); a delete's query.
    request: *const StoredRequest,
    response: ?*const StoredResponse = null,
    options: ?QueryOptions = null,
};

/// A Browser's cache lock and the Cache objects alive per cache.
pub const Storage = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    /// Cache objects alive, per cache id.
    handles: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    /// Caches deleted from their map while objects still represent them.
    doomed: std.ArrayListUnmanaged(u64) = .empty,

    /// A BrowserScope supplement's init: with the scope's lock held.
    pub fn init(allocator: Allocator) Storage {
        return .{ .allocator = allocator };
    }

    /// With the Browser's scope, after every realm has ended; the store's
    /// data goes with the Browser's platform state (or stays on disk).
    pub fn deinit(self: *Storage) void {
        self.handles.deinit(self.allocator);
        self.doomed.deinit(self.allocator);
    }

    fn lock(self: *Storage) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *Storage) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// A Cache object now represents `cache`.
    pub fn retain(self: *Storage, cache: u64) Allocator.Error!void {
        self.lock();
        defer self.unlock();
        const entry = try self.handles.getOrPut(self.allocator, cache);
        if (!entry.found_existing) entry.value_ptr.* = 0;
        entry.value_ptr.* += 1;
    }

    /// A Cache object that represented `cache` has gone. Any thread; touches
    /// no store (the next operation removes a doomed cache's entries).
    pub fn release(self: *Storage, cache: u64) void {
        self.lock();
        defer self.unlock();
        const count = self.handles.getPtr(cache) orelse return;
        count.* -= 1;
        if (count.* == 0) _ = self.handles.remove(cache);
    }

    fn isHeld(self: *const Storage, cache: u64) bool {
        return self.handles.contains(cache);
    }

    // ------------------------------------------------------------------
    // The name to cache map (CacheStorage, 5.5)
    // ------------------------------------------------------------------

    /// has(cacheName) step 2.1: whether `storage_key`'s map has `name`.
    pub fn hasCache(self: *Storage, browser: *platform.BrowserPlatform, storage_key: []const u8, name: []const u8) Error!bool {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .read, self.allocator);
        defer txn.end();
        const found = (try findName(&txn, self.allocator, storage_key, name)) orelse return false;
        self.allocator.free(found.key);
        return true;
    }

    /// open(cacheName) step 2: the cache `name` of `storage_key`'s map, made
    /// (and appended to the map) when there is none. Its id.
    pub fn openCache(self: *Storage, browser: *platform.BrowserPlatform, storage_key: []const u8, name: []const u8) Error!u64 {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .write, self.allocator);
        errdefer txn.abort();
        try self.purgeDoomed(&txn);
        if (try findName(&txn, self.allocator, storage_key, name)) |found| {
            self.allocator.free(found.key);
            try txn.commit();
            return found.cache;
        }
        // 2.2-2.3. A new request response list, set at map[cacheName].
        const cache = try nextId(&txn);
        const order = try nextId(&txn);
        const key = try nameKey(self.allocator, storage_key, order);
        defer self.allocator.free(key);
        const value = try self.allocator.alloc(u8, 8 + name.len);
        defer self.allocator.free(value);
        std.mem.writeInt(u64, value[0..8], cache, .big);
        @memcpy(value[8..], name);
        try txn.put(key, value);
        try txn.commit();
        return cache;
    }

    /// delete(cacheName) step 2.3.1: remove map[cacheName]; false when the
    /// map has no such cache. Its entries go now, or once no Cache object
    /// represents it.
    pub fn deleteCache(self: *Storage, browser: *platform.BrowserPlatform, storage_key: []const u8, name: []const u8) Error!bool {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .write, self.allocator);
        errdefer txn.abort();
        const found = (try findName(&txn, self.allocator, storage_key, name)) orelse {
            txn.end();
            return false;
        };
        defer self.allocator.free(found.key);
        try txn.delete(found.key);
        if (self.isHeld(found.cache)) {
            try self.doomed.append(self.allocator, found.cache);
        } else {
            try deleteEntries(&txn, found.cache);
        }
        try txn.commit();
        return true;
    }

    /// keys() step 2.1: the map's names, in the order they were added. OWNED.
    pub fn cacheNames(self: *Storage, browser: *platform.BrowserPlatform, allocator: Allocator, storage_key: []const u8) Error![][]u8 {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .read, self.allocator);
        defer txn.end();
        var names: std.ArrayListUnmanaged([]u8) = .empty;
        errdefer {
            for (names.items) |n| allocator.free(n);
            names.deinit(allocator);
        }
        const prefix = try namePrefix(self.allocator, storage_key);
        defer self.allocator.free(prefix);
        var cursor = try txn.prefixCursor(prefix);
        defer cursor.close();
        while (try cursor.next(self.allocator)) |kv| {
            defer kv.free(self.allocator);
            if (kv.value.len < 8) return error.StoreFailed;
            try names.append(allocator, try allocator.dupe(u8, kv.value[8..]));
        }
        return names.toOwnedSlice(allocator);
    }

    /// The map's caches, as (name, id), in order. OWNED names.
    pub fn caches(self: *Storage, browser: *platform.BrowserPlatform, allocator: Allocator, storage_key: []const u8) Error![]NamedCache {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .read, self.allocator);
        defer txn.end();
        var list: std.ArrayListUnmanaged(NamedCache) = .empty;
        errdefer {
            for (list.items) |c| allocator.free(c.name);
            list.deinit(allocator);
        }
        const prefix = try namePrefix(self.allocator, storage_key);
        defer self.allocator.free(prefix);
        var cursor = try txn.prefixCursor(prefix);
        defer cursor.close();
        while (try cursor.next(self.allocator)) |kv| {
            defer kv.free(self.allocator);
            if (kv.value.len < 8) return error.StoreFailed;
            try list.append(allocator, .{
                .cache = std.mem.readInt(u64, kv.value[0..8], .big),
                .name = try allocator.dupe(u8, kv.value[8..]),
            });
        }
        return list.toOwnedSlice(allocator);
    }

    pub const NamedCache = struct { cache: u64, name: []u8 };

    // ------------------------------------------------------------------
    // A request response list (Cache, 5.4)
    // ------------------------------------------------------------------

    /// Query Cache with `query` and `options` over the cache `cache` - or,
    /// with no query, every entry of it (matchAll() and keys() with the
    /// request omitted). Copies, in list order. OWNED.
    pub fn query(self: *Storage, browser: *platform.BrowserPlatform, allocator: Allocator, cache: u64, request_query: ?Query, options: QueryOptions) Error![]Entry {
        self.lock();
        defer self.unlock();
        var txn = try Txn.begin(browser, .read, self.allocator);
        defer txn.end();
        var list = try loadEntries(&txn, allocator, cache);
        defer {
            for (list.items) |*item| item.deinit(allocator);
            list.deinit(allocator);
        }
        var result: std.ArrayListUnmanaged(Entry) = .empty;
        errdefer {
            for (result.items) |*e| e.deinit(allocator);
            result.deinit(allocator);
        }
        for (list.items) |*item| {
            const keep = if (request_query) |q| try requestMatchesCachedItem(allocator, q, &item.entry.request, &item.entry.response, options) else true;
            if (!keep) continue;
            try result.append(allocator, item.entry);
            // The result has it now.
            item.entry = undefined;
            item.moved = true;
        }
        return result.toOwnedSlice(allocator);
    }

    /// Batch Cache Operations on the cache `cache`: atomic - an error leaves
    /// it as it was. The number of entries the delete operations removed
    /// (what delete() resolves with: true when some were).
    pub fn batch(self: *Storage, browser: *platform.BrowserPlatform, cache: u64, operations: []const Operation) Error!usize {
        self.lock();
        defer self.unlock();
        const allocator = self.allocator;
        var txn = try Txn.begin(browser, .write, self.allocator);
        errdefer txn.abort();
        try self.purgeDoomed(&txn);
        // 1-2. cache, and its backup: the transaction's.
        var list = try loadEntries(&txn, allocator, cache);
        defer {
            for (list.items) |*item| item.deinit(allocator);
            list.deinit(allocator);
        }
        // 3. addedItems: indexes into `list`.
        var added: std.ArrayListUnmanaged(usize) = .empty;
        defer added.deinit(allocator);
        var removed: usize = 0;
        for (operations) |operation| {
            // 4.2.1-2. Types (delete with a response).
            if (operation.kind == .delete and operation.response != null) return error.TypeError;
            // 4.2.3. Query Cache with the request and options over
            // addedItems: not empty - InvalidStateError.
            const options = operation.options orelse QueryOptions{};
            for (added.items) |index| {
                const item = &list.items[index];
                if (item.deleted) continue;
                if (try requestMatchesCachedItem(allocator, Query.of(operation.request), &item.entry.request, &item.entry.response, options)) return error.InvalidStateError;
            }
            switch (operation.kind) {
                // 4.2.5. Delete what Query Cache finds.
                .delete => {
                    for (list.items) |*item| {
                        if (item.deleted) continue;
                        if (!try requestMatchesCachedItem(allocator, Query.of(operation.request), &item.entry.request, &item.entry.response, options)) continue;
                        item.deleted = true;
                        removed += 1;
                        if (item.key) |key| try txn.delete(key);
                    }
                },
                .put => {
                    // 4.2.6.1. A put with no response.
                    const response = operation.response orelse return error.TypeError;
                    // 4.2.6.3-4. An http(s) URL, GET.
                    if (!isHttpScheme(operation.request.url)) return error.TypeError;
                    if (!std.mem.eql(u8, operation.request.method, "GET")) return error.TypeError;
                    // 4.2.6.5. Options must be null.
                    if (operation.options != null) return error.TypeError;
                    // 4.2.6.6-7. Remove what Query Cache finds for the
                    // request, default options.
                    for (list.items) |*item| {
                        if (item.deleted) continue;
                        if (!try requestMatchesCachedItem(allocator, Query.of(operation.request), &item.entry.request, &item.entry.response, .{})) continue;
                        item.deleted = true;
                        if (item.key) |key| try txn.delete(key);
                    }
                    // 4.2.6.8. Append the request/response to the cache.
                    var entry: Entry = .{
                        .request = try operation.request.clone(allocator),
                        .response = undefined,
                    };
                    entry.response = response.clone(allocator) catch |err| {
                        entry.request.deinit(allocator);
                        return err;
                    };
                    const seq = nextId(&txn) catch |err| {
                        entry.deinit(allocator);
                        return err;
                    };
                    const key = entryKey(allocator, cache, seq) catch |err| {
                        entry.deinit(allocator);
                        return err;
                    };
                    const bytes = records.encode(allocator, &entry) catch |err| {
                        entry.deinit(allocator);
                        allocator.free(key);
                        return err;
                    };
                    defer allocator.free(bytes);
                    // 4.2.6.9. A write over the quota: QuotaExceededError.
                    txn.put(key, bytes) catch |err| {
                        entry.deinit(allocator);
                        allocator.free(key);
                        return err;
                    };
                    list.append(allocator, .{ .entry = entry, .key = key }) catch |err| {
                        entry.deinit(allocator);
                        allocator.free(key);
                        return err;
                    };
                    // 4.2.6.10. addedItems.
                    try added.append(allocator, list.items.len - 1);
                },
            }
        }
        try txn.commit();
        return removed;
    }

    /// Remove the entries of deleted caches no Cache object represents
    /// any more. Locked, in a write transaction.
    fn purgeDoomed(self: *Storage, txn: *Txn) Error!void {
        var i: usize = 0;
        while (i < self.doomed.items.len) {
            const cache = self.doomed.items[i];
            if (self.isHeld(cache)) {
                i += 1;
                continue;
            }
            try deleteEntries(txn, cache);
            _ = self.doomed.swapRemove(i);
        }
    }
};

/// A request response list's entry as it was loaded.
const Loaded = struct {
    entry: Entry,
    /// Its key in the store. OWNED.
    key: ?[]u8,
    /// Removed from the list in this batch.
    deleted: bool = false,
    /// Its entry was handed to a result.
    moved: bool = false,

    fn deinit(self: *Loaded, allocator: Allocator) void {
        if (!self.moved) self.entry.deinit(allocator);
        if (self.key) |k| allocator.free(k);
    }
};

/// The cache's entries, in list order. OWNED (each entry and key).
fn loadEntries(txn: *Txn, allocator: Allocator, cache: u64) Error!std.ArrayListUnmanaged(Loaded) {
    var list: std.ArrayListUnmanaged(Loaded) = .empty;
    errdefer {
        for (list.items) |*item| item.deinit(allocator);
        list.deinit(allocator);
    }
    var prefix: [9]u8 = undefined;
    prefix[0] = 0x02;
    std.mem.writeInt(u64, prefix[1..9], cache, .big);
    var cursor = try txn.prefixCursor(&prefix);
    defer cursor.close();
    while (try cursor.next(allocator)) |kv| {
        defer allocator.free(kv.value_owned);
        errdefer allocator.free(kv.key_owned);
        var entry = records.decode(allocator, kv.value) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Corrupt => return error.StoreFailed,
        };
        errdefer entry.deinit(allocator);
        try list.append(allocator, .{ .entry = entry, .key = kv.key_owned });
    }
    return list;
}

fn deleteEntries(txn: *Txn, cache: u64) Error!void {
    var lower: [9]u8 = undefined;
    lower[0] = 0x02;
    std.mem.writeInt(u64, lower[1..9], cache, .big);
    var upper: [9]u8 = undefined;
    upper[0] = 0x02;
    std.mem.writeInt(u64, upper[1..9], cache + 1, .big);
    try txn.deleteRange(&lower, &upper);
}

const FoundName = struct { cache: u64, key: []u8 };

/// The map entry of `storage_key` named `name`, if any. OWNED key.
fn findName(txn: *Txn, allocator: Allocator, storage_key: []const u8, name: []const u8) Error!?FoundName {
    const prefix = try namePrefix(allocator, storage_key);
    defer allocator.free(prefix);
    var cursor = try txn.prefixCursor(prefix);
    defer cursor.close();
    while (try cursor.next(allocator)) |kv| {
        if (kv.value.len >= 8 and std.mem.eql(u8, kv.value[8..], name)) {
            const cache = std.mem.readInt(u64, kv.value[0..8], .big);
            allocator.free(kv.value_owned);
            return .{ .cache = cache, .key = kv.key_owned };
        }
        kv.free(allocator);
    }
    return null;
}

fn namePrefix(allocator: Allocator, storage_key: []const u8) Allocator.Error![]u8 {
    const prefix = try allocator.alloc(u8, storage_key.len + 2);
    prefix[0] = 0x01;
    @memcpy(prefix[1 .. 1 + storage_key.len], storage_key);
    prefix[prefix.len - 1] = 0x00;
    return prefix;
}

fn nameKey(allocator: Allocator, storage_key: []const u8, order: u64) Allocator.Error![]u8 {
    const key = try allocator.alloc(u8, storage_key.len + 2 + 8);
    key[0] = 0x01;
    @memcpy(key[1 .. 1 + storage_key.len], storage_key);
    key[1 + storage_key.len] = 0x00;
    std.mem.writeInt(u64, key[key.len - 8 ..][0..8], order, .big);
    return key;
}

fn entryKey(allocator: Allocator, cache: u64, seq: u64) Allocator.Error![]u8 {
    const key = try allocator.alloc(u8, 17);
    key[0] = 0x02;
    std.mem.writeInt(u64, key[1..9], cache, .big);
    std.mem.writeInt(u64, key[9..17], seq, .big);
    return key;
}

/// The store's next id. In a write transaction.
fn nextId(txn: *Txn) Error!u64 {
    const key = [_]u8{0x00};
    var id: u64 = 1;
    if (try txn.get(&key)) |bytes| {
        defer txn.allocator.free(bytes);
        if (bytes.len != 8) return error.StoreFailed;
        id = std.mem.readInt(u64, bytes[0..8], .big);
    }
    var next: [8]u8 = undefined;
    std.mem.writeInt(u64, &next, id + 1, .big);
    try txn.put(&key, &next);
    return id;
}

fn isHttpScheme(url: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(url, "http:") or std.ascii.startsWithIgnoreCase(url, "https:");
}

// ============================================================================
// Request Matches Cached Item
// ============================================================================

/// Request Matches Cached Item: whether the cached `request` (with its
/// `response`) matches `request_query` under `options`.
pub fn requestMatchesCachedItem(allocator: Allocator, request_query: Query, request: *const StoredRequest, response: ?*const StoredResponse, options: QueryOptions) Allocator.Error!bool {
    // 1. A cached request whose method is not GET matches only with
    // ignoreMethod.
    if (!options.ignore_method and !std.mem.eql(u8, request.method, "GET")) return false;
    // 2-5. The URLs, equal with the exclude fragment flag - and with their
    // queries empty under ignoreSearch.
    if (!std.mem.eql(u8, comparableUrl(request_query.url, options.ignore_search), comparableUrl(request.url, options.ignore_search))) return false;
    // 6. No response, ignoreVary, or no Vary header: a match.
    const cached_response = response orelse return true;
    if (options.ignore_vary) return true;
    // An opaque response's header list is empty: no Vary (its record keeps
    // the internal response's headers, which the spec's stored response,
    // the filtered one, does not show).
    if (cached_response.hidesHeaders()) return true;
    const vary = (try cached_response.header(allocator, "Vary")) orelse return true;
    defer allocator.free(vary);
    // 7-8. Each field-value: "*" never matches; otherwise the combined
    // values of that header in both requests must be the same.
    var fields = std.mem.splitScalar(u8, vary, ',');
    while (fields.next()) |raw| {
        const field = std.mem.trim(u8, raw, " \t");
        if (field.len == 0) continue;
        if (std.mem.eql(u8, field, "*")) return false;
        const cached = try records.combinedValue(allocator, request.headers, field);
        defer if (cached) |v| allocator.free(v);
        const queried = try records.combinedValue(allocator, request_query.headers, field);
        defer if (queried) |v| allocator.free(v);
        if (cached == null and queried == null) continue;
        if (cached == null or queried == null) return false;
        if (!std.mem.eql(u8, cached.?, queried.?)) return false;
    }
    // 9.
    return true;
}

/// `url` with its fragment excluded, and its query too when `ignore_search`
/// (step 4 sets both queries to the empty string: they compare equal either
/// way).
fn comparableUrl(url: []const u8, ignore_search: bool) []const u8 {
    const without_fragment = if (std.mem.indexOfScalar(u8, url, '#')) |i| url[0..i] else url;
    if (!ignore_search) return without_fragment;
    return if (std.mem.indexOfScalar(u8, without_fragment, '?')) |i| without_fragment[0..i] else without_fragment;
}

// ============================================================================
// The store, one transaction at a time
// ============================================================================

const KeyValue = struct {
    key: []const u8,
    value: []const u8,
    key_owned: []u8,
    value_owned: []u8,

    fn free(self: KeyValue, allocator: Allocator) void {
        allocator.free(self.key_owned);
        allocator.free(self.value_owned);
    }
};

const Txn = struct {
    store: *platform.Store,
    txn: *platform.StoreTransaction,
    allocator: Allocator,
    /// The transaction has ended (committed or aborted).
    done: bool = false,
    closed: bool = false,

    fn begin(browser: *platform.BrowserPlatform, mode: platform.TransactionMode, allocator: Allocator) Error!Txn {
        const store = platform.openStore(browser, platform.Str.from(store_name), .{}) catch |err| return storeError(err);
        errdefer platform.closeStore(store);
        const txn = platform.beginTransaction(store, mode) catch |err| return storeError(err);
        return .{ .store = store, .txn = txn, .allocator = allocator };
    }

    /// End the transaction - a read one, or one given up - and the store
    /// handle. Idempotent.
    fn end(self: *Txn) void {
        if (!self.done) platform.abortTransaction(self.txn);
        self.done = true;
        if (!self.closed) platform.closeStore(self.store);
        self.closed = true;
    }

    fn abort(self: *Txn) void {
        self.end();
    }

    fn commit(self: *Txn) Error!void {
        self.done = true;
        defer self.end();
        platform.commitTransaction(self.txn) catch |err| return storeError(err);
    }

    fn get(self: *Txn, key: []const u8) Error!?[]u8 {
        return platform.storeGet(self.txn, self.allocator, platform.Bytes.from(key)) catch |err| return storeError(err);
    }

    fn put(self: *Txn, key: []const u8, value: []const u8) Error!void {
        platform.storePut(self.txn, platform.Bytes.from(key), platform.Bytes.from(value)) catch |err| return storeError(err);
    }

    fn delete(self: *Txn, key: []const u8) Error!void {
        platform.storeDelete(self.txn, platform.Bytes.from(key)) catch |err| return storeError(err);
    }

    fn deleteRange(self: *Txn, lower: []const u8, upper: []const u8) Error!void {
        platform.storeDeleteRange(self.txn, .{
            .lower = platform.Bytes.from(lower),
            .upper = platform.Bytes.from(upper),
            .has_lower = true,
            .has_upper = true,
            .upper_open = true,
        }) catch |err| return storeError(err);
    }

    /// A cursor over the keys that start with `prefix`.
    fn prefixCursor(self: *Txn, prefix: []const u8) Error!Cursor {
        const cursor = platform.openCursor(self.txn, .{ .lower = platform.Bytes.from(prefix), .has_lower = true }, .forward) catch |err| return storeError(err);
        return .{ .cursor = cursor, .prefix = prefix };
    }
};

const Cursor = struct {
    cursor: *platform.StoreCursor,
    prefix: []const u8,

    /// The next pair under the prefix. OWNED.
    fn next(self: *Cursor, allocator: Allocator) Error!?KeyValue {
        const kv = (platform.cursorNext(self.cursor, allocator) catch |err| return storeError(err)) orelse return null;
        const key: []u8 = @constCast(kv.key.slice());
        const value: []u8 = @constCast(kv.value.slice());
        if (!std.mem.startsWith(u8, key, self.prefix)) {
            allocator.free(key);
            allocator.free(value);
            return null;
        }
        return .{ .key = key, .value = value, .key_owned = key, .value_owned = value };
    }

    fn close(self: *Cursor) void {
        platform.closeCursor(self.cursor);
    }
};

fn storeError(err: platform.StoreError) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.QuotaExceeded => error.QuotaExceeded,
        else => error.StoreFailed,
    };
}
