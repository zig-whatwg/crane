//! A Browser's profile directory, as its local storage persists there (the
//! user's ruling D6, 2026-11-21: Puppeteer's and Playwright's
//! --user-data-dir fully supported; lane prof1). Made only for a Browser
//! given a profile directory (`UserAgentStorage.attachProfile`, from
//! src/browser/profile_stores.zig at Browser.init); a Browser with none has
//! no Profile and keeps every storage area in memory, exactly as before.
//!
//! localStorage: the store "local_storage" (docs/platform-protocol.md 6.6:
//! kit/sqlite under the profile), one record per item, keyed by the
//! area's storage key (StorageKey.serialize) ++ 0x00 ++ the item's key, so
//! an area's items are one key range. An area is read from it when its
//! shelf is first obtained (`load`), and its changes are written back in
//! batches, as Chromium's storage service commits (BSD; reproduced, not
//! copied - components/services/storage/dom_storage/storage_area_impl.cc
//! and local_storage_impl.cc, Copyright 2016 The Chromium Authors):
//!
//! - The in-memory map is the truth for script. A change records its key
//!   in the area's CommitBatch before the map changes (StorageAreaImpl::Put
//!   / Delete: CreateCommitBatchIfNeeded, then the key into `changed_keys`,
//!   then the map); clear() sets `clear_all_first` and forgets the keys
//!   (DeleteAll). A commit reads each changed key's value from the map then
//!   (CollectCommit): present, it is written; absent, deleted.
//! - The batch's creation arms its commit (StartCommitTimer) after
//!   ComputeCommitDelay: the largest of the default delay (local_storage_
//!   impl.cc kCommitDefaultDelaySecs, 5 s: "Delay for a moment after a value
//!   is set in anticipation of other values being set, so changes are
//!   batched") and what two rate limiters need - kMaxCommitsPerHour, 60, and
//!   kMaxBytesPerHour, one area's quota ("To avoid excessive IO we apply
//!   limits to the amount of data being written and the frequency of
//!   writes"; Chrome's is its kPerStorageAreaQuota, 10 MiB, Crane's the
//!   localStorage endpoint's quota, 5 MiB, Storage 4.5's registered
//!   endpoints), each over the hour since the area was made
//!   (StorageAreaImpl::RateLimiter).
//! - The Browser's end commits every pending batch at once
//!   (LocalStorageImpl::ShutDown: "Flush any uncommitted data", each area's
//!   ScheduleImmediateCommit): `flush`, from Browser.deinit, while the
//!   platform state lives.
//! - A failed commit drops its batch - the map keeps the values - and is
//!   reported (StorageAreaImpl::OnCommitComplete -> delegate DidCommit ->
//!   LocalStorageImpl::OnCommitResult): Crane logs it where Chrome records
//!   UMA, and counts consecutive failures; past kCommitErrorThreshold, 8
//!   (dom_storage_constants.h: "After this many consecutive commit errors
//!   we'll throw away the entire database"), the store is deleted and made
//!   again, once (tried_to_recover_from_commit_errors_), and a success
//!   resets the count. Chrome then drops its areas, which reload from the
//!   empty database; Crane rewrites every live area from its map instead,
//!   so a page keeps seeing what it stored, as a Chrome page does through
//!   its renderer's cached copy.
//! - A failed READ of an area detaches it from the store, as
//!   StorageAreaImpl::OnMapLoaded does ("nothing will be persisted"): the
//!   area lives for the Browser in memory, and it is logged.
//!
//! sessionStorage is not persisted: no browser gives it back after a
//! restart except through session restore, which headless Crane does not
//! do. Chromium keeps it on disk only for session restore and deletes, at
//! startup, every namespace no restored window claims
//! (components/services/storage/dom_storage/session_storage_impl.cc
//! SessionStorageImpl::ScavengeUnusedNamespaces; a namespace is protected
//! from the scavenge only when it is persisted for a window being
//! restored); Firefox restores it only with its session store's windows
//! (browser/components/sessionstore, SessionStore's per-tab storage
//! collection); Safari keeps it per page (WebKit's SessionStorageManager,
//! a namespace per WebPageProxy) and restores it only with the page's
//! session state. A traversable's shed ends with it
//! (standard.TraversableStorageSheds).
//!
//! THREADS: localStorage is [Exposed=Window]: an area is loaded, changed,
//! committed and flushed on its Browser's window thread only, and its
//! commit timer runs on that thread's loop.

const std = @import("std");
const platform = @import("platform");

const log = std.log.scoped(.profile_storage);

/// The store localStorage keeps its items in.
pub const local_storage_store = "local_storage";

/// local_storage_impl.cc kCommitDefaultDelaySecs.
pub const commit_default_delay_ms: u64 = 5 * std.time.ms_per_s;
/// local_storage_impl.cc kMaxCommitsPerHour.
pub const max_commits_per_hour: usize = 60;
/// dom_storage_constants.h kCommitErrorThreshold.
pub const commit_error_threshold: u32 = 8;
const hour_ms: i64 = std.time.ms_per_hour;

/// How the Browser's storage arms a commit on its event loop: the loop's
/// timers (runtime.TimerInterface.setTimeoutOwned), which this module
/// cannot name - runtime imports storage. src/browser/profile_stores.zig
/// makes one from the Browser's EventLoop.
pub const CommitTimer = struct {
    context: *anyopaque,
    /// The window thread only: run `run(data)` after `ms`, on the Browser's
    /// window thread, or `drop(data)` if the loop ends first. 0: nothing
    /// was armed (the caller still owns `data`).
    arm: *const fn (context: *anyopaque, ms: u64, run: *const fn (?*anyopaque) void, data: ?*anyopaque, drop: *const fn (?*anyopaque) void) u64,
    /// The window thread only: cancel `id`; true only when it will never
    /// run.
    cancel: *const fn (context: *anyopaque, id: u64) bool,
    /// Any thread of the Browser (a worker's fetch stores cookies): run
    /// `run(data)` on the window thread `ms` after the loop takes the post,
    /// or `drop(data)` - on any thread - if it never will. Takes `data`
    /// whatever happens; it cannot be cancelled.
    post: *const fn (context: *anyopaque, ms: u64, run: *const fn (?*anyopaque) void, data: ?*anyopaque, drop: *const fn (?*anyopaque) void) void,
};

/// StorageAreaImpl::RateLimiter: the time `samples` need at `rate` per
/// `quantum`, against the time elapsed. Chrome keeps the rate and the
/// samples as floats; so does this.
pub const RateLimiter = struct {
    rate: f32,
    samples: f32 = 0,
    quantum_ms: i64,

    pub fn init(desired_rate: usize, quantum_ms: i64) RateLimiter {
        // RateLimiter::RateLimiter: DCHECK_GT(desired_rate, 0ul).
        std.debug.assert(desired_rate > 0);
        return .{ .rate = @floatFromInt(desired_rate), .quantum_ms = quantum_ms };
    }

    pub fn addSamples(self: *RateLimiter, samples: usize) void {
        self.samples += @floatFromInt(samples);
    }

    /// ComputeTimeNeeded: time_quantum_ * (samples_ / rate_).
    pub fn timeNeededMs(self: RateLimiter) i64 {
        const needed = @as(f64, @floatFromInt(self.quantum_ms)) * @as(f64, self.samples / self.rate);
        return @intFromFloat(@min(needed, @as(f64, @floatFromInt(std.math.maxInt(i64) / 2))));
    }

    /// ComputeDelayNeeded: what is still needed after `elapsed_ms`, or 0.
    pub fn delayNeededMs(self: RateLimiter, elapsed_ms: i64) i64 {
        const needed = self.timeNeededMs();
        return if (needed > elapsed_ms) needed - elapsed_ms else 0;
    }
};

/// StorageAreaImpl::CommitBatch, keys and values mode: the keys changed
/// since the last commit, whose values the commit reads from the map.
const CommitBatch = struct {
    clear_all_first: bool = false,
    /// Every item of the map is written (after `clear_all_first`): a key
    /// that could not be recorded for lack of memory widens the batch to
    /// the whole area, so a change is never lost to the store. Crane's; a
    /// std::set insertion in Chrome cannot fail but by aborting.
    write_all: bool = false,
    /// OWNED keys.
    changed_keys: std.StringHashMapUnmanaged(void) = .empty,

    fn forgetKeys(self: *CommitBatch, allocator: std.mem.Allocator) void {
        var keys = self.changed_keys.keyIterator();
        while (keys.next()) |key| allocator.free(key.*);
        self.changed_keys.clearRetainingCapacity();
    }

    fn deinit(self: *CommitBatch, allocator: std.mem.Allocator) void {
        self.forgetKeys(allocator);
        self.changed_keys.deinit(allocator);
    }
};

/// One local storage area's link to the profile's store: a storage key's
/// localStorage bottle (Chrome's StorageAreaImpl for one StorageKey).
/// Owned by its Profile, which outlives the area's bottle and every timer
/// armed for it (the Browser's loop ends before its storage does).
pub const Area = struct {
    profile: *Profile,
    /// The area's records' key prefix: StorageKey.serialize ++ 0x00. OWNED.
    prefix: []u8,
    /// The bottle's map while the bottle lives; null once it has gone.
    map: ?*std.StringHashMap([]u8),
    /// StorageAreaImpl::start_time_.
    start_ms: i64,
    commit_rate: RateLimiter,
    data_rate: RateLimiter,
    batch: ?CommitBatch = null,
    /// The armed commit (0: none).
    timer_id: u64 = 0,

    /// The upper bound of the area's records, open: the prefix with its
    /// last byte, 0x00, raised to 0x01. OWNED.
    fn upperBound(self: *const Area) std.mem.Allocator.Error![]u8 {
        return std.mem.concat(self.profile.allocator, u8, &.{ self.prefix[0 .. self.prefix.len - 1], &.{0x01} });
    }

    /// A change of `key` is about to be made to the map: record it.
    pub fn recordKey(self: *Area, key: []const u8) void {
        const batch = self.batchIfNeeded();
        if (batch.write_all or batch.changed_keys.contains(key)) return;
        const allocator = self.profile.allocator;
        const owned = allocator.dupe(u8, key) catch return writeAllInstead(batch, allocator);
        batch.changed_keys.put(allocator, owned, {}) catch {
            allocator.free(owned);
            writeAllInstead(batch, allocator);
        };
    }

    /// The map is about to be cleared (StorageAreaImpl::DeleteAll).
    pub fn recordClear(self: *Area) void {
        const batch = self.batchIfNeeded();
        batch.clear_all_first = true;
        batch.write_all = false;
        batch.forgetKeys(self.profile.allocator);
    }

    fn writeAllInstead(batch: *CommitBatch, allocator: std.mem.Allocator) void {
        batch.clear_all_first = true;
        batch.write_all = true;
        batch.forgetKeys(allocator);
    }

    /// StorageAreaImpl::CreateCommitBatchIfNeeded: a new batch arms its
    /// commit.
    fn batchIfNeeded(self: *Area) *CommitBatch {
        if (self.batch == null) {
            self.batch = .{};
            self.startCommitTimer();
        }
        return &self.batch.?;
    }

    /// StorageAreaImpl::ComputeCommitDelay.
    pub fn commitDelayMs(self: *const Area) u64 {
        const elapsed = platform.monotonicMillis() - self.start_ms;
        const limited = @max(self.commit_rate.delayNeededMs(elapsed), self.data_rate.delayNeededMs(elapsed));
        return @max(commit_default_delay_ms, @as(u64, @intCast(limited)));
    }

    /// StorageAreaImpl::StartCommitTimer. With no timer to arm on (a
    /// Browser whose loop has none), the batch waits for the next flush.
    fn startCommitTimer(self: *Area) void {
        if (self.batch == null or self.timer_id != 0) return;
        const timer = self.profile.timer orelse return;
        self.timer_id = timer.arm(timer.context, self.commitDelayMs(), commitTimerFired, self, commitTimerDropped);
    }

    fn commitTimerFired(data: ?*anyopaque) void {
        const self: *Area = @ptrCast(@alignCast(data orelse return));
        self.timer_id = 0;
        self.commitChanges();
    }

    /// The loop ended with the commit armed: Browser.deinit flushed first,
    /// so nothing is left to write.
    fn commitTimerDropped(data: ?*anyopaque) void {
        const self: *Area = @ptrCast(@alignCast(data orelse return));
        self.timer_id = 0;
    }

    /// StorageAreaImpl::CommitChanges and CollectCommit, and the database's
    /// write: the batch's changes, in one write transaction; its result is
    /// the Profile's to judge (OnCommitComplete -> DidCommit).
    pub fn commitChanges(self: *Area) void {
        var batch = self.batch orelse return;
        self.batch = null;
        defer batch.deinit(self.profile.allocator);
        // Its bottle has gone: nothing is left to write.
        const map = self.map orelse return;
        self.commit_rate.addSamples(1);
        var data_size: usize = 0;
        const result = self.write(map, &batch, &data_size);
        self.data_rate.addSamples(data_size);
        self.profile.onCommitResult(result);
    }

    fn write(self: *Area, map: *std.StringHashMap([]u8), batch: *const CommitBatch, data_size: *usize) platform.StoreError!void {
        const browser = self.profile.browser;
        const store = try platform.openStore(browser, platform.Str.from(local_storage_store), .{});
        defer platform.closeStore(store);
        const transaction = try platform.beginTransaction(store, .write);
        self.writeBatch(transaction, map, batch, data_size) catch |err| {
            platform.abortTransaction(transaction);
            return err;
        };
        // Ends the transaction, committed or not.
        return platform.commitTransaction(transaction);
    }

    fn writeBatch(self: *Area, transaction: *platform.StoreTransaction, map: *std.StringHashMap([]u8), batch: *const CommitBatch, data_size: *usize) platform.StoreError!void {
        const allocator = self.profile.allocator;
        if (batch.clear_all_first) {
            const upper = try self.upperBound();
            defer allocator.free(upper);
            try platform.storeDeleteRange(transaction, .{
                .lower = platform.Bytes.from(self.prefix),
                .has_lower = true,
                .upper = platform.Bytes.from(upper),
                .has_upper = true,
                .upper_open = true,
            });
        }
        if (batch.write_all) {
            var items = map.iterator();
            while (items.next()) |item| try self.putItem(transaction, item.key_ptr.*, item.value_ptr.*, data_size);
            return;
        }
        var keys = batch.changed_keys.keyIterator();
        while (keys.next()) |key| {
            if (map.get(key.*)) |value| {
                try self.putItem(transaction, key.*, value, data_size);
            } else {
                const record_key = try std.mem.concat(allocator, u8, &.{ self.prefix, key.* });
                defer allocator.free(record_key);
                data_size.* += key.len;
                try platform.storeDelete(transaction, platform.Bytes.from(record_key));
            }
        }
    }

    fn putItem(self: *Area, transaction: *platform.StoreTransaction, key: []const u8, value: []const u8, data_size: *usize) platform.StoreError!void {
        const record_key = try std.mem.concat(self.profile.allocator, u8, &.{ self.prefix, key });
        defer self.profile.allocator.free(record_key);
        data_size.* += key.len + value.len;
        try platform.storePut(transaction, platform.Bytes.from(record_key), platform.Bytes.from(value));
    }

    /// Commit at once whatever is pending (ScheduleImmediateCommit).
    pub fn commitNow(self: *Area) void {
        if (self.timer_id != 0) {
            const timer = self.profile.timer.?;
            // A timer that may still run finds no batch.
            if (timer.cancel(timer.context, self.timer_id)) self.timer_id = 0;
        }
        self.commitChanges();
    }

    /// The bottle is going (its shelf's end): the area keeps nothing of it.
    /// Never a commit here - a bottle ends at its Browser's end, after the
    /// flush and after the platform state.
    pub fn detachMap(self: *Area) void {
        self.map = null;
        if (self.batch) |*batch| batch.deinit(self.profile.allocator);
        self.batch = null;
    }

    fn destroy(self: *Area) void {
        if (self.batch) |*batch| batch.deinit(self.profile.allocator);
        self.profile.allocator.free(self.prefix);
        self.profile.allocator.destroy(self);
    }
};

/// The Browser's profile, for its local storage: the BrowserPlatform whose
/// stores are under the directory, the timers commits arm on, and every
/// area read from it.
pub const Profile = struct {
    allocator: std.mem.Allocator,
    /// BORROWED: the Browser's platform state, which outlives every commit
    /// (Browser.deinit flushes before it ends it).
    browser: *platform.BrowserPlatform,
    timer: ?CommitTimer,
    areas: std.ArrayListUnmanaged(*Area) = .empty,
    /// LocalStorageImpl::commit_error_count_.
    commit_error_count: u32 = 0,
    /// LocalStorageImpl::tried_to_recover_from_commit_errors_.
    tried_to_recover: bool = false,

    pub fn create(allocator: std.mem.Allocator, browser: *platform.BrowserPlatform, timer: ?CommitTimer) std.mem.Allocator.Error!*Profile {
        const self = try allocator.create(Profile);
        self.* = .{ .allocator = allocator, .browser = browser, .timer = timer };
        return self;
    }

    /// With the Browser's storage, after its loop ended (no timer is armed)
    /// and after its platform state ended: nothing here touches a store.
    pub fn destroy(self: *Profile) void {
        for (self.areas.items) |area| area.destroy();
        self.areas.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// The area of `serialized_key` (a storage key's serialization) for the
    /// bottle map `map`, its items read from the store into the map, which
    /// is empty. Null when the read failed (StorageAreaImpl::OnMapLoaded's
    /// failure): the area is then the Browser's in memory alone, and logged.
    pub fn load(self: *Profile, serialized_key: []const u8, map: *std.StringHashMap([]u8), quota: u64) std.mem.Allocator.Error!?*Area {
        const prefix = try std.mem.concat(self.allocator, u8, &.{ serialized_key, &.{0x00} });
        errdefer self.allocator.free(prefix);
        try self.areas.ensureUnusedCapacity(self.allocator, 1);
        const area = try self.allocator.create(Area);
        errdefer self.allocator.destroy(area);
        area.* = .{
            .profile = self,
            .prefix = prefix,
            .map = map,
            .start_ms = platform.monotonicMillis(),
            .commit_rate = .init(max_commits_per_hour, hour_ms),
            .data_rate = .init(@intCast(quota), hour_ms),
        };
        self.readInto(area, map) catch |err| {
            clearMap(map);
            if (err == error.OutOfMemory) return error.OutOfMemory;
            log.err("localStorage of {s} could not be read from the profile ({s}): it is kept in memory for this Browser only, as Chrome's StorageAreaImpl::OnMapLoaded detaches an area it cannot read", .{ serialized_key, @errorName(err) });
            self.allocator.free(prefix);
            self.allocator.destroy(area);
            return null;
        };
        self.areas.appendAssumeCapacity(area);
        return area;
    }

    fn clearMap(map: *std.StringHashMap([]u8)) void {
        var items = map.iterator();
        while (items.next()) |item| {
            map.allocator.free(item.key_ptr.*);
            map.allocator.free(item.value_ptr.*);
        }
        map.clearRetainingCapacity();
    }

    fn readInto(self: *Profile, area: *const Area, map: *std.StringHashMap([]u8)) platform.StoreError!void {
        const upper = try area.upperBound();
        defer self.allocator.free(upper);
        const store = try platform.openStore(self.browser, platform.Str.from(local_storage_store), .{});
        defer platform.closeStore(store);
        const transaction = try platform.beginTransaction(store, .read);
        // A read transaction commits nothing: its end.
        defer platform.abortTransaction(transaction);
        const cursor = try platform.openCursor(transaction, .{
            .lower = platform.Bytes.from(area.prefix),
            .has_lower = true,
            .upper = platform.Bytes.from(upper),
            .has_upper = true,
            .upper_open = true,
        }, .forward);
        defer platform.closeCursor(cursor);
        // The map's own allocator owns its keys and values.
        const map_allocator = map.allocator;
        while (try platform.cursorNext(cursor, map_allocator)) |record| {
            const record_key = record.key.slice();
            defer map_allocator.free(record_key);
            const value = record.value.slice();
            errdefer map_allocator.free(value);
            const key = try map_allocator.dupe(u8, record_key[area.prefix.len..]);
            errdefer map_allocator.free(key);
            try map.putNoClobber(key, @constCast(value));
        }
    }

    /// LocalStorageImpl::ShutDown and Flush: every area's pending batch,
    /// committed now (ScheduleImmediateCommit). Browser.deinit's, before
    /// its loop and its platform state end.
    pub fn flush(self: *Profile) void {
        for (self.areas.items) |area| area.commitNow();
    }

    /// LocalStorageImpl::OnCommitResult.
    fn onCommitResult(self: *Profile, result: platform.StoreError!void) void {
        if (result) |_| {
            self.commit_error_count = 0;
            return;
        } else |err| {
            log.warn("a localStorage commit to the profile failed: {s} (consecutive failures: {d})", .{ @errorName(err), self.commit_error_count + 1 });
            self.commit_error_count += 1;
            if (self.commit_error_count <= commit_error_threshold) return;
            // "there isn't really anything left to try, so" the errors
            // are ignored.
            if (self.tried_to_recover) return;
            self.tried_to_recover = true;
            self.deleteAndRecreate();
        }
    }

    /// LocalStorageImpl::DeleteAndRecreateDatabase (kCommitErrorThreshold
    /// exceeded): the store goes and is made again on its next open; every
    /// live area is written to it whole, from its map (see the file's
    /// comment for how this differs from Chrome's dropped areas).
    fn deleteAndRecreate(self: *Profile) void {
        log.err("more than {d} consecutive localStorage commits failed: the profile's store is deleted and made again", .{commit_error_threshold});
        self.commit_error_count = 0;
        platform.deleteStore(self.browser, platform.Str.from(local_storage_store)) catch |err| switch (err) {
            error.NotFound => {},
            else => log.err("deleting the profile's localStorage store failed: {s}", .{@errorName(err)}),
        };
        for (self.areas.items) |area| {
            if (area.map == null) continue;
            const batch = area.batchIfNeeded();
            Area.writeAllInstead(batch, self.allocator);
        }
    }
};

test "RateLimiter: the time samples need at their rate, less what has elapsed" {
    var commits = RateLimiter.init(max_commits_per_hour, hour_ms);
    try std.testing.expectEqual(@as(i64, 0), commits.delayNeededMs(0));
    // One commit needs a minute of the hour.
    commits.addSamples(1);
    try std.testing.expectEqual(@as(i64, std.time.ms_per_min), commits.timeNeededMs());
    try std.testing.expectEqual(@as(i64, std.time.ms_per_min - 1000), commits.delayNeededMs(1000));
    try std.testing.expectEqual(@as(i64, 0), commits.delayNeededMs(2 * std.time.ms_per_min));
    // A whole quota written needs the whole hour.
    var bytes = RateLimiter.init(1024, hour_ms);
    bytes.addSamples(1024);
    try std.testing.expectEqual(hour_ms, bytes.timeNeededMs());
}

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

test "localStorage areas read from and flush to a profile directory; a store is touched only with a profile" {
    const testing = std.testing;
    const standard = @import("standard.zig");
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const directory = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(directory);
    const key = standard.StorageKey.initBorrowed("https://example.test", "https://example.test", false);
    const other = standard.StorageKey.initBorrowed("https://other.test", "https://other.test", false);
    {
        const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
        defer platform.destroyBrowserPlatform(browser);
        var user_agent_storage = standard.UserAgentStorage.init(testing.allocator);
        defer user_agent_storage.deinit();
        // No timer: every batch waits for the flush.
        try user_agent_storage.attachProfile(browser, null);
        const map = (try standard.obtainLocalStorageBottleMap(&user_agent_storage, key, .localStorage)).?;
        try map.set("a", "1");
        try map.set("b", "2");
        try map.set("b", "3");
        try testing.expect(map.delete("a"));
        try map.set("gone", "x");
        _ = map.delete("gone");
        const area = map.area.?;
        try testing.expect(area.batch != null);
        const elsewhere = (try standard.obtainLocalStorageBottleMap(&user_agent_storage, other, .localStorage)).?;
        try elsewhere.set("b", "other");
        user_agent_storage.flushProfile();
        try testing.expect(area.batch == null);
        // A cleared area, then one item: committed as one batch.
        elsewhere.clear();
        try elsewhere.set("c", "4");
        user_agent_storage.flushProfile();
    }
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
    defer platform.destroyBrowserPlatform(browser);
    var user_agent_storage = standard.UserAgentStorage.init(testing.allocator);
    defer user_agent_storage.deinit();
    try user_agent_storage.attachProfile(browser, null);
    const map = (try standard.obtainLocalStorageBottleMap(&user_agent_storage, key, .localStorage)).?;
    try testing.expectEqual(@as(usize, 1), map.count());
    try testing.expectEqualStrings("3", map.get("b").?);
    const elsewhere = (try standard.obtainLocalStorageBottleMap(&user_agent_storage, other, .localStorage)).?;
    try testing.expectEqual(@as(usize, 1), elsewhere.count());
    try testing.expectEqualStrings("4", elsewhere.get("c").?);

    // Without a profile, nothing records: the map is all there is.
    var in_memory = standard.UserAgentStorage.init(testing.allocator);
    defer in_memory.deinit();
    const memory_map = (try standard.obtainLocalStorageBottleMap(&in_memory, key, .localStorage)).?;
    try memory_map.set("k", "v");
    try testing.expect(memory_map.area == null);
    try testing.expect(in_memory.profile == null);
}

test "the commit delay: Chrome's 5 s default, longer once the commit rate limit needs it" {
    var area: Area = .{
        .profile = undefined,
        .prefix = &.{},
        .map = null,
        .start_ms = platform.monotonicMillis(),
        .commit_rate = .init(max_commits_per_hour, hour_ms),
        .data_rate = .init(5 * 1024 * 1024, hour_ms),
    };
    try std.testing.expectEqual(commit_default_delay_ms, area.commitDelayMs());
    // Thirty commits at once need half an hour: the next waits for it.
    area.commit_rate.addSamples(30);
    try std.testing.expect(area.commitDelayMs() > 29 * std.time.ms_per_min);
}
