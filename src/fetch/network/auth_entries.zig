//! Browser-owned Basic authentication entries (Fetch authentication entries).
//! One hashed partition/origin bucket, then longest protection-space prefix.
//! Design: Chromium 154 HttpAuthCache::LookupByPath/AddPath; RFC 7617 2.2.
const std = @import("std");
const Allocator = std.mem.Allocator;

const Key = struct {
    partition: []const u8,
    origin: []const u8,
    fn copy(self: Key, a: Allocator) !Key {
        const partition = try a.dupe(u8, self.partition);
        errdefer a.free(partition);
        return .{ .partition = partition, .origin = try a.dupe(u8, self.origin) };
    }
    fn deinit(self: Key, a: Allocator) void {
        a.free(self.partition);
        a.free(self.origin);
    }
};
const Hash = struct {
    pub fn hash(_: @This(), key: Key) u64 {
        var h = std.hash.Wyhash.init(0);
        std.hash.autoHash(&h, key.partition.len);
        h.update(key.partition);
        h.update(key.origin);
        return h.final();
    }
    pub fn eql(_: @This(), a: Key, b: Key) bool {
        return std.mem.eql(u8, a.partition, b.partition) and std.mem.eql(u8, a.origin, b.origin);
    }
};

/// A lookup's owned copy: no pointer into a locked store escapes it.
pub const Credentials = struct {
    realm: []u8,
    username: []u8,
    password: []u8,
    pub fn deinit(self: Credentials, a: Allocator) void {
        a.free(self.realm);
        a.free(self.username);
        a.free(self.password);
    }
    fn copy(a: Allocator, realm: []const u8, username: []const u8, password: []const u8) !Credentials {
        const r = try a.dupe(u8, realm);
        errdefer a.free(r);
        const u = try a.dupe(u8, username);
        errdefer a.free(u);
        return .{ .realm = r, .username = u, .password = try a.dupe(u8, password) };
    }
};
const Entry = struct {
    credentials: Credentials,
    paths: std.ArrayListUnmanaged([]u8) = .empty,
    created: u64,
    fn deinit(self: *Entry, a: Allocator) void {
        self.credentials.deinit(a);
        for (self.paths.items) |p| a.free(p);
        self.paths.deinit(a);
    }
    fn addPath(self: *Entry, a: Allocator, path: []const u8) !void {
        // RFC 7617 2.2: the scope ends after the last slash, including it.
        const directory = if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| path[0 .. slash + 1] else "/";
        for (self.paths.items) |p| if (std.mem.startsWith(u8, directory, p)) return;
        const owned = try a.dupe(u8, directory);
        errdefer a.free(owned);
        try self.paths.ensureUnusedCapacity(a, 1);
        var i: usize = 0;
        while (i < self.paths.items.len) {
            if (std.mem.startsWith(u8, self.paths.items[i], directory)) a.free(self.paths.orderedRemove(i)) else i += 1;
        }
        // Chromium's per-realm path bound. Eviction only means a challenge.
        if (self.paths.items.len >= 10) a.free(self.paths.orderedRemove(0));
        self.paths.appendAssumeCapacity(owned);
    }
};
const Bucket = std.ArrayListUnmanaged(Entry);

pub const AuthEntries = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    entries: std.HashMapUnmanaged(Key, Bucket, Hash, 80) = .empty,
    entry_count: std.atomic.Value(usize) = .init(0),
    sequence: u64 = 0,
    /// Chromium 154 HttpAuthCache::kMaxNumRealmEntries (codex-xhr D9).
    max_entries: usize = 20,

    pub fn init(a: Allocator) AuthEntries {
        return .{ .allocator = a };
    }
    pub fn deinit(self: *AuthEntries) void {
        self.clear();
        self.entries.deinit(self.allocator);
    }
    /// The common unauthenticated path takes no lock and allocates nothing.
    pub fn isEmpty(self: *const AuthEntries) bool {
        return self.entry_count.load(.acquire) == 0;
    }

    pub fn lookup(self: *AuthEntries, a: Allocator, partition: []const u8, origin: []const u8, path: []const u8) !?Credentials {
        if (self.isEmpty()) return null;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const bucket = self.entries.getPtr(.{ .partition = partition, .origin = origin }) orelse return null;
        var best: ?*const Entry = null;
        var length: usize = 0;
        for (bucket.items) |*entry| for (entry.paths.items) |prefix| {
            if (prefix.len > length and std.mem.startsWith(u8, path, prefix)) {
                best = entry;
                length = prefix.len;
            }
        };
        const selected = best orelse return null;
        const c = selected.credentials;
        return try Credentials.copy(a, c.realm, c.username, c.password);
    }

    pub fn put(self: *AuthEntries, partition: []const u8, origin: []const u8, realm: []const u8, path: []const u8, username: []const u8, password: []const u8) !void {
        if (self.max_entries == 0) return;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const a = self.allocator;
        const key: Key = .{ .partition = partition, .origin = origin };
        if (self.entries.getPtr(key)) |bucket| for (bucket.items) |*entry| {
            if (!std.mem.eql(u8, entry.credentials.realm, realm)) continue;
            const replacement = try Credentials.copy(a, realm, username, password);
            errdefer replacement.deinit(a);
            try entry.addPath(a, path);
            entry.credentials.deinit(a);
            entry.credentials = replacement;
            return;
        };
        var entry: Entry = .{ .credentials = try Credentials.copy(a, realm, username, password), .created = self.sequence };
        errdefer entry.deinit(a);
        try entry.addPath(a, path);
        self.sequence +%= 1;
        if (self.entry_count.load(.monotonic) >= self.max_entries) self.evict();
        if (!self.entries.contains(key)) {
            const owned = try key.copy(a);
            errdefer owned.deinit(a);
            try self.entries.put(a, owned, .empty);
        }
        const bucket = self.entries.getPtr(key).?;
        errdefer if (bucket.items.len == 0) self.removeEmptyBucket(key);
        try bucket.append(a, entry);
        _ = self.entry_count.fetchAdd(1, .release);
    }

    fn evict(self: *AuthEntries) void {
        var victim: ?Key = null;
        var index: usize = 0;
        var oldest: u64 = std.math.maxInt(u64);
        var it = self.entries.iterator();
        while (it.next()) |bucket| for (bucket.value_ptr.items, 0..) |entry, i| {
            if (victim == null or entry.created < oldest) {
                victim = bucket.key_ptr.*;
                oldest = entry.created;
                index = i;
            }
        };
        if (victim) |key| self.removeAt(key, index);
    }
    fn removeEmptyBucket(self: *AuthEntries, key: Key) void {
        if (self.entries.fetchRemove(key)) |removed| {
            var bucket = removed.value;
            std.debug.assert(bucket.items.len == 0);
            bucket.deinit(self.allocator);
            removed.key.deinit(self.allocator);
        }
    }
    fn removeAt(self: *AuthEntries, key: Key, index: usize) void {
        const bucket = self.entries.getPtr(key).?;
        var entry = bucket.orderedRemove(index);
        entry.deinit(self.allocator);
        _ = self.entry_count.fetchSub(1, .release);
        if (bucket.items.len == 0) self.removeEmptyBucket(key);
    }
    pub fn remove(self: *AuthEntries, partition: []const u8, origin: []const u8, realm: []const u8) void {
        self.removeMatching(partition, origin, realm, null, null);
    }
    /// A rejected older request must not remove newer credentials.
    pub fn removeMatching(self: *AuthEntries, partition: []const u8, origin: []const u8, realm: []const u8, username: ?[]const u8, password: ?[]const u8) void {
        if (self.isEmpty()) return;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const key: Key = .{ .partition = partition, .origin = origin };
        const bucket = self.entries.getPtr(key) orelse return;
        for (bucket.items, 0..) |entry, i| {
            const c = entry.credentials;
            if (!std.mem.eql(u8, c.realm, realm)) continue;
            if (username) |u| if (!std.mem.eql(u8, c.username, u)) return;
            if (password) |p| if (!std.mem.eql(u8, c.password, p)) return;
            self.removeAt(key, i);
            return;
        }
    }
    pub fn clear(self: *AuthEntries) void {
        if (self.isEmpty()) return;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var it = self.entries.iterator();
        while (it.next()) |bucket| {
            for (bucket.value_ptr.items) |*entry| entry.deinit(self.allocator);
            bucket.value_ptr.deinit(self.allocator);
            bucket.key_ptr.deinit(self.allocator);
        }
        self.entries.clearRetainingCapacity();
        self.entry_count.store(0, .release);
    }
};
