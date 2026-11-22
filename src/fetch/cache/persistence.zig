//! The HTTP cache's persistence in a Browser's profile directory (the
//! user's ruling D6, 2026-11-21; lane prof1, D6 step 5). Only a Browser
//! given a profile directory has one (`HttpCache.attachProfile`, from
//! src/browser/profile_stores.zig at Browser.init); without one the cache
//! is in memory alone, exactly as before.
//!
//! The memory cache (http_cache.zig) stays what it is - its map, its LRU,
//! its caps - and the profile's store "http_cache" (docs/platform-protocol.md
//! 6.6, kit/sqlite) keeps a second level under it, as Chromium's profile
//! keeps its disk cache (BSD; reproduced, not copied - net/disk_cache/simple/
//! simple_index.cc, net/disk_cache/cache_util.cc, Copyright The Chromium
//! Authors):
//!
//! - An INDEX in memory of every response on disk: its size and when it
//!   was last used, in whole seconds (SimpleIndex's EntryMetadata,
//!   SetLastUsedTime), read from small index records when the Browser
//!   starts - never the responses themselves.
//! - A response is read from the store when the memory cache misses and the
//!   index has it, and kept in memory from then on.
//! - What the memory cache stores, and what it invalidates, is queued and
//!   handed over as one batch as soon as the Browser's loop runs a task, and
//!   at the Browser's end; the Browser's storage sequence writes it in one
//!   transaction (storage.StorageSequence; lane prof2): Chromium writes its
//!   disk cache off the requesting path, on the cache's own sequence
//!   (net/disk_cache/simple/simple_backend_impl.cc), never on the thread
//!   that stored the response.
//! - A batch handed over and not yet written is kept IN FLIGHT: a read finds
//!   a response there before it looks in the store, so a read never waits
//!   for the sequence and never misses a write it has not yet made (Chrome's
//!   simple cache answers an entry with a write pending from the entry's
//!   operation queue, never from a disk that lacks it).
//! - The disk cap is Chromium's PreferredCacheSize for an HTTP disk cache:
//!   80 MiB (kDefaultCacheSize) scaled by 400% off Windows, chosen from the
//!   free space of the profile's volume (PreferredCacheSizeInternal), never
//!   over four times the scaled default nor a fifth of the free space.
//! - Eviction is SimpleIndex's: once the disk holds more than its high
//!   watermark (the cap less a twentieth, kEvictionMarginDivisor 20), the
//!   responses with the highest (seconds since last use) x (size + 512,
//!   kEstimatedEntryOverhead) go until it is down to the low watermark (the
//!   cap less two twentieths) - old and large first.
//!
//! Layout, keys in byte order, a response's key being its cache key -
//! (partition length u32 BE, partition, credentialed u8, URL):
//!   0x01 key   its index record: size u64 BE, last used u32 BE (seconds)
//!   0x02 key   the response (`encode`)
//!
//! THREADS: the memory cache serves every thread of its Browser; this is
//! called after its lock is released, never under it, and guards its index,
//! its queue and its batches in flight with `mutex`. A commit takes the
//! queue on the Browser's window thread (the commit timer's task, the
//! Browser's end); the batch is written on the storage sequence, which then
//! takes `mutex` to retire it - never while another thread holds `mutex`
//! and waits for the sequence (nothing here waits for it).

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const storage = @import("storage");
const Job = storage.sequence.Job;
const stored_response = @import("stored_response.zig");
const StoredResponse = stored_response.StoredResponse;
const Header = stored_response.Header;
const content_coding = @import("../content_coding/root.zig");

const log = std.log.scoped(.http_cache_persistence);

pub const store_name = "http_cache";

const mib: u64 = 1024 * 1024;
/// cache_util.cc kDefaultCacheSize.
pub const default_cache_size: u64 = 80 * mib;
/// cache_util.cc PreferredCacheSize: an HTTP disk cache's
/// percent_relative_size, 400 on every platform but Windows - Crane builds
/// none for Windows.
const percent_relative_size: u64 = 400;
/// simple_index.cc kEvictionMarginDivisor.
const eviction_margin_divisor: u64 = 20;
/// simple_index.cc kEstimatedEntryOverhead.
const estimated_entry_overhead: u64 = 512;

/// cache_util.cc PreferredCacheSizeInternal.
fn preferredCacheSizeInternal(available: u64) u64 {
    // "Return 80% of the available space if there is not enough space to
    // use kDefaultCacheSize."
    if (available < default_cache_size * 10 / 8) return available * 8 / 10;
    // "Return kDefaultCacheSize if it uses 10% to 80% of the available space."
    if (available < default_cache_size * 10) return default_cache_size;
    // "Return 10% of the available space if the target size (2.5 *
    // kDefaultCacheSize) is more than 10%."
    if (available < default_cache_size * 25) return available / 10;
    // "Return the target size (2.5 * kDefaultCacheSize) if it uses 10% to 1%
    // of the available space."
    if (available < default_cache_size * 250) return default_cache_size * 5 / 2;
    // "Return 1% of the available space."
    return available / 100;
}

/// cache_util.cc PreferredCacheSize for an HTTP disk cache, given the
/// profile volume's free space (null: unknown - the scaled default).
pub fn preferredCacheSize(available: ?u64) u64 {
    const scaled_default = default_cache_size * percent_relative_size / 100;
    var preferred = scaled_default;
    if (available) |free| {
        preferred = preferredCacheSizeInternal(free);
        if (preferred < free / 5) preferred = @min(preferred * percent_relative_size / 100, free / 5);
    }
    return @min(preferred, scaled_default * 4);
}

const IndexEntry = struct {
    size: u64,
    /// Seconds since the epoch; never 0 (SetLastUsedTime: 0 is "null").
    last_used: u32,
};

/// What a commit writes for a key.
const Pending = union(enum) {
    /// The response, and its index record (a reference held).
    put: *StoredResponse,
    /// The index record alone: the response was used.
    touch,
    /// Both records go.
    delete,
};

fn nowSeconds() u32 {
    const seconds = platform.wallSeconds();
    return if (seconds <= 1) 1 else @intCast(@min(seconds, std.math.maxInt(u32)));
}

pub const Persistence = struct {
    allocator: Allocator,
    /// BORROWED: the Browser's platform state, which outlives every commit.
    browser: *platform.BrowserPlatform,
    timer: ?storage.profile.CommitTimer,
    max_bytes: u64,
    /// Guards everything below.
    mutex: std.Io.Mutex = .init,
    /// By cache key (OWNED keys). Responses come and go - evicted,
    /// invalidated - so its tombstones are rehashed away (infra.tombstones).
    index: std.StringHashMapUnmanaged(IndexEntry) = .empty,
    index_guard: @import("infra").tombstones.TombstoneGuard = .{},
    disk_bytes: u64 = 0,
    /// By cache key (OWNED keys).
    pending: std.StringHashMapUnmanaged(Pending) = .empty,
    commit_posted: bool = false,
    /// The batches handed to the storage sequence and not yet written,
    /// oldest first: a read looks in them, newest first, after `pending`.
    in_flight: std.ArrayListUnmanaged(*Batch) = .empty,
    /// BORROWED: the Browser's storage sequence, which writes every batch
    /// and stops before this ends (profile_stores.flush).
    sequence: *storage.StorageSequence,

    /// The persistence of a profile whose volume has `available` bytes free
    /// (null: unknown), its index read from the store, its batches written
    /// on `sequence`. `allocator` must be thread-safe: a batch is freed on
    /// the sequence.
    pub fn create(allocator: Allocator, browser: *platform.BrowserPlatform, timer: ?storage.profile.CommitTimer, sequence: *storage.StorageSequence, available: ?u64) Allocator.Error!*Persistence {
        const self = try allocator.create(Persistence);
        self.* = .{ .allocator = allocator, .browser = browser, .timer = timer, .sequence = sequence, .max_bytes = preferredCacheSize(available) };
        self.loadIndex() catch |err| switch (err) {
            error.OutOfMemory => {
                self.destroy();
                return error.OutOfMemory;
            },
            else => log.err("the profile's HTTP cache index could not be read ({s}); it starts empty", .{@errorName(err)}),
        };
        return self;
    }

    /// With the memory cache's close, after the Browser's flush, its
    /// storage sequence's stop (every batch written) and its platform
    /// state's end: nothing is written here.
    pub fn destroy(self: *Persistence) void {
        std.debug.assert(self.in_flight.items.len == 0);
        self.in_flight.deinit(self.allocator);
        var keys = self.index.keyIterator();
        while (keys.next()) |key| self.allocator.free(key.*);
        self.index.deinit(self.allocator);
        self.dropPending(&self.pending);
        self.allocator.destroy(self);
    }

    fn dropPending(self: *Persistence, pending: *std.StringHashMapUnmanaged(Pending)) void {
        var entries = pending.iterator();
        while (entries.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.* == .put) entry.value_ptr.put.release();
        }
        pending.deinit(self.allocator);
        pending.* = .empty;
    }

    fn lock(self: *Persistence) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *Persistence) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    // ------------------------------------------------------------ the index

    fn loadIndex(self: *Persistence) platform.StoreError!void {
        const store = try platform.openStore(self.browser, platform.Str.from(store_name), .{});
        defer platform.closeStore(store);
        const transaction = try platform.beginTransaction(store, .read);
        defer platform.abortTransaction(transaction);
        const cursor = try platform.openCursor(transaction, .{
            .lower = platform.Bytes.from(&.{0x01}),
            .has_lower = true,
            .upper = platform.Bytes.from(&.{0x02}),
            .has_upper = true,
            .upper_open = true,
        }, .forward);
        defer platform.closeCursor(cursor);
        while (try platform.cursorNext(cursor, self.allocator)) |record| {
            const full = record.key.slice();
            defer self.allocator.free(full);
            defer self.allocator.free(record.value.slice());
            const value = record.value.slice();
            if (value.len != 12) continue;
            const key = try self.allocator.dupe(u8, full[1..]);
            const entry: IndexEntry = .{
                .size = std.mem.readInt(u64, value[0..8], .big),
                .last_used = @max(1, std.mem.readInt(u32, value[8..12], .big)),
            };
            self.index_guard.beforeInsert(&self.index);
            const slot = self.index.getOrPut(self.allocator, key) catch |err| {
                self.allocator.free(key);
                return err;
            };
            if (slot.found_existing) {
                self.allocator.free(key);
                continue;
            }
            slot.value_ptr.* = entry;
            self.disk_bytes += entry.size;
        }
        // A smaller cap than the last Browser's (less free space now).
        self.lock();
        defer self.unlock();
        self.evictIfNeeded();
    }

    // ------------------------------------------------------------ recording

    /// The memory cache stored `entry` (the reference is taken).
    pub fn recordPut(self: *Persistence, entry: *StoredResponse) void {
        const key = cacheKey(self.allocator, entry.partition, entry.url, entry.credentialed) catch return entry.release();
        defer self.allocator.free(key);
        const size: u64 = entry.size;
        // Over the cap on its own: never on disk, as Chromium's backend
        // refuses an entry over its MaxFileSize.
        if (size > self.max_bytes / 8) {
            entry.release();
            return self.recordDelete(entry.partition, entry.url, entry.credentialed);
        }
        self.lock();
        defer self.unlock();
        self.queue(key, .{ .put = entry }) catch return;
        self.setIndex(key, .{ .size = size, .last_used = nowSeconds() }) catch {};
        self.evictIfNeeded();
    }

    /// The memory cache removed (`partition`, `url`, `credentialed`).
    pub fn recordDelete(self: *Persistence, partition: []const u8, url: []const u8, credentialed: bool) void {
        const key = cacheKey(self.allocator, partition, url, credentialed) catch return;
        defer self.allocator.free(key);
        self.lock();
        defer self.unlock();
        self.deleteLocked(key);
    }

    /// Every response whose URL `matches` (Clear Site Data's cache type).
    pub fn deleteMatching(self: *Persistence, context: anytype, comptime matches: fn (@TypeOf(context), []const u8) bool) void {
        self.lock();
        defer self.unlock();
        var doomed: std.ArrayListUnmanaged([]const u8) = .empty;
        defer doomed.deinit(self.allocator);
        var keys = self.index.keyIterator();
        while (keys.next()) |key| {
            const parts = splitKey(key.*) orelse continue;
            if (!matches(context, parts.url)) continue;
            doomed.append(self.allocator, key.*) catch break;
        }
        for (doomed.items) |key| self.deleteLocked(key);
    }

    /// Under the lock: `key` leaves the index and the disk.
    fn deleteLocked(self: *Persistence, key: []const u8) void {
        // A key never written needs no delete; one queued to be written
        // does (its put is dropped by the queue). Queued first: `key` may
        // be the index's own copy, freed below.
        if (!self.index.contains(key) and !self.pending.contains(key)) return;
        self.queue(key, .delete) catch {};
        if (self.index.fetchRemove(key)) |removed| {
            self.index_guard.noteRemoval(&self.index);
            self.disk_bytes -= removed.value.size;
            self.allocator.free(removed.key);
        }
    }

    /// Under the lock: `key`'s index entry.
    fn setIndex(self: *Persistence, key: []const u8, entry: IndexEntry) Allocator.Error!void {
        if (self.index.getPtr(key)) |existing| {
            self.disk_bytes = self.disk_bytes - existing.size + entry.size;
            existing.* = entry;
            return;
        }
        const owned = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned);
        self.index_guard.beforeInsert(&self.index);
        try self.index.put(self.allocator, owned, entry);
        self.disk_bytes += entry.size;
    }

    /// Under the lock: queue `what` for `key`, the batch's first operation
    /// posting its commit. A queued put a later operation replaces is
    /// released; a touch never replaces a put.
    fn queue(self: *Persistence, key: []const u8, what: Pending) Allocator.Error!void {
        // The key copied first, so the map never holds a slot it cannot
        // fill (and is never removed from: commits take it whole).
        const owned = self.allocator.dupe(u8, key) catch |err| {
            if (what == .put) what.put.release();
            return err;
        };
        const slot = self.pending.getOrPut(self.allocator, owned) catch |err| {
            self.allocator.free(owned);
            if (what == .put) what.put.release();
            return err;
        };
        if (slot.found_existing) {
            self.allocator.free(owned);
            if (what == .touch and slot.value_ptr.* == .put) return;
            if (slot.value_ptr.* == .put) slot.value_ptr.put.release();
        }
        slot.value_ptr.* = what;
        if (!self.commit_posted) {
            if (self.timer) |timer| {
                self.commit_posted = true;
                timer.post(timer.context, 0, commitFired, self, commitDropped);
            }
        }
    }

    /// Under the lock: SimpleIndex::StartEvictionIfNeeded.
    fn evictIfNeeded(self: *Persistence) void {
        const high = self.max_bytes - self.max_bytes / eviction_margin_divisor;
        const low = self.max_bytes - 2 * (self.max_bytes / eviction_margin_divisor);
        if (self.disk_bytes <= high) return;
        const amount = self.disk_bytes - low;
        const Candidate = struct { key: []const u8, score: u64 };
        var candidates: std.ArrayListUnmanaged(Candidate) = .empty;
        defer candidates.deinit(self.allocator);
        candidates.ensureTotalCapacity(self.allocator, self.index.count()) catch return;
        const now = nowSeconds();
        var entries = self.index.iterator();
        while (entries.next()) |entry| {
            const age: u64 = now -| entry.value_ptr.last_used;
            candidates.appendAssumeCapacity(.{ .key = entry.key_ptr.*, .score = age *| (entry.value_ptr.size + estimated_entry_overhead) });
        }
        std.mem.sort(Candidate, candidates.items, {}, struct {
            fn moreEvictable(_: void, a: Candidate, b: Candidate) bool {
                return a.score > b.score;
            }
        }.moreEvictable);
        var evicted: u64 = 0;
        for (candidates.items) |candidate| {
            if (evicted >= amount) break;
            const size = self.index.get(candidate.key).?.size;
            evicted += size;
            self.deleteLocked(candidate.key);
        }
    }

    // -------------------------------------------------------------- reading

    /// The response the profile has for the key, made with `allocator`
    /// (its one reference the caller's); null when the disk has none. A
    /// response queued to be written answers from the queue.
    pub fn load(self: *Persistence, allocator: Allocator, partition: []const u8, url: []const u8, credentialed: bool) ?*StoredResponse {
        const key = cacheKey(self.allocator, partition, url, credentialed) catch return null;
        defer self.allocator.free(key);
        {
            self.lock();
            defer self.unlock();
            if (self.queuedLocked(key)) |what| switch (what) {
                .put => |entry| {
                    entry.retain();
                    return entry;
                },
                .delete => return null,
                .touch => {},
            };
            if (!self.index.contains(key)) return null;
        }
        const record = self.read(key) catch |err| {
            log.warn("a stored response could not be read from the profile ({s}); it is dropped", .{@errorName(err)});
            self.recordDelete(partition, url, credentialed);
            return null;
        } orelse {
            self.recordDelete(partition, url, credentialed);
            return null;
        };
        defer self.allocator.free(record);
        const entry = decode(allocator, record) catch |err| {
            if (err != error.OutOfMemory) {
                log.warn("a stored response of the profile is corrupt; it is dropped", .{});
                self.recordDelete(partition, url, credentialed);
            }
            return null;
        };
        self.touch(key);
        return entry;
    }

    /// A memory hit used (`partition`, `url`, `credentialed`): its last use,
    /// in the index (SimpleIndex::UseIfExists).
    pub fn recordUse(self: *Persistence, partition: []const u8, url: []const u8, credentialed: bool) void {
        const key = cacheKey(self.allocator, partition, url, credentialed) catch return;
        defer self.allocator.free(key);
        self.touch(key);
    }

    /// Under the lock: what is queued or in flight for `key`, newest first -
    /// the queue, then the batches in flight from the last handed over. A
    /// touch alone says nothing of the response: the next older one, or the
    /// store, does.
    fn queuedLocked(self: *Persistence, key: []const u8) ?Pending {
        if (self.pending.get(key)) |what| if (what != .touch) return what;
        var i = self.in_flight.items.len;
        while (i > 0) {
            i -= 1;
            if (self.in_flight.items[i].taken.get(key)) |what| if (what != .touch) return what;
        }
        return null;
    }

    /// Under the lock: whether a batch newer than `batch` - in flight after
    /// it, or the queue - writes `key`'s response again.
    fn rewrittenAfterLocked(self: *Persistence, batch: *const Batch, key: []const u8) bool {
        if (self.pending.get(key)) |what| if (what == .put) return true;
        var newer = false;
        for (self.in_flight.items) |other| {
            if (other == batch) {
                newer = true;
                continue;
            }
            if (!newer) continue;
            if (other.taken.get(key)) |what| if (what == .put) return true;
        }
        return false;
    }

    fn touch(self: *Persistence, key: []const u8) void {
        self.lock();
        defer self.unlock();
        const entry = self.index.getPtr(key) orelse return;
        const now = nowSeconds();
        // Whole seconds: a second use within one changes nothing.
        if (entry.last_used == now) return;
        entry.last_used = now;
        self.queue(key, .touch) catch {};
    }

    fn read(self: *Persistence, key: []const u8) platform.StoreError!?[]u8 {
        const full = try std.mem.concat(self.allocator, u8, &.{ &.{0x02}, key });
        defer self.allocator.free(full);
        const store = try platform.openStore(self.browser, platform.Str.from(store_name), .{});
        defer platform.closeStore(store);
        const transaction = try platform.beginTransaction(store, .read);
        defer platform.abortTransaction(transaction);
        return platform.storeGet(transaction, self.allocator, platform.Bytes.from(full));
    }

    // -------------------------------------------------------------- commits

    fn commitFired(data: ?*anyopaque) void {
        const self: *Persistence = @ptrCast(@alignCast(data orelse return));
        self.commit();
    }

    /// The loop ended first: the Browser's flush wrote the batch.
    fn commitDropped(data: ?*anyopaque) void {
        _ = data;
    }

    /// Everything queued, taken as one batch with the index records as they
    /// stand now, and handed to the storage sequence, which writes it in one
    /// write transaction. The window thread.
    pub fn commit(self: *Persistence) void {
        // Made first: with no room for it the queue waits, whole, for the
        // next commit (the Browser's end flushes at the latest).
        const batch = self.allocator.create(Batch) catch return;
        batch.* = .{ .persistence = self };
        {
            self.lock();
            defer self.unlock();
            self.commit_posted = false;
            if (self.pending.count() == 0) {
                self.allocator.destroy(batch);
                return;
            }
            // The index records as they stand now, read under the lock, and
            // a slot in the list of batches in flight.
            batch.index_now.ensureTotalCapacity(self.allocator, self.pending.count()) catch {
                self.allocator.destroy(batch);
                return;
            };
            self.in_flight.ensureUnusedCapacity(self.allocator, 1) catch {
                batch.index_now.deinit(self.allocator);
                self.allocator.destroy(batch);
                return;
            };
            batch.taken = self.pending;
            self.pending = .empty;
            var keys = batch.taken.keyIterator();
            while (keys.next()) |key| batch.index_now.appendAssumeCapacity(.{ .key = key.*, .entry = self.index.get(key.*) });
            self.in_flight.appendAssumeCapacity(batch);
        }
        self.sequence.post(&batch.job);
    }

    /// The Browser's end: what is queued, handed to the storage sequence
    /// now, before the sequence stops (which writes it).
    pub fn flush(self: *Persistence) void {
        self.commit();
    }

    /// Under the lock: `batch` leaves the batches in flight.
    fn retireLocked(self: *Persistence, batch: *Batch) void {
        for (self.in_flight.items, 0..) |held, i| {
            if (held != batch) continue;
            _ = self.in_flight.orderedRemove(i);
            return;
        }
    }

    /// One commit's batch: its queue, taken whole (OWNED, a reference held
    /// per put), and the index records as they stood when it was taken
    /// (their keys borrowed from `taken`). Written on the storage sequence;
    /// in flight - readable - until then.
    const Batch = struct {
        job: Job = .{ .run = run, .drop = drop },
        /// BORROWED: outlives the sequence (the Browser stops it first).
        persistence: *Persistence,
        taken: std.StringHashMapUnmanaged(Pending) = .empty,
        index_now: std.ArrayListUnmanaged(IndexNow) = .empty,

        const IndexNow = struct { key: []const u8, entry: ?IndexEntry };

        fn destroy(self: *Batch) void {
            const persistence = self.persistence;
            self.index_now.deinit(persistence.allocator);
            persistence.dropPending(&self.taken);
            persistence.allocator.destroy(self);
        }

        /// On the storage sequence: the write, then the batch retired. A
        /// failed batch is lost, as a failed disk cache write is; what it
        /// would have written leaves the index - unless a newer batch writes
        /// it again - so the index never names a response the disk lacks.
        fn run(job: *Job) void {
            const self: *Batch = @fieldParentPtr("job", job);
            const persistence = self.persistence;
            const result = self.write();
            {
                persistence.lock();
                defer persistence.unlock();
                if (result) |_| {} else |err| {
                    log.warn("an HTTP cache commit to the profile failed: {s}", .{@errorName(err)});
                    var entries = self.taken.iterator();
                    while (entries.next()) |entry| {
                        if (entry.value_ptr.* != .put) continue;
                        if (persistence.rewrittenAfterLocked(self, entry.key_ptr.*)) continue;
                        if (persistence.index.fetchRemove(entry.key_ptr.*)) |removed| {
                            persistence.index_guard.noteRemoval(&persistence.index);
                            persistence.disk_bytes -= removed.value.size;
                            persistence.allocator.free(removed.key);
                        }
                    }
                }
                persistence.retireLocked(self);
            }
            self.destroy();
        }

        /// The sequence had stopped: the Browser is ending, its flush ran
        /// before, and this came too late to be written.
        fn drop(job: *Job) void {
            const self: *Batch = @fieldParentPtr("job", job);
            const persistence = self.persistence;
            log.warn("an HTTP cache commit came after the Browser's storage sequence stopped; it is not written", .{});
            {
                persistence.lock();
                defer persistence.unlock();
                persistence.retireLocked(self);
            }
            self.destroy();
        }

        fn write(self: *Batch) platform.StoreError!void {
            const store = try platform.openStore(self.persistence.browser, platform.Str.from(store_name), .{});
            defer platform.closeStore(store);
            const transaction = try platform.beginTransaction(store, .write);
            self.writeAll(transaction) catch |err| {
                platform.abortTransaction(transaction);
                return err;
            };
            return platform.commitTransaction(transaction);
        }

        fn writeAll(self: *Batch, transaction: *platform.StoreTransaction) platform.StoreError!void {
            const allocator = self.persistence.allocator;
            var full: std.ArrayListUnmanaged(u8) = .empty;
            defer full.deinit(allocator);
            for (self.index_now.items) |item| {
                const what = self.taken.get(item.key).?;
                full.clearRetainingCapacity();
                try full.append(allocator, 0x01);
                try full.appendSlice(allocator, item.key);
                const index_key = try allocator.dupe(u8, full.items);
                defer allocator.free(index_key);
                full.items[0] = 0x02;
                const response_key = full.items;
                // The index entry gone since (evicted or deleted): both records go.
                const entry = item.entry orelse {
                    try platform.storeDelete(transaction, platform.Bytes.from(index_key));
                    try platform.storeDelete(transaction, platform.Bytes.from(response_key));
                    continue;
                };
                switch (what) {
                    .delete => {
                        try platform.storeDelete(transaction, platform.Bytes.from(index_key));
                        try platform.storeDelete(transaction, platform.Bytes.from(response_key));
                        continue;
                    },
                    .put => |response| {
                        const record = try encode(allocator, response);
                        defer allocator.free(record);
                        try platform.storePut(transaction, platform.Bytes.from(response_key), platform.Bytes.from(record));
                    },
                    .touch => {},
                }
                var index_record: [12]u8 = undefined;
                std.mem.writeInt(u64, index_record[0..8], entry.size, .big);
                std.mem.writeInt(u32, index_record[8..12], entry.last_used, .big);
                try platform.storePut(transaction, platform.Bytes.from(index_key), platform.Bytes.from(&index_record));
            }
        }
    };
};

// ------------------------------------------------------------------- keys

/// A response's cache key: (partition length u32 BE, partition,
/// credentialed u8, URL). OWNED.
pub fn cacheKey(allocator: Allocator, partition: []const u8, url: []const u8, credentialed: bool) Allocator.Error![]u8 {
    const key = try allocator.alloc(u8, 4 + partition.len + 1 + url.len);
    std.mem.writeInt(u32, key[0..4], @intCast(partition.len), .big);
    @memcpy(key[4..][0..partition.len], partition);
    key[4 + partition.len] = @intFromBool(credentialed);
    @memcpy(key[5 + partition.len ..], url);
    return key;
}

fn splitKey(key: []const u8) ?struct { partition: []const u8, credentialed: bool, url: []const u8 } {
    if (key.len < 5) return null;
    const len = std.mem.readInt(u32, key[0..4], .big);
    if (key.len < 5 + len) return null;
    return .{ .partition = key[4..][0..len], .credentialed = key[4 + len] != 0, .url = key[5 + len ..] };
}

// ---------------------------------------------------------------- records

const record_version: u8 = 1;

fn appendBytes(list: *std.ArrayListUnmanaged(u8), allocator: Allocator, bytes: []const u8) Allocator.Error!void {
    var len: [4]u8 = undefined;
    std.mem.writeInt(u32, &len, @intCast(bytes.len), .big);
    try list.appendSlice(allocator, &len);
    try list.appendSlice(allocator, bytes);
}

fn appendInt(list: *std.ArrayListUnmanaged(u8), allocator: Allocator, comptime T: type, value: T) Allocator.Error!void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .big);
    try list.appendSlice(allocator, &bytes);
}

/// A stored response's record. OWNED.
pub fn encode(allocator: Allocator, response: *const StoredResponse) Allocator.Error![]u8 {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);
    try list.append(allocator, record_version);
    try appendBytes(&list, allocator, response.partition);
    try appendBytes(&list, allocator, response.url);
    try list.append(allocator, @intFromBool(response.credentialed));
    try appendInt(&list, allocator, u16, response.status);
    try appendBytes(&list, allocator, response.status_message);
    try appendInt(&list, allocator, u32, @intCast(response.headers.len));
    for (response.headers) |h| {
        try appendBytes(&list, allocator, h.name);
        try appendBytes(&list, allocator, h.value);
    }
    try appendBytes(&list, allocator, response.body.bytes);
    try appendInt(&list, allocator, u64, response.body_info.encoded_size);
    try appendInt(&list, allocator, u64, response.body_info.decoded_size);
    try appendInt(&list, allocator, u32, @intCast(response.vary.len));
    for (response.vary) |field| {
        try appendBytes(&list, allocator, field.name);
        try list.append(allocator, @intFromBool(field.value != null));
        try appendBytes(&list, allocator, field.value orelse "");
    }
    try list.append(allocator, @intFromBool(response.vary_star));
    try appendInt(&list, allocator, i64, response.request_time);
    try appendInt(&list, allocator, i64, response.response_time);
    return list.toOwnedSlice(allocator);
}

const Reader = struct {
    bytes: []const u8,
    at: usize = 0,

    fn take(self: *Reader, n: usize) error{Corrupt}![]const u8 {
        if (self.bytes.len - self.at < n) return error.Corrupt;
        defer self.at += n;
        return self.bytes[self.at..][0..n];
    }

    fn int(self: *Reader, comptime T: type) error{Corrupt}!T {
        return std.mem.readInt(T, (try self.take(@sizeOf(T)))[0..@sizeOf(T)], .big);
    }

    fn slice(self: *Reader) error{Corrupt}![]const u8 {
        return self.take(try self.int(u32));
    }

    fn flag(self: *Reader) error{Corrupt}!bool {
        return (try self.take(1))[0] != 0;
    }
};

/// The stored response a record holds, made with `allocator`.
pub fn decode(allocator: Allocator, bytes: []const u8) error{ OutOfMemory, Corrupt }!*StoredResponse {
    var reader: Reader = .{ .bytes = bytes };
    if ((try reader.take(1))[0] != record_version) return error.Corrupt;
    const partition = try reader.slice();
    const url = try reader.slice();
    const credentialed = try reader.flag();
    const status = try reader.int(u16);
    const status_message = try reader.slice();
    const header_count = try reader.int(u32);
    if (header_count > bytes.len) return error.Corrupt;
    const headers = try allocator.alloc(Header, header_count);
    defer allocator.free(headers);
    for (headers) |*h| h.* = .{ .name = try reader.slice(), .value = try reader.slice() };
    const body = try reader.slice();
    const encoded_size = try reader.int(u64);
    const decoded_size = try reader.int(u64);
    const vary_count = try reader.int(u32);
    if (vary_count > bytes.len) return error.Corrupt;
    const vary = try allocator.alloc(stored_response.VaryField, vary_count);
    defer allocator.free(vary);
    for (vary) |*field| {
        const name = try reader.slice();
        const has_value = try reader.flag();
        const value = try reader.slice();
        // The parts are borrowed from `bytes`; restore copies them.
        field.* = .{ .name = @constCast(name), .value = if (has_value) @constCast(value) else null };
    }
    const vary_star = try reader.flag();
    const request_time = try reader.int(i64);
    const response_time = try reader.int(i64);
    if (reader.at != bytes.len) return error.Corrupt;
    return StoredResponse.restore(allocator, .{
        .partition = partition,
        .url = url,
        .credentialed = credentialed,
        .status = status,
        .status_message = status_message,
        .headers = headers,
        .body = body,
        // The filtered coding is one of content_coding's static names, made
        // again from the stored Content-Encoding, as HTTP-network fetch made it.
        .body_info = .{
            .encoded_size = encoded_size,
            .decoded_size = decoded_size,
            .content_encoding = content_coding.filteredCoding(content_coding.headerFields(headers)),
        },
        .vary = vary,
        .vary_star = vary_star,
        .request_time = request_time,
        .response_time = response_time,
    });
}

test "PreferredCacheSize: Chromium's tiers for an HTTP disk cache" {
    // Unknown free space: the scaled default, 320 MiB.
    try std.testing.expectEqual(320 * mib, preferredCacheSize(null));
    // 100 MiB free: kDefaultCacheSize (it uses 10% to 80% of the space).
    try std.testing.expectEqual(@as(u64, 80 * mib), preferredCacheSize(100 * mib));
    // 50 MiB free: 80% of it.
    try std.testing.expectEqual(@as(u64, 40 * mib), preferredCacheSize(50 * mib));
    // Plenty: capped at four times the scaled default.
    try std.testing.expectEqual(1280 * mib, preferredCacheSize(1024 * 1024 * mib));
}

test "a stored response's record holds what the cache needs of it" {
    const allocator = std.testing.allocator;
    const original = try StoredResponse.create(allocator, .{
        .partition = "https://top.test",
        .url = "https://a.test/x",
        .credentialed = false,
        .status = 200,
        .status_message = "OK",
        .headers = &.{ .{ .name = "Content-Type", .value = "text/plain" }, .{ .name = "Vary", .value = "Accept" }, .{ .name = "Cache-Control", .value = "max-age=60" } },
        .body = "hello",
        .request = .{},
        .request_time = 10,
        .response_time = 11,
    });
    defer original.release();
    const record = try encode(allocator, original);
    defer allocator.free(record);
    const restored = try decode(allocator, record);
    defer restored.release();
    try std.testing.expectEqualStrings(original.url, restored.url);
    try std.testing.expectEqualStrings("hello", restored.body.bytes);
    try std.testing.expectEqual(original.credentialed, restored.credentialed);
    try std.testing.expectEqual(original.headers.len, restored.headers.len);
    try std.testing.expectEqual(original.vary.len, restored.vary.len);
    try std.testing.expectEqual(original.lifetime(), restored.lifetime());
    try std.testing.expectEqual(original.size, restored.size);
    try std.testing.expectError(error.Corrupt, decode(allocator, record[0 .. record.len - 1]));
}

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

test "a profile's HTTP cache: what one Browser stored is read by the next, what it invalidated is gone" {
    const testing = std.testing;
    const HttpCache = @import("http_cache.zig").HttpCache;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const directory = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(directory);
    const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };
    const make = struct {
        fn response(url: []const u8, body: []const u8) !*StoredResponse {
            return StoredResponse.create(testing.allocator, .{
                .partition = "https://top.test",
                .url = url,
                .status = 200,
                .headers = &.{.{ .name = "Cache-Control", .value = "max-age=600" }},
                .body = body,
                .request_time = 1,
                .response_time = 2,
            });
        }
    };
    {
        const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
        defer platform.destroyBrowserPlatform(browser);
        const cache = try HttpCache.create(testing.allocator, .{});
        var sequence = storage.StorageSequence.init(testing.allocator);
        defer sequence.deinit();
        try sequence.start();
        // No timer: the batch waits for the flush.
        try cache.attachProfile(browser, null, &sequence, null);
        cache.publish(try make.response("https://a.test/kept", "kept"));
        cache.publish(try make.response("https://a.test/gone", "gone"));
        cache.invalidate("https://top.test", "https://a.test/gone");
        cache.flushProfile();
        // As at a Browser's end: the sequence writes what it was handed and
        // stops before the cache closes.
        sequence.stop();
        cache.close();
    }
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const cache = try HttpCache.create(testing.allocator, .{});
    defer cache.close();
    // Stopped before the cache closes (the defers run in reverse).
    var sequence = storage.StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    try sequence.start();
    try cache.attachProfile(browser, null, &sequence, null);
    // The memory level is empty; the disk level answers, once, and the
    // memory level keeps it.
    try testing.expectEqual(@as(usize, 0), cache.entryCount());
    const kept = cache.lookup("https://top.test", "https://a.test/kept", true) orelse return error.TestExpectedHit;
    defer kept.release();
    try testing.expectEqualStrings("kept", kept.body.bytes);
    try testing.expectEqual(@as(usize, 1), cache.entryCount());
    try testing.expect(cache.lookup("https://top.test", "https://a.test/gone", true) == null);
    // Another partition, another key.
    try testing.expect(cache.lookup("https://other.test", "https://a.test/kept", true) == null);
}

/// A job that holds the storage sequence until its gate is set.
const Held = struct {
    job: Job = .{ .run = run, .drop = drop },
    gate: storage.sequence.Done = .{},

    fn run(job: *Job) void {
        const self: *Held = @fieldParentPtr("job", job);
        self.gate.wait();
    }

    fn drop(job: *Job) void {
        _ = job;
    }
};

fn countRecords(browser: *platform.BrowserPlatform) !usize {
    const store = try platform.openStore(browser, platform.Str.from(store_name), .{});
    defer platform.closeStore(store);
    const transaction = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(transaction);
    const cursor = try platform.openCursor(transaction, .all, .forward);
    defer platform.closeCursor(cursor);
    var records: usize = 0;
    while (try platform.cursorNext(cursor, std.testing.allocator)) |record| {
        std.testing.allocator.free(record.key.slice());
        std.testing.allocator.free(record.value.slice());
        records += 1;
    }
    return records;
}

test "a batch handed to the storage sequence answers reads from memory until it is written" {
    const testing = std.testing;
    const HttpCache = @import("http_cache.zig").HttpCache;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const directory = try std.fs.path.join(testing.allocator, &.{ base, "profile" });
    defer testing.allocator.free(directory);
    const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(directory) }, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const cache = try HttpCache.create(testing.allocator, .{});
    defer cache.close();
    var sequence = storage.StorageSequence.init(testing.allocator);
    defer sequence.deinit();
    try sequence.start();
    try cache.attachProfile(browser, null, &sequence, null);
    var held: Held = .{};
    sequence.post(&held.job);
    cache.publish(try StoredResponse.create(testing.allocator, .{
        .partition = "https://top.test",
        .url = "https://a.test/held",
        .status = 200,
        .headers = &.{.{ .name = "Cache-Control", .value = "max-age=600" }},
        .body = "held",
        .request_time = 1,
        .response_time = 2,
    }));
    cache.flushProfile();
    const persistence = cache.persistence.?;
    // Handed over and not written: the store has nothing, the batch is in
    // flight, and the disk level answers from it.
    try testing.expectEqual(@as(usize, 0), try countRecords(browser));
    try testing.expectEqual(@as(usize, 1), persistence.in_flight.items.len);
    const from_batch = persistence.load(testing.allocator, "https://top.test", "https://a.test/held", true) orelse return error.TestExpectedHit;
    defer from_batch.release();
    try testing.expectEqualStrings("held", from_batch.body.bytes);
    held.gate.set();
    sequence.barrier();
    // Written - its index record and its response - and retired.
    try testing.expectEqual(@as(usize, 0), persistence.in_flight.items.len);
    try testing.expectEqual(@as(usize, 2), try countRecords(browser));
    const from_store = persistence.load(testing.allocator, "https://top.test", "https://a.test/held", true) orelse return error.TestExpectedHit;
    defer from_store.release();
    try testing.expectEqualStrings("held", from_store.body.bytes);
}
