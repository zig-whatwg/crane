//! Fetch CORS-preflight cache, owned by one Browser's NetworkContext.
//! Keys and permissions are owned; lookups return only bools under the lock.
//! https://fetch.spec.whatwg.org/#cors-preflight-cache
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CacheKey = struct {
    network_partition_key: []const u8,
    origin: []const u8,
    url: []const u8,

    fn copy(self: CacheKey, a: Allocator) !CacheKey {
        const partition = try a.dupe(u8, self.network_partition_key);
        errdefer a.free(partition);
        const origin = try a.dupe(u8, self.origin);
        errdefer a.free(origin);
        return .{ .network_partition_key = partition, .origin = origin, .url = try a.dupe(u8, self.url) };
    }
    fn deinit(self: CacheKey, a: Allocator) void {
        a.free(self.network_partition_key);
        a.free(self.origin);
        a.free(self.url);
    }
};
const KeyContext = struct {
    pub fn hash(_: @This(), key: CacheKey) u64 {
        var h = std.hash.Wyhash.init(0);
        inline for (.{ key.network_partition_key, key.origin, key.url }) |part| {
            std.hash.autoHash(&h, part.len);
            h.update(part);
        }
        return h.final();
    }
    pub fn eql(_: @This(), a: CacheKey, b: CacheKey) bool {
        return std.mem.eql(u8, a.network_partition_key, b.network_partition_key) and
            std.mem.eql(u8, a.origin, b.origin) and std.mem.eql(u8, a.url, b.url);
    }
};
const Permission = struct {
    name: []u8,
    is_header: bool,
    credentials: bool,
    expires: i64,
};

/// One hashed key, containing the independently expiring method/header entries.
pub const CacheEntry = struct {
    created: i64,
    permissions: std.ArrayListUnmanaged(Permission) = .empty,

    fn deinit(self: *CacheEntry, a: Allocator) void {
        for (self.permissions.items) |p| a.free(p.name);
        self.permissions.deinit(a);
    }
    fn expired(self: *const CacheEntry, now: i64) bool {
        for (self.permissions.items) |p| if (p.expires > now) return false;
        return true;
    }
    fn permits(self: *const CacheEntry, now: i64, credentials: bool, name: []const u8, is_header: bool) bool {
        for (self.permissions.items) |p| {
            if (p.is_header != is_header or p.expires <= now or (credentials and !p.credentials)) continue;
            if (if (is_header) std.ascii.eqlIgnoreCase(p.name, name) else std.mem.eql(u8, p.name, name)) return true;
            // Browsers treat '*' literally for credentialed requests. The
            // Authorization header always needs an explicit permission.
            if (!credentials and std.mem.eql(u8, p.name, "*") and
                !(is_header and std.ascii.eqlIgnoreCase(name, "authorization"))) return true;
        }
        return false;
    }
    fn put(self: *CacheEntry, a: Allocator, name: []const u8, is_header: bool, credentials: bool, expires: i64) !void {
        var matched = false;
        for (self.permissions.items) |*p| {
            if (p.is_header != is_header or (credentials and !p.credentials)) continue;
            const exact = if (is_header) std.ascii.eqlIgnoreCase(p.name, name) else std.mem.eql(u8, p.name, name);
            const wildcard = !credentials and std.mem.eql(u8, p.name, "*") and
                !(is_header and std.ascii.eqlIgnoreCase(name, "authorization"));
            if (exact or wildcard) {
                p.expires = expires;
                matched = true;
            }
        }
        if (matched) return;
        const owned = if (is_header) try std.ascii.allocLowerString(a, name) else try a.dupe(u8, name);
        errdefer a.free(owned);
        try self.permissions.append(a, .{ .name = owned, .is_header = is_header, .credentials = credentials, .expires = expires });
    }
};

pub const PreflightCache = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    entries: std.HashMapUnmanaged(CacheKey, CacheEntry, KeyContext, 80) = .empty,
    entry_count: std.atomic.Value(usize) = .init(0),
    /// Chromium 154: kMaxCacheEntries=1024, kMaxTimeout=2h. Fetch permits
    /// implementation-defined caps and early eviction (codex-xhr D6).
    max_entries: usize = 1024,
    max_max_age: u64 = 7200,

    pub fn init(a: Allocator) PreflightCache {
        return .{ .allocator = a };
    }
    pub fn deinit(self: *PreflightCache) void {
        self.clearAll();
        self.entries.deinit(self.allocator);
    }
    /// A miss is one hash lookup, with no allocation or scan of other keys.
    /// `method=null` means the caller's method needs no cache permission.
    pub fn allows(self: *PreflightCache, key: CacheKey, now: i64, credentials: bool, method: ?[]const u8, headers: []const []const u8) bool {
        if (self.count() == 0) return false;
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = self.entries.getPtr(key) orelse return false;
        if (method) |m| if (!entry.permits(now, credentials, m, false)) return false;
        for (headers) |h| if (!entry.permits(now, credentials, h, true)) return false;
        return true;
    }
    /// Fetch create/update cache entries (preflight steps 8-15). `now` is
    /// monotonic milliseconds, injected for deterministic expiry tests.
    pub fn store(self: *PreflightCache, key: CacheKey, now: i64, max_age: ?u64, methods: []const []const u8, headers: []const []const u8, credentials: bool) !void {
        if (self.max_entries == 0 or methods.len + headers.len == 0 or methods.len + headers.len > 1024) return;
        // Chromium's key-size limit also avoids retaining arbitrarily long URLs.
        if (key.url.len > 1024) return;
        const age: u64 = @min(max_age orelse 5, @min(self.max_max_age, 7200));
        const expires = now +| @as(i64, @intCast(age * 1000));
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const entry = self.entries.getPtr(key) orelse {
            // Prepare the whole insertion before eviction. Allocation
            // failure must preserve the old entry and its count (D13).
            var value: CacheEntry = .{ .created = now };
            errdefer value.deinit(self.allocator);
            for (methods) |m| try value.put(self.allocator, m, false, credentials, expires);
            for (headers) |h| try value.put(self.allocator, h, true, credentials, expires);
            const owned = try key.copy(self.allocator);
            errdefer owned.deinit(self.allocator);
            try self.entries.ensureUnusedCapacity(self.allocator, 1);
            if (self.entries.count() >= self.max_entries) self.evict(now);
            self.entries.putAssumeCapacity(owned, value);
            _ = self.entry_count.fetchAdd(1, .release);
            return;
        };
        var i: usize = 0;
        while (i < entry.permissions.items.len) {
            if (entry.permissions.items[i].expires <= now) {
                self.allocator.free(entry.permissions.swapRemove(i).name);
            } else i += 1;
        }
        if (entry.permissions.items.len + methods.len + headers.len > 1024) {
            entry.deinit(self.allocator);
            entry.* = .{ .created = now };
        }
        for (methods) |m| try entry.put(self.allocator, m, false, credentials, expires);
        for (headers) |h| try entry.put(self.allocator, h, true, credentials, expires);
    }
    /// Only insertion at capacity scans keys. Prefer expired entries, then
    /// evict the oldest key; no callback or other subsystem runs under lock.
    fn evict(self: *PreflightCache, now: i64) void {
        var victim: ?CacheKey = null;
        var oldest: i64 = std.math.maxInt(i64);
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.expired(now)) {
                victim = entry.key_ptr.*;
                break;
            }
            if (victim == null or entry.value_ptr.created < oldest) {
                oldest = entry.value_ptr.created;
                victim = entry.key_ptr.*;
            }
        }
        if (victim) |key| self.remove(key);
    }
    fn remove(self: *PreflightCache, key: CacheKey) void {
        if (self.entries.fetchRemove(key)) |removed| {
            var value = removed.value;
            value.deinit(self.allocator);
            removed.key.deinit(self.allocator);
            _ = self.entry_count.fetchSub(1, .release);
        }
    }
    pub fn clear(self: *PreflightCache, key: CacheKey) void {
        if (self.count() == 0) return;
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.remove(key);
    }
    pub fn clearAll(self: *PreflightCache) void {
        if (self.count() == 0) return;
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            entry.key_ptr.deinit(self.allocator);
        }
        self.entries.clearRetainingCapacity();
        self.entry_count.store(0, .release);
    }
    pub fn count(self: *const PreflightCache) usize {
        return self.entry_count.load(.acquire);
    }
};

const test_key: CacheKey = .{ .origin = "https://frame.test", .url = "https://api.test/", .network_partition_key = "https://top.test" };
test "PreflightCache.init and deinit" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}
test "PreflightCache.createEntry and match" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"PUT"}, &.{"X-Test"}, false);
    try std.testing.expect(cache.allows(test_key, 1, false, "PUT", &.{"x-test"}));
    var other = test_key;
    other.origin = "null";
    try std.testing.expect(!cache.allows(other, 1, false, "PUT", &.{}));
}
test "CacheEntry.isMethodAllowed" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"PUT"}, &.{}, false);
    try std.testing.expect(cache.allows(test_key, 1, false, "PUT", &.{}));
    // Fetch method matching is byte-exact, unlike the old cache's uppercasing.
    try std.testing.expect(!cache.allows(test_key, 1, false, "put", &.{}));
    try std.testing.expect(!cache.allows(test_key, 1, false, "PATCH", &.{}));
}
test "CacheEntry.isMethodAllowed with wildcard" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"*"}, &.{}, false);
    try std.testing.expect(cache.allows(test_key, 1, false, "CUSTOM", &.{}));
}
test "CacheEntry.isHeaderAllowed" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{}, &.{"X-Custom"}, false);
    try std.testing.expect(cache.allows(test_key, 1, false, null, &.{"x-custom"}));
    try std.testing.expect(!cache.allows(test_key, 1, false, null, &.{"Authorization"}));
}
test "CacheEntry.isHeaderAllowed with wildcard" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{}, &.{"*"}, false);
    try std.testing.expect(cache.allows(test_key, 1, false, null, &.{"x-custom"}));
    try std.testing.expect(!cache.allows(test_key, 1, false, null, &.{"Authorization"}));
}
test "PreflightCache.clear" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"PUT"}, &.{}, false);
    cache.clear(test_key);
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}
test "PreflightCache.clearAll" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"PUT"}, &.{}, false);
    cache.clearAll();
    try std.testing.expectEqual(@as(usize, 0), cache.count());
}
test "PreflightCache max age capping" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    cache.max_max_age = 100;
    try cache.store(test_key, 0, 1000, &.{"PUT"}, &.{}, false);
    try std.testing.expect(cache.allows(test_key, 99999, false, "PUT", &.{}));
    try std.testing.expect(!cache.allows(test_key, 100000, false, "PUT", &.{}));
}
test "PreflightCache credentials with wildcard" {
    var cache = PreflightCache.init(std.testing.allocator);
    defer cache.deinit();
    try cache.store(test_key, 0, 60, &.{"*"}, &.{"*"}, true);
    try std.testing.expect(!cache.allows(test_key, 1, true, "PUT", &.{"x-custom"}));
}
