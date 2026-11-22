//! The cookie jar's persistence in a Browser's profile directory (the
//! user's ruling D6, 2026-11-21: Puppeteer's and Playwright's
//! --user-data-dir fully supported; lane prof1, D6 step 3). Only a Browser
//! given a profile directory has one (`CookieJar.attachProfile`, from
//! src/browser/profile_stores.zig at Browser.init); without one the jar is
//! in memory alone, exactly as before.
//!
//! The jar's cookies are the truth; the store "cookies" (docs/platform-
//! protocol.md 6.6: kit/sqlite under the profile) keeps one record per
//! persistent cookie, keyed by the cookie's identity - partition key,
//! domain, host-only flag, path and name (Cookie.hasSameIdentity) - as
//! Chromium's SQLitePersistentCookieStore keeps a row per cookie and
//! Firefox's cookies.sqlite one per (name, host, path, originAttributes).
//! What is written when follows Chromium (BSD; reproduced, not copied -
//! net/extras/sqlite/sqlite_persistent_cookie_store.cc, Copyright 2012 The
//! Chromium Authors; net/cookies/cookie_monster.cc):
//!
//! - Only persistent cookies are written. CookieMonster tells its store
//!   about a cookie only when ShouldUpdatePersistentStore - "cc.IsPersistent()
//!   || persist_session_cookies_", the latter off in a browser - and Firefox
//!   writes no session cookie to cookies.sqlite either. A session cookie
//!   that replaces a persistent one deletes its record (Chrome: the old
//!   cookie's DeleteCookie, then no AddCookie).
//! - Changes are queued and coalesced per cookie (Backend::BatchOperation:
//!   "A delete op makes all the previous ones irrelevant", an access-time
//!   update after another drops the earlier one; here each cookie's last
//!   state - its record, or its deletion - stands for all of them), and
//!   committed in one transaction (DoCommit) "every 30 seconds" after the
//!   batch's first operation (kCommitInterval), at once when "more than 512
//!   outstanding operations" were queued (kCommitAfterBatchSize: the count
//!   is of operations, not of cookies), and at the Browser's end (the
//!   cookie store's Flush; Browser.deinit's `flush`, while the platform
//!   state lives).
//! - Last access times are written only once a cookie's has moved
//!   kDefaultAccessUpdateThresholdSeconds, 60 s, past the one last written
//!   (CookieMonster::InternalUpdateCookieAccessTime: "When a cookie has been
//!   accessed recently, don't bother updating its access time again"). The
//!   jar's in-memory access times are unchanged.
//! - At load, a record whose cookie has expired is deleted and not loaded.
//!   Chromium loads expired cookies and deletes them, store included, at
//!   their first lookup or garbage collection (StoreLoadedCookies: "Even if
//!   a key is expired, insert it so it can be garbage collected, removed,
//!   and sync'd"); the jar would drop them at its first garbage collection,
//!   and no page could see them in between, so the sweep is that deletion
//!   made at once.
//! - A failed commit is logged; its operations are dropped (DoCommit
//!   records the error and carries on) and the jar keeps its cookies.
//!
//! THREADS: the jar serves every thread of its Browser under its lock, and
//! records into this under that lock (`mutex` nests inside it). Commits run
//! on the Browser's window thread - its timer's, its posted task's, its
//! end's - one at a time (`commit_mutex`).

const std = @import("std");
const platform = @import("platform");
const storage = @import("storage");
const clock = @import("clock");
const cookie_mod = @import("cookie.zig");
const Cookie = cookie_mod.Cookie;
const SameSite = cookie_mod.SameSite;
const PartitionKey = cookie_mod.PartitionKey;
const CookieJar = @import("jar.zig").CookieJar;

const log = std.log.scoped(.cookie_persistence);

/// The store the jar keeps its persistent cookies in.
pub const store_name = "cookies";
/// sqlite_persistent_cookie_store.cc kCommitInterval: "Commit every 30
/// seconds."
pub const commit_interval_ms: u64 = 30 * std.time.ms_per_s;
/// sqlite_persistent_cookie_store.cc kCommitAfterBatchSize: "Commit right
/// away if we have more than 512 outstanding operations."
pub const commit_after_batch_size: usize = 512;
/// cookie_monster.cc kDefaultAccessUpdateThresholdSeconds.
pub const access_update_threshold_ms: i64 = 60 * std.time.ms_per_s;

/// The record format's version, its first byte.
const record_version: u8 = 1;

pub const CookiePersistence = struct {
    allocator: std.mem.Allocator,
    /// BORROWED: the Browser's platform state, which outlives every commit.
    browser: *platform.BrowserPlatform,
    timer: ?storage.profile.CommitTimer,
    /// The jar this persists: a `rewrite_all` commit reads it whole.
    jar: *CookieJar,
    /// Guards `pending`, `num_pending` and `rewrite_all`. Taken inside the
    /// jar's lock, never around it.
    mutex: std.Io.Mutex = .init,
    /// Each changed cookie's last state, by record key: its record (OWNED),
    /// or null for its deletion. OWNED keys.
    pending: std.StringHashMapUnmanaged(?[]u8) = .empty,
    /// Backend::num_pending_: operations queued since the last commit.
    num_pending: usize = 0,
    /// A change that could not be queued for lack of memory, or a jar
    /// cleared whole: the next commit deletes every record and writes every
    /// persistent cookie of the jar.
    rewrite_all: bool = false,
    /// One commit at a time.
    commit_mutex: std.Io.Mutex = .init,

    pub fn create(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, timer: ?storage.profile.CommitTimer, jar: *CookieJar) std.mem.Allocator.Error!*CookiePersistence {
        const self = try allocator.create(CookiePersistence);
        self.* = .{ .allocator = allocator, .browser = browser, .timer = timer, .jar = jar };
        return self;
    }

    /// With the jar, after the Browser's flush and its platform state's
    /// end: what is still queued (nothing, after a flush) is dropped.
    pub fn destroy(self: *CookiePersistence) void {
        self.forgetPending();
        self.pending.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn forgetPending(self: *CookiePersistence) void {
        var entries = self.pending.iterator();
        while (entries.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.*) |record| self.allocator.free(record);
        }
        self.pending.clearRetainingCapacity();
    }

    fn lock(mutex: *std.Io.Mutex) void {
        std.Io.Threaded.mutexLockUncancelable(mutex);
    }

    fn unlock(mutex: *std.Io.Mutex) void {
        std.Io.Threaded.mutexUnlock(mutex);
    }

    // ------------------------------------------------------------- loading

    /// Read the profile's cookies into the jar, which is empty: the
    /// persistent cookies that have not expired, in creation order. The
    /// records of expired cookies - and any that cannot be read - are
    /// deleted. Before any realm of the Browser exists.
    pub fn load(self: *CookiePersistence) platform.StoreError!void {
        const store = try platform.openStore(self.browser, platform.Str.from(store_name), .{});
        defer platform.closeStore(store);
        var stale: std.ArrayListUnmanaged([]u8) = .empty;
        defer {
            for (stale.items) |key| self.allocator.free(key);
            stale.deinit(self.allocator);
        }
        {
            const transaction = try platform.beginTransaction(store, .read);
            defer platform.abortTransaction(transaction);
            const cursor = try platform.openCursor(transaction, .all, .forward);
            defer platform.closeCursor(cursor);
            while (try platform.cursorNext(cursor, self.allocator)) |record| {
                const key = @constCast(record.key.slice());
                var keep_key = false;
                defer if (!keep_key) self.allocator.free(key);
                defer self.allocator.free(record.value.slice());
                var cookie = decode(self.jar.allocator, record.value.slice()) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.Corrupt => {
                        log.warn("a cookie record of the profile could not be read; it is deleted", .{});
                        try stale.append(self.allocator, key);
                        keep_key = true;
                        continue;
                    },
                };
                if (cookie.isExpired() or cookie.isSession()) {
                    cookie.deinit();
                    try stale.append(self.allocator, key);
                    keep_key = true;
                    continue;
                }
                cookie.persisted_access_time = cookie.last_access_time;
                self.jar.cookies.append(self.jar.allocator, cookie) catch |err| {
                    cookie.deinit();
                    return err;
                };
            }
        }
        // The jar's order is its insertion order; a restored jar's is its
        // cookies' creation order (a stable sort keeps a tie's record order).
        std.mem.sort(Cookie, self.jar.cookies.items, {}, struct {
            fn lessThan(_: void, a: Cookie, b: Cookie) bool {
                return a.creation_time < b.creation_time;
            }
        }.lessThan);
        if (stale.items.len == 0) return;
        const transaction = try platform.beginTransaction(store, .write);
        for (stale.items) |key| platform.storeDelete(transaction, platform.Bytes.from(key)) catch |err| {
            platform.abortTransaction(transaction);
            return err;
        };
        try platform.commitTransaction(transaction);
    }

    // ----------------------------------------------------------- recording

    /// The jar stored `cookie` (inserted, or replacing one of its identity):
    /// its record, if it is persistent; its deletion otherwise. Under the
    /// jar's lock.
    pub fn recordStored(self: *CookiePersistence, cookie: *Cookie) void {
        if (cookie.isSession()) return self.recordRemoved(cookie);
        cookie.persisted_access_time = cookie.last_access_time;
        self.queue(cookie, true);
    }

    /// The jar removed `cookie`. Under the jar's lock.
    pub fn recordRemoved(self: *CookiePersistence, cookie: *const Cookie) void {
        self.queue(cookie, false);
    }

    /// The jar was cleared. Under the jar's lock.
    pub fn recordCleared(self: *CookiePersistence) void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        self.forgetPending();
        self.rewrite_all = true;
        self.noteOperation();
    }

    /// `cookie` was retrieved and its access time moved: written once it
    /// is a threshold past the last one written. Under the jar's lock.
    pub fn recordAccess(self: *CookiePersistence, cookie: *Cookie) void {
        if (cookie.isSession()) return;
        if (cookie.last_access_time - cookie.persisted_access_time < access_update_threshold_ms) return;
        cookie.persisted_access_time = cookie.last_access_time;
        self.queue(cookie, true);
    }

    /// Backend::BatchOperation.
    fn queue(self: *CookiePersistence, cookie: *const Cookie, put: bool) void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        defer self.noteOperation();
        if (self.rewrite_all) return;
        self.queueLocked(cookie, put) catch {
            // Out of memory: the next commit writes the jar whole, so no
            // change is lost to the store.
            self.forgetPending();
            self.rewrite_all = true;
        };
    }

    fn queueLocked(self: *CookiePersistence, cookie: *const Cookie, put: bool) std.mem.Allocator.Error!void {
        const key = try recordKey(self.allocator, cookie);
        errdefer self.allocator.free(key);
        const record: ?[]u8 = if (put) try encode(self.allocator, cookie) else null;
        errdefer if (record) |bytes| self.allocator.free(bytes);
        const entry = try self.pending.getOrPut(self.allocator, key);
        if (entry.found_existing) {
            self.allocator.free(key);
            if (entry.value_ptr.*) |old| self.allocator.free(old);
        }
        entry.value_ptr.* = record;
    }

    /// The batch's first operation arms the 30 s commit; its 512th commits
    /// at once (both on the window thread, as tasks: the jar may be held
    /// here, on any thread).
    fn noteOperation(self: *CookiePersistence) void {
        self.num_pending += 1;
        const timer = self.timer orelse return;
        if (self.num_pending == 1) {
            timer.post(timer.context, commit_interval_ms, commitFired, self, commitDropped);
        } else if (self.num_pending == commit_after_batch_size) {
            timer.post(timer.context, 0, commitFired, self, commitDropped);
        }
    }

    fn commitFired(data: ?*anyopaque) void {
        const self: *CookiePersistence = @ptrCast(@alignCast(data orelse return));
        self.commit();
    }

    /// The loop ended first: the Browser's flush wrote the batch.
    fn commitDropped(data: ?*anyopaque) void {
        _ = data;
    }

    // ------------------------------------------------------------- commits

    /// Backend::Commit: everything queued, in one write transaction. On the
    /// window thread, never under the jar's lock.
    pub fn commit(self: *CookiePersistence) void {
        lock(&self.commit_mutex);
        defer unlock(&self.commit_mutex);
        // "Maybe an old timer fired or we are already Close()'ed": the
        // queue is taken whole, and a commit with nothing queued writes
        // nothing.
        var taken: std.StringHashMapUnmanaged(?[]u8) = .empty;
        var rewrite: ?[]Cookie = null;
        defer {
            var entries = taken.iterator();
            while (entries.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                if (entry.value_ptr.*) |record| self.allocator.free(record);
            }
            taken.deinit(self.allocator);
            if (rewrite) |cookies| freeCookies(self.allocator, cookies);
        }
        {
            self.jar.lock();
            defer self.jar.unlock();
            lock(&self.mutex);
            defer unlock(&self.mutex);
            taken = self.pending;
            self.pending = .empty;
            self.num_pending = 0;
            if (self.rewrite_all) {
                self.rewrite_all = false;
                rewrite = snapshot(self.allocator, self.jar) catch blk: {
                    // Not even the snapshot fits: the next commit tries again.
                    self.rewrite_all = true;
                    break :blk null;
                };
                if (rewrite == null) return;
            }
        }
        if (taken.count() == 0 and rewrite == null) return;
        self.write(&taken, rewrite) catch |err| {
            // DoCommit: the error is recorded, the operations are gone.
            log.warn("a cookie commit to the profile failed: {s}", .{@errorName(err)});
        };
    }

    /// What is queued, written now: the Browser's end (the cookie store's
    /// Flush), before its loop and its platform state end.
    pub fn flush(self: *CookiePersistence) void {
        self.commit();
    }

    fn write(self: *CookiePersistence, taken: *const std.StringHashMapUnmanaged(?[]u8), rewrite: ?[]const Cookie) platform.StoreError!void {
        const store = try platform.openStore(self.browser, platform.Str.from(store_name), .{});
        defer platform.closeStore(store);
        const transaction = try platform.beginTransaction(store, .write);
        self.writeAll(transaction, taken, rewrite) catch |err| {
            platform.abortTransaction(transaction);
            return err;
        };
        return platform.commitTransaction(transaction);
    }

    fn writeAll(self: *CookiePersistence, transaction: *platform.StoreTransaction, taken: *const std.StringHashMapUnmanaged(?[]u8), rewrite: ?[]const Cookie) platform.StoreError!void {
        if (rewrite) |cookies| {
            try platform.storeDeleteRange(transaction, .all);
            for (cookies) |*cookie| {
                const key = try recordKey(self.allocator, cookie);
                defer self.allocator.free(key);
                const record = try encode(self.allocator, cookie);
                defer self.allocator.free(record);
                try platform.storePut(transaction, platform.Bytes.from(key), platform.Bytes.from(record));
            }
        }
        var entries = taken.iterator();
        while (entries.next()) |entry| {
            const key = platform.Bytes.from(entry.key_ptr.*);
            if (entry.value_ptr.*) |record| {
                try platform.storePut(transaction, key, platform.Bytes.from(record));
            } else {
                try platform.storeDelete(transaction, key);
            }
        }
    }

    /// Copies of the jar's persistent cookies. Under the jar's lock.
    fn snapshot(allocator: std.mem.Allocator, jar: *const CookieJar) std.mem.Allocator.Error![]Cookie {
        var list: std.ArrayListUnmanaged(Cookie) = .empty;
        errdefer {
            for (list.items) |*cookie| cookie.deinit();
            list.deinit(allocator);
        }
        for (jar.cookies.items) |cookie| {
            if (cookie.isSession()) continue;
            var copy = try cookie.clone(allocator);
            errdefer copy.deinit();
            try list.append(allocator, copy);
        }
        return list.toOwnedSlice(allocator);
    }

    fn freeCookies(allocator: std.mem.Allocator, cookies: []Cookie) void {
        for (cookies) |*cookie| cookie.deinit();
        allocator.free(cookies);
    }
};

// ------------------------------------------------------------------ records

fn appendBytes(list: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, bytes: []const u8) std.mem.Allocator.Error!void {
    var len: [4]u8 = undefined;
    std.mem.writeInt(u32, &len, @intCast(bytes.len), .little);
    try list.appendSlice(allocator, &len);
    try list.appendSlice(allocator, bytes);
}

fn appendInt(list: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, value: i64) std.mem.Allocator.Error!void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(i64, &bytes, value, .little);
    try list.appendSlice(allocator, &bytes);
}

/// A cookie's record key: its identity (Cookie.hasSameIdentity), each part
/// length-prefixed - the partition key's site (or none), the domain in
/// lowercase (identity compares it ASCII case-insensitively), the host-only
/// flag, the path, the name. OWNED.
pub fn recordKey(allocator: std.mem.Allocator, cookie: *const Cookie) std.mem.Allocator.Error![]u8 {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);
    if (cookie.partition_key) |partition| {
        try list.append(allocator, 1);
        try appendBytes(&list, allocator, partition.top_level_site);
    } else try list.append(allocator, 0);
    const domain = cookie.domain orelse "";
    const lower = try std.ascii.allocLowerString(allocator, domain);
    defer allocator.free(lower);
    try appendBytes(&list, allocator, lower);
    try list.append(allocator, @intFromBool(cookie.host_only));
    try appendBytes(&list, allocator, cookie.path);
    try appendBytes(&list, allocator, cookie.name);
    return list.toOwnedSlice(allocator);
}

/// A persistent cookie's record. OWNED.
pub fn encode(allocator: std.mem.Allocator, cookie: *const Cookie) std.mem.Allocator.Error![]u8 {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);
    try list.append(allocator, record_version);
    try appendBytes(&list, allocator, cookie.name);
    try appendBytes(&list, allocator, cookie.value);
    try list.append(allocator, @intFromBool(cookie.domain != null));
    try appendBytes(&list, allocator, cookie.domain orelse "");
    try appendBytes(&list, allocator, cookie.path);
    try appendInt(&list, allocator, cookie.expiry_time orelse 0);
    try appendInt(&list, allocator, cookie.creation_time);
    try appendInt(&list, allocator, cookie.last_access_time);
    const flags: u8 = @as(u8, @intFromBool(cookie.secure)) |
        (@as(u8, @intFromBool(cookie.http_only)) << 1) |
        (@as(u8, @intFromBool(cookie.host_only)) << 2) |
        (@as(u8, @intFromBool(cookie.has_path)) << 3);
    try list.append(allocator, flags);
    try list.append(allocator, switch (cookie.same_site) {
        .strict => 0,
        .lax => 1,
        .none => 2,
        .unset => 3,
    });
    try list.append(allocator, @intFromBool(cookie.partition_key != null));
    try appendBytes(&list, allocator, if (cookie.partition_key) |partition| partition.top_level_site else "");
    return list.toOwnedSlice(allocator);
}

const Reader = struct {
    bytes: []const u8,
    at: usize = 0,

    fn byte(self: *Reader) error{Corrupt}!u8 {
        if (self.at >= self.bytes.len) return error.Corrupt;
        defer self.at += 1;
        return self.bytes[self.at];
    }

    fn int(self: *Reader) error{Corrupt}!i64 {
        if (self.bytes.len - self.at < 8) return error.Corrupt;
        defer self.at += 8;
        return std.mem.readInt(i64, self.bytes[self.at..][0..8], .little);
    }

    fn slice(self: *Reader) error{Corrupt}![]const u8 {
        if (self.bytes.len - self.at < 4) return error.Corrupt;
        const len = std.mem.readInt(u32, self.bytes[self.at..][0..4], .little);
        self.at += 4;
        if (self.bytes.len - self.at < len) return error.Corrupt;
        defer self.at += len;
        return self.bytes[self.at..][0..len];
    }
};

/// The persistent cookie a record holds, owning its parts (`allocator`).
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) error{ OutOfMemory, Corrupt }!Cookie {
    var reader: Reader = .{ .bytes = bytes };
    if (try reader.byte() != record_version) return error.Corrupt;
    const name = try reader.slice();
    const value = try reader.slice();
    const has_domain = try reader.byte() != 0;
    const domain = try reader.slice();
    const path = try reader.slice();
    const expiry = try reader.int();
    const creation = try reader.int();
    const last_access = try reader.int();
    const flags = try reader.byte();
    const same_site: SameSite = switch (try reader.byte()) {
        0 => .strict,
        1 => .lax,
        2 => .none,
        3 => .unset,
        else => return error.Corrupt,
    };
    const has_partition = try reader.byte() != 0;
    const partition = try reader.slice();
    if (reader.at != bytes.len or path.len == 0 or path[0] != '/') return error.Corrupt;

    var cookie: Cookie = .{
        .name = "",
        .value = "",
        .creation_time = creation,
        .last_access_time = last_access,
        .expiry_time = expiry,
        .secure = flags & 1 != 0,
        .http_only = flags & 2 != 0,
        .host_only = flags & 4 != 0,
        .has_path = flags & 8 != 0,
        .same_site = same_site,
        .allocator = allocator,
    };
    // Cookie.deinit frees what is set so far.
    errdefer cookie.deinit();
    cookie.name = try allocator.dupe(u8, name);
    cookie.value = try allocator.dupe(u8, value);
    if (has_domain) cookie.domain = try allocator.dupe(u8, domain);
    if (!std.mem.eql(u8, path, "/")) cookie.path = try allocator.dupe(u8, path);
    if (has_partition) cookie.partition_key = try PartitionKey.init(allocator, partition);
    return cookie;
}

// ==================================================================== tests

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

fn testCookie(name: []const u8, value: []const u8, max_age_ms: ?i64) !Cookie {
    var cookie = try Cookie.init(std.testing.allocator, name, value);
    errdefer cookie.deinit();
    try cookie.setDomain("example.test");
    if (max_age_ms) |age| cookie.expiry_time = clock.wallMillis() + age;
    return cookie;
}

test "a record holds every part of a cookie, and its key its identity" {
    const allocator = std.testing.allocator;
    var cookie = try testCookie("name", "value", 3_600_000);
    defer cookie.deinit();
    try cookie.setPath("/app");
    cookie.secure = true;
    cookie.http_only = true;
    cookie.host_only = false;
    cookie.has_path = true;
    cookie.same_site = .strict;
    try cookie.setPartitionKey(PartitionKey.initBorrowed("https://top.test"));

    const record = try encode(allocator, &cookie);
    defer allocator.free(record);
    var restored = try decode(allocator, record);
    defer restored.deinit();
    try std.testing.expectEqualStrings("name", restored.name);
    try std.testing.expectEqualStrings("value", restored.value);
    try std.testing.expectEqualStrings("example.test", restored.domain.?);
    try std.testing.expectEqualStrings("/app", restored.path);
    try std.testing.expectEqual(cookie.expiry_time, restored.expiry_time);
    try std.testing.expectEqual(cookie.creation_time, restored.creation_time);
    try std.testing.expect(restored.secure and restored.http_only and !restored.host_only and restored.has_path);
    try std.testing.expectEqual(SameSite.strict, restored.same_site);
    try std.testing.expectEqualStrings("https://top.test", restored.partition_key.?.top_level_site);
    try std.testing.expect(restored.hasSameIdentity(cookie));

    const key = try recordKey(allocator, &cookie);
    defer allocator.free(key);
    const restored_key = try recordKey(allocator, &restored);
    defer allocator.free(restored_key);
    try std.testing.expectEqualSlices(u8, key, restored_key);
    // A truncated record is corrupt, never a cookie.
    try std.testing.expectError(error.Corrupt, decode(allocator, record[0 .. record.len - 1]));
}

test "a jar on a profile: persistent cookies are written, session cookies never, expired ones swept at load" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const directory = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(directory);
    {
        const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
        defer platform.destroyBrowserPlatform(browser);
        var jar = CookieJar.init(testing.allocator);
        defer jar.deinit();
        // No timer: every batch waits for the flush.
        try jar.attachProfile(browser, null);
        var kept = try testCookie("kept", "1", 3_600_000);
        defer kept.deinit();
        var session = try testCookie("session", "2", null);
        defer session.deinit();
        var short = try testCookie("short", "3", 50);
        defer short.deinit();
        var gone = try testCookie("gone", "4", 3_600_000);
        defer gone.deinit();
        try jar.store(kept);
        try jar.store(session);
        try jar.store(short);
        try jar.store(gone);
        try testing.expectEqual(@as(usize, 1), jar.delete("gone", "example.test", "/"));
        jar.flush();
    }
    std.Io.sleep(testing.io, .fromMilliseconds(100), .awake) catch {};
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
    defer platform.destroyBrowserPlatform(browser);
    var jar = CookieJar.init(testing.allocator);
    defer jar.deinit();
    try jar.attachProfile(browser, null);
    // Only "kept": the session cookie was never written, "gone" deleted,
    // and "short" expired while no jar was open - its record swept.
    try testing.expectEqual(@as(usize, 1), jar.count());
    try testing.expectEqualStrings("kept", jar.cookies.items[0].name);
    const store = try platform.openStore(browser, platform.Str.from(store_name), .{});
    defer platform.closeStore(store);
    const transaction = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(transaction);
    const cursor = try platform.openCursor(transaction, .all, .forward);
    defer platform.closeCursor(cursor);
    var records: usize = 0;
    while (try platform.cursorNext(cursor, testing.allocator)) |record| {
        testing.allocator.free(record.key.slice());
        testing.allocator.free(record.value.slice());
        records += 1;
    }
    try testing.expectEqual(@as(usize, 1), records);
}
