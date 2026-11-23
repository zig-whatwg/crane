//! IndexedDB's backing store: every database of a Browser, its records and
//! its index entries kept in the Browser's store "indexeddb" through the
//! platform protocol's storage engine (docs/platform-protocol.md 6.6) -
//! kit/memory_store for a Browser with no profile directory, kit/sqlite for
//! one with (the user's ruling D6, 2026-11-21; the integrator's plan 8:17 PM
//! ET: "one engine in both modes is Chrome's model - incognito runs the same
//! backing store over an in-memory env"). Lane prof1.
//!
//! The design is Chromium's IndexedDBBackingStore over LevelDB (BSD;
//! reproduced, not copied - content/browser/indexed_db/
//! indexed_db_backing_store.cc, indexed_db_leveldb_coding.cc,
//! leveldb/leveldb_transaction.cc, Copyright The Chromium Authors):
//!
//! - Records and index entries are read from the store when asked for -
//!   gets, ranges, cursors - never loaded whole; only the schema (stores,
//!   indexes, key generators, the version) is kept in memory, as Chromium
//!   keeps IndexedDBDatabaseMetadata.
//! - An IndexedDB transaction is a `Transaction` here: a read snapshot of
//!   the store taken when it starts, and a WRITE BATCH of its own changes
//!   that its reads see over the snapshot (LevelDBTransaction: a tree of
//!   changes over a snapshot, read through a TransactionIterator that merges
//!   the two). Its commit writes the batch in one short store transaction,
//!   one commit at a time; its abort drops the batch. The IndexedDB
//!   scheduler (server.zig) never runs two transactions that write the same
//!   object store at once, so batches applied in commit order are
//!   serializable, and only a commit ever holds the store's one writer.
//! - Keys are order-preserving byte strings, so the store's byte order is
//!   IndexedDB's key order (6.6: "Crane encodes IndexedDB keys, object stores
//!   and indexes into order-preserving byte keys above this layer"). The key
//!   encoding is self-delimiting so an index entry's key - index key then
//!   primary key - sorts by both. Chromium compares its keys with a LevelDB
//!   comparator of its own; Firefox's Key.cpp (MPL: its idea reproduced, not
//!   its code) encodes byte-comparable keys, typed in IndexedDB's order:
//!   number < date < string < binary < array.
//! - A record keeps, beside its value, the index keys it was filed under
//!   (Firefox's index_data_values on object_data rows), so an overwrite or a
//!   delete removes its old index entries without running a key path again.
//! - With a profile directory, a commit is written on the Browser's storage
//!   sequence (storage.StorageSequence; lane prof2), never on the agent's
//!   thread: the batch moves into a `CommitJob`, and the transaction learns
//!   its result from a task the job posts to its agent's loop - Chromium
//!   commits on its IndexedDB backing store's sequence and posts the
//!   complete event back to the renderer only after the commit finished
//!   (content/browser/indexed_db/indexed_db_transaction.cc, Commit ->
//!   CommitPhaseTwo -> the callbacks' OnComplete). With no profile directory
//!   (kit/memory_store) there is no sequence: a commit is written on the
//!   committing thread, as before. No read waits for the sequence: a
//!   transaction starts only once every earlier overlapping one finished -
//!   its commit written - and a database's schema is read only for a record
//!   the server's map lacks, which a database with a commit or a deletion
//!   in flight never is (the job holds its record, `CommitJob.hold`).
//!
//! LAYOUT (byte keys; `esc(b)` escapes 0x00 as 00 FF and ends with 00 01;
//! integers u64 big-endian; `key(k)` the key encoding below):
//!   00 'n'                                   the next database id
//!   01 esc(storage key) esc(name)            a database's id
//!   02 db 00                                 the database: version, next store id
//!   02 db 01 store                           an object store's schema (schema.zig)
//!   03 db store key(primary)                 a record: index keys, then the value
//!   04 db store index key(index) key(primary)  an index entry (empty)

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const IDBKey = @import("key.zig").IDBKey;
const sequence_mod = @import("../sequence.zig");
const server_mod = @import("server.zig");

pub const store_name = "indexeddb";

pub const Error = platform.StoreError || error{Corrupt};

/// A store failure as IndexedDB reports it: QuotaExceededError for a full
/// store, UnknownError for any other (IndexedDB 5.4 commit: "an appropriate
/// error"; Chromium's IndexedDBBackingStore maps leveldb errors so).
pub fn idbError(err: anyerror) @import("errors.zig").IDBError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.QuotaExceeded => error.QuotaExceededError,
        else => error.UnknownError,
    };
}

// ======================================================================
// Key encoding
// ======================================================================

const tag_number: u8 = 0x10;
const tag_date: u8 = 0x20;
const tag_string: u8 = 0x30;
const tag_binary: u8 = 0x40;
const tag_array: u8 = 0x50;
const array_end: u8 = 0x00;

/// Append `bytes` escaped: 0x00 as 00 FF, then the terminator 00 01, which
/// sorts below every escaped byte - a prefix before its extensions.
pub fn appendEscaped(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, bytes: []const u8) Allocator.Error!void {
    try out.ensureUnusedCapacity(allocator, bytes.len + 2);
    for (bytes) |byte| {
        if (byte == 0) {
            try out.appendSlice(allocator, &.{ 0x00, 0xFF });
        } else try out.append(allocator, byte);
    }
    try out.appendSlice(allocator, &.{ 0x00, 0x01 });
}

/// A number's 8 bytes in an order memcmp agrees with: the sign bit set for
/// a positive number, every bit flipped for a negative one. -0 is +0 (the
/// keys compare equal, IndexedDB 2.? "compare two keys").
fn sortableNumber(value: f64) u64 {
    const canonical = if (value == 0) 0.0 else value;
    const bits: u64 = @bitCast(canonical);
    return if (bits >> 63 == 1) ~bits else bits | (@as(u64, 1) << 63);
}

fn numberFromSortable(sortable: u64) f64 {
    const bits = if (sortable >> 63 == 1) sortable & ~(@as(u64, 1) << 63) else ~sortable;
    return @bitCast(bits);
}

/// Append `key`, order-preserving and self-delimiting.
pub fn appendKey(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, key: IDBKey) Allocator.Error!void {
    switch (key.value) {
        .number => |number| {
            try out.append(allocator, tag_number);
            try appendU64(out, allocator, sortableNumber(number));
        },
        .date => |millis| {
            try out.append(allocator, tag_date);
            try appendU64(out, allocator, @as(u64, @bitCast(millis)) ^ (@as(u64, 1) << 63));
        },
        .string => |text| {
            // Strings compare by UTF-16 code unit (key.compareStrings): each
            // unit as two big-endian bytes, escaped.
            try out.append(allocator, tag_string);
            var units: std.ArrayListUnmanaged(u8) = .empty;
            defer units.deinit(allocator);
            var points = std.unicode.Wtf8View.initUnchecked(text).iterator();
            while (points.nextCodepoint()) |point| {
                if (point <= 0xffff) {
                    try appendUnit(&units, allocator, @intCast(point));
                } else {
                    const offset = point - 0x10000;
                    try appendUnit(&units, allocator, @intCast(0xd800 + (offset >> 10)));
                    try appendUnit(&units, allocator, @intCast(0xdc00 + (offset & 0x3ff)));
                }
            }
            try appendEscaped(out, allocator, units.items);
        },
        .binary => |bytes| {
            try out.append(allocator, tag_binary);
            try appendEscaped(out, allocator, bytes);
        },
        .array => |elements| {
            try out.append(allocator, tag_array);
            for (elements) |element| try appendKey(out, allocator, element);
            try out.append(allocator, array_end);
        },
    }
}

fn appendUnit(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, unit: u16) Allocator.Error!void {
    try out.appendSlice(allocator, &.{ @intCast(unit >> 8), @intCast(unit & 0xff) });
}

pub fn appendU64(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, value: u64) Allocator.Error!void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    try out.appendSlice(allocator, &bytes);
}

/// A reader over encoded bytes.
pub const Reader = struct {
    bytes: []const u8,
    at: usize = 0,

    pub fn done(self: *const Reader) bool {
        return self.at >= self.bytes.len;
    }

    pub fn byte(self: *Reader) error{Corrupt}!u8 {
        if (self.at >= self.bytes.len) return error.Corrupt;
        defer self.at += 1;
        return self.bytes[self.at];
    }

    pub fn u64Be(self: *Reader) error{Corrupt}!u64 {
        if (self.bytes.len - self.at < 8) return error.Corrupt;
        defer self.at += 8;
        return std.mem.readInt(u64, self.bytes[self.at..][0..8], .big);
    }

    pub fn u32Be(self: *Reader) error{Corrupt}!u32 {
        if (self.bytes.len - self.at < 4) return error.Corrupt;
        defer self.at += 4;
        return std.mem.readInt(u32, self.bytes[self.at..][0..4], .big);
    }

    pub fn take(self: *Reader, n: usize) error{Corrupt}![]const u8 {
        if (self.bytes.len - self.at < n) return error.Corrupt;
        defer self.at += n;
        return self.bytes[self.at..][0..n];
    }

    /// An escaped byte string, unescaped into `out`.
    pub fn escaped(self: *Reader, out: *std.ArrayListUnmanaged(u8), allocator: Allocator) (error{Corrupt} || Allocator.Error)!void {
        while (true) {
            const b = try self.byte();
            if (b != 0) {
                try out.append(allocator, b);
                continue;
            }
            switch (try self.byte()) {
                0x01 => return,
                0xFF => try out.append(allocator, 0),
                else => return error.Corrupt,
            }
        }
    }

    /// Skip an escaped byte string.
    pub fn skipEscaped(self: *Reader) error{Corrupt}!void {
        while (true) {
            if (try self.byte() != 0) continue;
            switch (try self.byte()) {
                0x01 => return,
                0xFF => {},
                else => return error.Corrupt,
            }
        }
    }

    /// One encoded key, decoded and owned (`allocator`).
    pub fn key(self: *Reader, allocator: Allocator) (error{Corrupt} || Allocator.Error)!IDBKey {
        switch (try self.byte()) {
            tag_number => return IDBKey.number(numberFromSortable(try self.u64Be())),
            tag_date => return IDBKey.date(@bitCast((try self.u64Be()) ^ (@as(u64, 1) << 63))),
            tag_string => {
                var raw: std.ArrayListUnmanaged(u8) = .empty;
                defer raw.deinit(allocator);
                try self.escaped(&raw, allocator);
                if (raw.items.len % 2 != 0) return error.Corrupt;
                const units = try allocator.alloc(u16, raw.items.len / 2);
                defer allocator.free(units);
                for (units, 0..) |*unit, i| unit.* = std.mem.nativeToLittle(u16, std.mem.readInt(u16, raw.items[i * 2 ..][0..2], .big));
                const text = try std.unicode.wtf16LeToWtf8Alloc(allocator, units);
                return .{ .key_type = .string, .value = .{ .string = text }, .allocator = allocator };
            },
            tag_binary => {
                var raw: std.ArrayListUnmanaged(u8) = .empty;
                errdefer raw.deinit(allocator);
                try self.escaped(&raw, allocator);
                return .{ .key_type = .binary, .value = .{ .binary = try raw.toOwnedSlice(allocator) }, .allocator = allocator };
            },
            tag_array => {
                var elements: std.ArrayListUnmanaged(IDBKey) = .empty;
                errdefer {
                    for (elements.items) |*element| element.deinit();
                    elements.deinit(allocator);
                }
                while (true) {
                    if (self.at >= self.bytes.len) return error.Corrupt;
                    if (self.bytes[self.at] == array_end) {
                        self.at += 1;
                        break;
                    }
                    var element = try self.key(allocator);
                    elements.append(allocator, element) catch |err| {
                        element.deinit();
                        return err;
                    };
                }
                return .{ .key_type = .array, .value = .{ .array = try elements.toOwnedSlice(allocator) }, .allocator = allocator };
            },
            else => return error.Corrupt,
        }
    }

    /// Skip one encoded key.
    pub fn skipKey(self: *Reader) error{Corrupt}!void {
        switch (try self.byte()) {
            tag_number, tag_date => _ = try self.take(8),
            tag_string, tag_binary => try self.skipEscaped(),
            tag_array => while (true) {
                if (self.at >= self.bytes.len) return error.Corrupt;
                if (self.bytes[self.at] == array_end) {
                    self.at += 1;
                    return;
                }
                try self.skipKey();
            },
            else => return error.Corrupt,
        }
    }
};

// ======================================================================
// Layout
// ======================================================================

pub const prefix_next_id = [_]u8{ 0x00, 'n' };
pub const tag_directory: u8 = 0x01;
pub const tag_schema: u8 = 0x02;
pub const tag_record: u8 = 0x03;
pub const tag_index: u8 = 0x04;

/// A key under construction, in a buffer the caller reuses: no allocation
/// once it has grown to a key's size.
pub const KeyBuffer = struct {
    bytes: std.ArrayListUnmanaged(u8) = .empty,

    pub fn deinit(self: *KeyBuffer, allocator: Allocator) void {
        self.bytes.deinit(allocator);
    }

    pub fn reset(self: *KeyBuffer) *std.ArrayListUnmanaged(u8) {
        self.bytes.clearRetainingCapacity();
        return &self.bytes;
    }
};

pub fn directoryKey(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, storage_key: []const u8, name: []const u8) Allocator.Error!void {
    try out.append(allocator, tag_directory);
    try appendEscaped(out, allocator, storage_key);
    try appendEscaped(out, allocator, name);
}

pub fn databaseKey(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, db: u64) Allocator.Error!void {
    try out.append(allocator, tag_schema);
    try appendU64(out, allocator, db);
    try out.append(allocator, 0x00);
}

pub fn storeSchemaKey(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, db: u64, store: u64) Allocator.Error!void {
    try out.append(allocator, tag_schema);
    try appendU64(out, allocator, db);
    try out.append(allocator, 0x01);
    try appendU64(out, allocator, store);
}

/// 03 db store - every record of a store starts so.
pub fn recordPrefix(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, db: u64, store: u64) Allocator.Error!void {
    try out.append(allocator, tag_record);
    try appendU64(out, allocator, db);
    try appendU64(out, allocator, store);
}

/// 04 db store index - every entry of an index starts so.
pub fn indexPrefix(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, db: u64, store: u64, index: u64) Allocator.Error!void {
    try out.append(allocator, tag_index);
    try appendU64(out, allocator, db);
    try appendU64(out, allocator, store);
    try appendU64(out, allocator, index);
}

/// The smallest key past every key that starts with `prefix` (its last
/// byte below 0xFF raised by one, what follows dropped): an exclusive upper
/// bound for a prefix scan. Every prefix here ends in a counter or a tag,
/// so one byte below 0xFF exists. OWNED by `out`.
pub fn prefixEnd(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, prefix: []const u8) Allocator.Error!void {
    var end = prefix.len;
    while (end > 0 and prefix[end - 1] == 0xFF) end -= 1;
    std.debug.assert(end > 0);
    try out.appendSlice(allocator, prefix[0..end]);
    out.items[out.items.len - 1] += 1;
}

/// 05 db store key(primary) - every reverse row of a record starts so; the
/// row's index id follows.
pub fn reversePrefix(out: *std.ArrayListUnmanaged(u8), allocator: Allocator, db: u64, store: u64) Allocator.Error!void {
    try out.append(allocator, tag_reverse);
    try appendU64(out, allocator, db);
    try appendU64(out, allocator, store);
}

pub const tag_reverse: u8 = 0x05;

/// The byte bounds - lower inclusive, upper exclusive - of the keys under
/// `prefix` whose next encoded key lies in the IndexedDB key range (`lower`,
/// `upper`, each open or closed; null: unbounded), into `lower_out` and
/// `upper_out`. A key under the prefix may carry more after that key (an
/// index entry's primary key, a reverse row's index id): a closed upper bound
/// and an open lower one are the end of everything that starts with
/// prefix ++ key(bound).
pub fn keyRangeBounds(
    allocator: Allocator,
    prefix: []const u8,
    lower: ?IDBKey,
    lower_open: bool,
    upper: ?IDBKey,
    upper_open: bool,
    lower_out: *std.ArrayListUnmanaged(u8),
    upper_out: *std.ArrayListUnmanaged(u8),
) Allocator.Error!Bounds {
    lower_out.clearRetainingCapacity();
    upper_out.clearRetainingCapacity();
    try lower_out.appendSlice(allocator, prefix);
    if (lower) |key| {
        try appendKey(lower_out, allocator, key);
        if (lower_open) {
            var start: std.ArrayListUnmanaged(u8) = .empty;
            defer start.deinit(allocator);
            try start.appendSlice(allocator, lower_out.items);
            lower_out.clearRetainingCapacity();
            try prefixEnd(lower_out, allocator, start.items);
        }
    }
    if (upper) |key| {
        try upper_out.appendSlice(allocator, prefix);
        try appendKey(upper_out, allocator, key);
        if (!upper_open) {
            var start: std.ArrayListUnmanaged(u8) = .empty;
            defer start.deinit(allocator);
            try start.appendSlice(allocator, upper_out.items);
            upper_out.clearRetainingCapacity();
            try prefixEnd(upper_out, allocator, start.items);
        }
    } else try prefixEnd(upper_out, allocator, prefix);
    return .{ .lower = lower_out.items, .upper = upper_out.items, .upper_open = true };
}

/// `a` narrowed by `b`: the larger lower bound, the smaller upper bound
/// (both lower inclusive and upper exclusive).
pub fn intersect(a: Bounds, b: Bounds) Bounds {
    var result = a;
    if (b.lower) |lower| {
        if (result.lower == null or std.mem.order(u8, lower, result.lower.?) == .gt) result.lower = lower;
    }
    if (b.upper) |upper| {
        if (result.upper == null or std.mem.order(u8, upper, result.upper.?) == .lt) result.upper = upper;
    }
    result.lower_open = false;
    result.upper_open = true;
    return result;
}

/// Whether the bounds hold no key at all.
pub fn empty(bounds: Bounds) bool {
    const lower = bounds.lower orelse return false;
    const upper = bounds.upper orelse return false;
    return std.mem.order(u8, lower, upper) != .lt;
}

// ======================================================================
// The store and its transactions
// ======================================================================

/// The Browser's IndexedDB store. One per IDBServer.
pub const BackingStore = struct {
    allocator: Allocator,
    /// BORROWED: the Browser's platform state, which outlives every realm.
    browser: *platform.BrowserPlatform,
    /// One commit at a time (the store's one writer).
    commit_mutex: std.Io.Mutex = .init,
    /// The next database id (`00 n`), read at `init`; handed out in memory
    /// and written by the next commit after one was taken, under the commit
    /// lock - always the latest, so the stored counter never goes back.
    next_db_id: std.atomic.Value(u64) = .init(1),
    counter_dirty: std.atomic.Value(bool) = .init(false),
    /// The Browser's storage sequence, which writes every commit of a
    /// Browser with a profile directory (lane prof2; `IDBServer.attachSequence`
    /// at Browser.init, before any realm). Null - no profile directory, or no
    /// Browser - commits are written on the committing thread.
    sequence: ?*sequence_mod.StorageSequence = null,

    /// The store of `browser`, its database counter read.
    pub fn init(allocator: Allocator, browser: *platform.BrowserPlatform) Error!BackingStore {
        var self: BackingStore = .{ .allocator = allocator, .browser = browser };
        const store = try self.open();
        defer platform.closeStore(store);
        const reader = try platform.beginTransaction(store, .read);
        defer platform.abortTransaction(reader);
        const stored = (try platform.storeGet(reader, allocator, platform.Bytes.from(&prefix_next_id))) orelse return self;
        defer allocator.free(stored);
        if (stored.len != 8) return error.Corrupt;
        self.next_db_id.store(@max(1, std.mem.readInt(u64, stored[0..8], .big)), .monotonic);
        return self;
    }

    /// A new database's id, never handed out before on this profile.
    pub fn allocateDatabaseId(self: *BackingStore) u64 {
        const id = self.next_db_id.fetchAdd(1, .monotonic);
        self.counter_dirty.store(true, .release);
        return id;
    }

    fn open(self: *BackingStore) platform.StoreError!*platform.Store {
        return platform.openStore(self.browser, platform.Str.from(store_name), .{});
    }

    /// A transaction over a snapshot taken now.
    pub fn begin(self: *BackingStore) platform.StoreError!*Transaction {
        const store = try self.open();
        errdefer platform.closeStore(store);
        const snapshot = try platform.beginTransaction(store, .read);
        errdefer platform.abortTransaction(snapshot);
        const transaction = try self.allocator.create(Transaction);
        transaction.* = .{ .backing = self, .store = store, .snapshot = snapshot };
        return transaction;
    }

    /// Write `changes` - each key's value, or null for its deletion - in one
    /// store transaction, under the commit lock (several agents' threads
    /// commit at once with no sequence; with one, only the sequence writes).
    /// Durable on return with a profile (kit/sqlite).
    pub fn apply(self: *BackingStore, ranges: []const OwnedRange, changes: []const Change) platform.StoreError!void {
        if (changes.len == 0 and ranges.len == 0) return;
        std.Io.Threaded.mutexLockUncancelable(&self.commit_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.commit_mutex);
        const store = try self.open();
        defer platform.closeStore(store);
        const writer = try platform.beginTransaction(store, .write);
        const counter_was_dirty = self.counter_dirty.swap(false, .acq_rel);
        self.writeAll(writer, ranges, changes, counter_was_dirty) catch |err| {
            platform.abortTransaction(writer);
            if (counter_was_dirty) self.counter_dirty.store(true, .release);
            return err;
        };
        platform.commitTransaction(writer) catch |err| {
            if (counter_was_dirty) self.counter_dirty.store(true, .release);
            return err;
        };
    }

    fn writeAll(self: *BackingStore, writer: *platform.StoreTransaction, ranges: []const OwnedRange, changes: []const Change, counter: bool) platform.StoreError!void {
        // A batch's range deletions came before the changes it still holds
        // (a change in a range made later overrides it).
        for (ranges) |range| try platform.storeDeleteRange(writer, .{
            .lower = platform.Bytes.from(range.lower),
            .has_lower = true,
            .upper = platform.Bytes.from(range.upper),
            .has_upper = true,
            .upper_open = true,
        });
        for (changes) |change| {
            if (change.value) |value| {
                try platform.storePut(writer, platform.Bytes.from(change.key), platform.Bytes.from(value));
            } else try platform.storeDelete(writer, platform.Bytes.from(change.key));
        }
        if (counter) {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, self.next_db_id.load(.monotonic), .big);
            try platform.storePut(writer, platform.Bytes.from(&prefix_next_id), platform.Bytes.from(&bytes));
        }
    }
};

/// One key's change: its new value, or null for a deletion. OWNED.
pub const Change = struct {
    key: []u8,
    value: ?[]u8,
};

/// Every key in [lower, upper) deleted. OWNED.
pub const OwnedRange = struct {
    lower: []u8,
    upper: []u8,

    fn contains(self: OwnedRange, key: []const u8) bool {
        return std.mem.order(u8, key, self.lower) != .lt and std.mem.order(u8, key, self.upper) == .lt;
    }
};

/// A commit handed to the Browser's storage sequence (lane prof2): an
/// IndexedDB transaction's batch, or a database's deletion, moved out of
/// its `Transaction` and written there in one store transaction
/// (`BackingStore.apply`). Two references: the waiter's (the transaction,
/// or the deletion's request: `take` or `abandon`) and the sequence's
/// (passed to the task that tells the waiter, or given back when nobody is
/// told).
pub const CommitJob = struct {
    job: sequence_mod.Job = .{ .run = run, .drop = drop },
    backing: *BackingStore,
    /// The batch, moved from the transaction. OWNED until written.
    ranges: std.ArrayListUnmanaged(OwnedRange) = .empty,
    changes: std.ArrayListUnmanaged(Change) = .empty,
    /// Written by the sequence before `done` is set; read after it.
    result: platform.StoreError!void = {},
    done: sequence_mod.Done = .{},
    refs: std.atomic.Value(u32) = .init(2),
    /// Where the waiter is told: a task posted to its agent's loop (an
    /// endpoint of dom.indexeddb.endpointOf, its sink reference OWNED until
    /// the post). Null: the waiter waits for `done` itself.
    notify: ?server_mod.Endpoint = null,
    /// What the posted task calls, on the waiter's agent's thread, while
    /// set. That thread's alone: set after the post, cleared by `take` and
    /// `abandon` - so the task never calls a waiter that has gone.
    waiter: ?Waiter = null,
    /// A database record the job holds until it was written (a deletion's):
    /// the record stays in the server's map, so no agent reads the store's
    /// copy of the database - its schema, its directory entry - meanwhile.
    hold: ?Hold = null,

    pub const Waiter = struct {
        context: *anyopaque,
        call: *const fn (context: *anyopaque) void,
    };

    pub const Hold = struct {
        server: *server_mod.IDBServer,
        database: *server_mod.UniqueIDBDatabase,
    };

    /// Hand it to the storage sequence. Never under a lock a job takes (the
    /// server's: a stopped sequence drops it here, and the drop lets go of
    /// its hold). The job is the sequence's and its waiter's from here.
    pub fn post(self: *CommitJob) void {
        self.backing.sequence.?.post(&self.job);
    }

    /// Whether the batch was written (or will never be).
    pub fn isDone(self: *const CommitJob) bool {
        return self.done.isSet();
    }

    /// Block until it was written: an agent ending with its transaction's
    /// commit in flight (the one wait an agent's thread makes on the
    /// sequence, at its end), or a caller with no loop to be told on.
    pub fn wait(self: *CommitJob) void {
        self.done.wait();
    }

    /// The waiter's answer, once done, and its reference given back: the
    /// store's error, if the write failed. On the waiter's thread.
    pub fn take(self: *CommitJob) platform.StoreError!void {
        std.debug.assert(self.done.isSet());
        self.waiter = null;
        const result = self.result;
        self.release();
        return result;
    }

    /// The waiter goes without its answer (its agent ended; a deletion's
    /// write needs nothing of it): its reference given back. On the
    /// waiter's thread.
    pub fn abandon(self: *CommitJob) void {
        self.waiter = null;
        self.release();
    }

    fn release(self: *CommitJob) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.notify) |*endpoint| endpoint.release();
        self.freeBatch();
        self.backing.allocator.destroy(self);
    }

    fn freeBatch(self: *CommitJob) void {
        const allocator = self.backing.allocator;
        for (self.changes.items) |item| {
            allocator.free(item.key);
            if (item.value) |value| allocator.free(value);
        }
        self.changes.deinit(allocator);
        self.changes = .empty;
        for (self.ranges.items) |range| {
            allocator.free(range.lower);
            allocator.free(range.upper);
        }
        self.ranges.deinit(allocator);
        self.ranges = .empty;
    }

    /// On the storage sequence: the write.
    fn run(job: *sequence_mod.Job) void {
        const self: *CommitJob = @fieldParentPtr("job", job);
        self.result = self.backing.apply(self.ranges.items, self.changes.items);
        self.finish();
    }

    /// The sequence had stopped (the Browser is ending, after its realms):
    /// never written. On the poster's thread.
    fn drop(job: *sequence_mod.Job) void {
        const self: *CommitJob = @fieldParentPtr("job", job);
        self.result = error.Closed;
        self.finish();
    }

    /// The batch goes, the record is let go, the waiter learns: `done`,
    /// then the task to its agent, which takes the sequence's reference.
    fn finish(self: *CommitJob) void {
        self.freeBatch();
        if (self.hold) |hold| {
            self.hold = null;
            // A job may take the server's lock: nothing waits for the
            // sequence under it.
            hold.server.release(hold.database);
        }
        self.done.set();
        var endpoint = self.notify orelse return self.release();
        self.notify = null;
        endpoint.post(.{ .run = notifyRun, .drop = notifyDrop, .data = self });
        endpoint.release();
    }

    /// On the waiter's agent's thread: tell it, if it still waits.
    fn notifyRun(data: ?*anyopaque) void {
        const self: *CommitJob = @ptrCast(@alignCast(data.?));
        if (self.waiter) |waiter| waiter.call(waiter.context);
        self.release();
    }

    /// That loop ended: nobody to tell (the agent's end waited instead).
    fn notifyDrop(data: ?*anyopaque) void {
        const self: *CommitJob = @ptrCast(@alignCast(data.?));
        self.release();
    }
};

/// What a merged read returns: a key and its value. OWNED (the allocator
/// the read was given).
pub const Entry = struct {
    key: []u8,
    value: []u8,

    pub fn deinit(self: Entry, allocator: Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
    }
};

pub const Direction = enum { forward, reverse };

/// A key range in the store's byte order. Bounds BORROWED.
pub const Bounds = struct {
    lower: ?[]const u8 = null,
    lower_open: bool = false,
    upper: ?[]const u8 = null,
    upper_open: bool = false,

    fn below(self: Bounds, key: []const u8) bool {
        const lower = self.lower orelse return false;
        return switch (std.mem.order(u8, key, lower)) {
            .lt => true,
            .eq => self.lower_open,
            .gt => false,
        };
    }

    fn above(self: Bounds, key: []const u8) bool {
        const upper = self.upper orelse return false;
        return switch (std.mem.order(u8, key, upper)) {
            .gt => true,
            .eq => self.upper_open,
            .lt => false,
        };
    }

    pub fn contains(self: Bounds, key: []const u8) bool {
        return !self.below(key) and !self.above(key);
    }

    fn platformRange(self: Bounds) platform.KeyRange {
        return .{
            .lower = platform.Bytes.from(self.lower orelse ""),
            .has_lower = self.lower != null,
            .lower_open = self.lower_open,
            .upper = platform.Bytes.from(self.upper orelse ""),
            .has_upper = self.upper != null,
            .upper_open = self.upper_open,
        };
    }
};

/// An IndexedDB transaction's view of the store: its snapshot, and its own
/// changes over it (LevelDBTransaction).
pub const Transaction = struct {
    backing: *BackingStore,
    store: *platform.Store,
    snapshot: *platform.StoreTransaction,
    /// The changes, sorted by key (a value, or null: deleted). OWNED.
    changes: std.ArrayListUnmanaged(Change) = .empty,
    /// Range deletions, in the order made: a snapshot key inside one is
    /// gone for this transaction; a change made after it overrides it
    /// (deleteRange clears the changes it covers). Chromium's
    /// LevelDBTransaction::RemoveRange.
    ranges: std.ArrayListUnmanaged(OwnedRange) = .empty,
    /// Key buffers the transaction's requests build their keys in, reused:
    /// a read allocates no key once they have grown.
    scratch: [@typeInfo(Slot).@"enum".field_names.len]std.ArrayListUnmanaged(u8) = @splat(.empty),

    /// The scratch buffers, by use.
    pub const Slot = enum { lower, upper, key, prefix, aux_lower, aux_upper, aux_key };

    /// The buffer `slot`, emptied. Grown with `allocator()`.
    pub fn buffer(self: *Transaction, slot: Slot) *std.ArrayListUnmanaged(u8) {
        const out = &self.scratch[@backingInt(slot)];
        out.clearRetainingCapacity();
        return out;
    }

    pub fn gpa(self: *const Transaction) Allocator {
        return self.backing.allocator;
    }

    /// The transaction ends: its snapshot and its changes go (committed or
    /// not - `commit` writes them first).
    pub fn destroy(self: *Transaction) void {
        const allocator = self.backing.allocator;
        self.dropChanges();
        self.changes.deinit(allocator);
        self.ranges.deinit(allocator);
        for (&self.scratch) |*slot_buffer| slot_buffer.deinit(allocator);
        platform.abortTransaction(self.snapshot);
        platform.closeStore(self.store);
        allocator.destroy(self);
    }

    fn dropChanges(self: *Transaction) void {
        const allocator = self.backing.allocator;
        for (self.changes.items) |item| {
            allocator.free(item.key);
            if (item.value) |value| allocator.free(value);
        }
        self.changes.clearRetainingCapacity();
        for (self.ranges.items) |range| {
            allocator.free(range.lower);
            allocator.free(range.upper);
        }
        self.ranges.clearRetainingCapacity();
    }

    /// Whether a range deletion hides the snapshot's `key`.
    fn hidden(self: *const Transaction, key: []const u8) bool {
        for (self.ranges.items) |range| if (range.contains(key)) return true;
        return false;
    }

    /// Write the changes (LevelDBTransaction::Commit). On failure nothing
    /// was written and the changes are kept for an abort.
    pub fn commit(self: *Transaction) platform.StoreError!void {
        try self.backing.apply(self.ranges.items, self.changes.items);
        self.dropChanges();
    }

    /// Drop the changes (LevelDBTransaction::Rollback).
    pub fn rollback(self: *Transaction) void {
        self.dropChanges();
    }

    /// Whether a commit would write anything.
    pub fn hasChanges(self: *const Transaction) bool {
        return self.changes.items.len != 0 or self.ranges.items.len != 0;
    }

    /// The changes, moved into a job for the Browser's storage sequence (the
    /// backing store has one), to be handed over with `CommitJob.post`:
    /// `notify` is told once it was written (null: the caller waits), and
    /// `hold` is held until then. The snapshot stays the transaction's.
    /// Takes `notify` whatever happens. The job's waiter reference is the
    /// caller's.
    pub fn prepareCommit(self: *Transaction, notify: ?server_mod.Endpoint, hold: ?CommitJob.Hold) Allocator.Error!*CommitJob {
        std.debug.assert(self.backing.sequence != null);
        const job = self.backing.allocator.create(CommitJob) catch |err| {
            if (notify) |endpoint| {
                var owned = endpoint;
                owned.release();
            }
            return err;
        };
        job.* = .{ .backing = self.backing, .ranges = self.ranges, .changes = self.changes, .notify = notify, .hold = hold };
        self.ranges = .empty;
        self.changes = .empty;
        return job;
    }

    fn find(self: *const Transaction, key: []const u8) struct { index: usize, found: bool } {
        var low: usize = 0;
        var high: usize = self.changes.items.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            switch (std.mem.order(u8, self.changes.items[mid].key, key)) {
                .lt => low = mid + 1,
                .gt => high = mid,
                .eq => return .{ .index = mid, .found = true },
            }
        }
        return .{ .index = low, .found = false };
    }

    fn change(self: *Transaction, key: []const u8, value: ?[]const u8) Allocator.Error!void {
        const allocator = self.backing.allocator;
        const owned_value: ?[]u8 = if (value) |bytes| try allocator.dupe(u8, bytes) else null;
        errdefer if (owned_value) |bytes| allocator.free(bytes);
        const at = self.find(key);
        if (at.found) {
            const slot = &self.changes.items[at.index];
            if (slot.value) |old| allocator.free(old);
            slot.value = owned_value;
            return;
        }
        const owned_key = try allocator.dupe(u8, key);
        errdefer allocator.free(owned_key);
        try self.changes.insert(allocator, at.index, .{ .key = owned_key, .value = owned_value });
    }

    pub fn put(self: *Transaction, key: []const u8, value: []const u8) Allocator.Error!void {
        return self.change(key, value);
    }

    pub fn delete(self: *Transaction, key: []const u8) Allocator.Error!void {
        return self.change(key, null);
    }

    /// Delete every key the transaction sees in [lower, upper): one range
    /// deletion, whatever the range holds - its own changes there dropped.
    pub fn deleteRange(self: *Transaction, lower: []const u8, upper: []const u8) Allocator.Error!void {
        const allocator = self.backing.allocator;
        try self.ranges.ensureUnusedCapacity(allocator, 1);
        const owned_lower = try allocator.dupe(u8, lower);
        errdefer allocator.free(owned_lower);
        const owned_upper = try allocator.dupe(u8, upper);
        const range: OwnedRange = .{ .lower = owned_lower, .upper = owned_upper };
        self.ranges.appendAssumeCapacity(range);
        // Its own changes there: gone, and their slots too (a deletion of a
        // key the snapshot may hold is the range's to say now).
        var i: usize = 0;
        while (i < self.changes.items.len) {
            const item = self.changes.items[i];
            if (!range.contains(item.key)) {
                i += 1;
                continue;
            }
            allocator.free(item.key);
            if (item.value) |value| allocator.free(value);
            _ = self.changes.orderedRemove(i);
        }
    }

    /// The value the transaction sees for `key`. OWNED (`allocator`).
    pub fn get(self: *Transaction, allocator: Allocator, key: []const u8) platform.StoreError!?[]u8 {
        const at = self.find(key);
        if (at.found) {
            const value = self.changes.items[at.index].value orelse return null;
            return try allocator.dupe(u8, value);
        }
        if (self.hidden(key)) return null;
        return platform.storeGet(self.snapshot, allocator, platform.Bytes.from(key));
    }

    /// Whether the transaction sees `key`.
    pub fn has(self: *Transaction, scratch: Allocator, key: []const u8) platform.StoreError!bool {
        const value = (try self.get(scratch, key)) orelse return false;
        scratch.free(value);
        return true;
    }

    /// The first entry the transaction sees in `bounds`, in `direction`
    /// (the merged TransactionIterator's Seek): its own change of a key
    /// overrides the snapshot's, a deletion hides it. OWNED (`allocator`).
    pub fn first(self: *Transaction, allocator: Allocator, bounds: Bounds, direction: Direction) platform.StoreError!?Entry {
        var walk = try self.iterate(bounds, direction);
        defer walk.close();
        return walk.next(allocator);
    }

    /// Walk the merged view over `bounds` in `direction`. Close it before
    /// the transaction changes.
    pub fn iterate(self: *Transaction, bounds: Bounds, direction: Direction) platform.StoreError!Iterator {
        const cursor = try platform.openCursor(self.snapshot, bounds.platformRange(), if (direction == .forward) .forward else .reverse);
        var iterator: Iterator = .{ .transaction = self, .bounds = bounds, .direction = direction, .cursor = cursor };
        iterator.change_at = iterator.firstChange();
        return iterator;
    }

    /// The merged iterator (TransactionIterator): the snapshot's cursor and
    /// the change list, walked together.
    pub const Iterator = struct {
        transaction: *Transaction,
        bounds: Bounds,
        direction: Direction,
        cursor: *platform.StoreCursor,
        /// The snapshot's next entry, read ahead. OWNED (`held_allocator`).
        held: ?platform.KeyValue = null,
        held_allocator: ?Allocator = null,
        snapshot_done: bool = false,
        /// The next change to look at (forward: index; reverse: one past it).
        change_at: usize = 0,

        pub fn close(self: *Iterator) void {
            self.dropHeld();
            platform.closeCursor(self.cursor);
        }

        fn dropHeld(self: *Iterator) void {
            if (self.held) |kv| {
                self.held_allocator.?.free(kv.key.slice());
                self.held_allocator.?.free(kv.value.slice());
            }
            self.held = null;
        }

        fn firstChange(self: *const Iterator) usize {
            const changes = self.transaction.changes.items;
            if (self.direction == .forward) {
                var i: usize = 0;
                if (self.bounds.lower) |lower| i = self.transaction.find(lower).index;
                while (i < changes.len and self.bounds.below(changes[i].key)) i += 1;
                return i;
            }
            var i: usize = changes.len;
            if (self.bounds.upper) |upper| {
                const at = self.transaction.find(upper);
                i = if (at.found) at.index + 1 else at.index;
            }
            while (i > 0 and self.bounds.above(changes[i - 1].key)) i -= 1;
            return i;
        }

        /// The nearest change still ahead, in range.
        fn peekChange(self: *const Iterator) ?*const Change {
            const changes = self.transaction.changes.items;
            if (self.direction == .forward) {
                if (self.change_at >= changes.len) return null;
                const item = &changes[self.change_at];
                return if (self.bounds.above(item.key)) null else item;
            }
            if (self.change_at == 0) return null;
            const item = &changes[self.change_at - 1];
            return if (self.bounds.below(item.key)) null else item;
        }

        fn stepChange(self: *Iterator) void {
            if (self.direction == .forward) self.change_at += 1 else self.change_at -= 1;
        }

        fn peekSnapshot(self: *Iterator, allocator: Allocator) platform.StoreError!?platform.KeyValue {
            if (self.held) |kv| return kv;
            if (self.snapshot_done) return null;
            const kv = (try platform.cursorNext(self.cursor, allocator)) orelse {
                self.snapshot_done = true;
                return null;
            };
            self.held = kv;
            self.held_allocator = allocator;
            return kv;
        }

        /// Whether `a` comes before `b` in the walk's direction.
        fn before(self: *const Iterator, a: []const u8, b: []const u8) bool {
            const order = std.mem.order(u8, a, b);
            return if (self.direction == .forward) order == .lt else order == .gt;
        }

        /// The next entry. OWNED (`allocator`, which must be the same on
        /// every call of one walk).
        pub fn next(self: *Iterator, allocator: Allocator) platform.StoreError!?Entry {
            while (true) {
                const from_change = self.peekChange();
                const from_snapshot = try self.peekSnapshot(allocator);
                if (from_change == null and from_snapshot == null) return null;
                const take_change = if (from_change) |c| if (from_snapshot) |s| !self.before(s.key.slice(), c.key) else true else false;
                if (take_change) {
                    const item = from_change.?;
                    // The same key in the snapshot is overridden.
                    if (from_snapshot) |s| if (std.mem.eql(u8, s.key.slice(), item.key)) self.dropHeld();
                    self.stepChange();
                    const value = item.value orelse continue;
                    const key = try allocator.dupe(u8, item.key);
                    errdefer allocator.free(key);
                    return .{ .key = key, .value = try allocator.dupe(u8, value) };
                }
                const kv = from_snapshot.?;
                if (self.transaction.hidden(kv.key.slice())) {
                    self.dropHeld();
                    continue;
                }
                self.held = null;
                return .{ .key = @constCast(kv.key.slice()), .value = @constCast(kv.value.slice()) };
            }
        }
    };
};

// ======================================================================
// Tests
// ======================================================================

fn encodeOwned(allocator: Allocator, key: IDBKey) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try appendKey(&out, allocator, key);
    return out.toOwnedSlice(allocator);
}

test "the key encoding sorts as IndexedDB compares, and decodes to the key" {
    const allocator = std.testing.allocator;
    const compare = @import("key.zig").compare;
    // Sorted by IndexedDB's order: number < date < string < binary < array,
    // and within each type by value - strings by UTF-16 code unit, so
    // U+10000 (the units D800 DC00) sorts before U+FFFF.
    const keys = [_]IDBKey{
        IDBKey.number(-std.math.inf(f64)),
        IDBKey.number(-1.5),
        IDBKey.number(0),
        IDBKey.number(2),
        IDBKey.number(std.math.inf(f64)),
        IDBKey.date(-5),
        IDBKey.date(7),
        IDBKey.string(""),
        IDBKey.string("\x00"),
        IDBKey.string("a"),
        IDBKey.string("ab"),
        IDBKey.string("b"),
        IDBKey.string("\u{10000}"),
        IDBKey.string("\u{ffff}"),
        IDBKey.binary(""),
        IDBKey.binary("\x00"),
        IDBKey.binary("\x00\x00"),
        IDBKey.binary("\x01"),
        IDBKey.array(&.{}),
        IDBKey.array(&.{IDBKey.number(1)}),
        IDBKey.array(&.{ IDBKey.number(1), IDBKey.string("x") }),
        IDBKey.array(&.{IDBKey.string("a")}),
    };
    var encoded: [keys.len][]u8 = undefined;
    for (keys, 0..) |key, i| encoded[i] = try encodeOwned(allocator, key);
    defer for (encoded) |bytes| allocator.free(bytes);
    for (keys, 0..) |a, i| for (keys, 0..) |b, j| {
        const want = std.math.order(compare(a, b), 0);
        try std.testing.expectEqual(want, std.mem.order(u8, encoded[i], encoded[j]));
    };
    // Round trips; -0 is +0.
    for (keys, 0..) |key, i| {
        var reader: Reader = .{ .bytes = encoded[i] };
        var decoded = try reader.key(allocator);
        defer decoded.deinit();
        try std.testing.expect(reader.done());
        try std.testing.expectEqual(@as(i16, 0), compare(key, decoded));
    }
    const negative_zero = try encodeOwned(allocator, IDBKey.number(-0.0));
    defer allocator.free(negative_zero);
    try std.testing.expectEqualSlices(u8, encoded[2], negative_zero);
}

test "an index entry's key sorts by index key, then primary key" {
    const allocator = std.testing.allocator;
    var a: std.ArrayListUnmanaged(u8) = .empty;
    defer a.deinit(allocator);
    var b: std.ArrayListUnmanaged(u8) = .empty;
    defer b.deinit(allocator);
    // ("a", 2) < ("ab", 1): the index key decides first, a prefix before
    // its extension even when the primary key is larger.
    try appendKey(&a, allocator, IDBKey.string("a"));
    try appendKey(&a, allocator, IDBKey.number(2));
    try appendKey(&b, allocator, IDBKey.string("ab"));
    try appendKey(&b, allocator, IDBKey.number(1));
    try std.testing.expectEqual(std.math.Order.lt, std.mem.order(u8, a.items, b.items));
}

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

test "a transaction reads its own changes over its snapshot; commit and rollback" {
    const allocator = std.testing.allocator;
    const browser = try platform.createBrowserPlatform(allocator, &.{}, .{ .context = null, .post = ignoreEvent });
    defer platform.destroyBrowserPlatform(browser);
    var backing = try BackingStore.init(allocator, browser);
    {
        const t = try backing.begin();
        defer t.destroy();
        for ([_][]const u8{ "b", "d", "f" }) |key| try t.put(key, key);
        try t.commit();
    }
    const t = try backing.begin();
    defer t.destroy();
    try t.put("c", "c");
    try t.delete("d");
    try t.put("f", "F");
    const expectWalk = struct {
        fn run(txn: *Transaction, bounds: Bounds, direction: Direction, want: []const []const u8) !void {
            var walk = try txn.iterate(bounds, direction);
            defer walk.close();
            for (want) |key| {
                const entry = (try walk.next(std.testing.allocator)) orelse return error.TestEndedEarly;
                defer entry.deinit(std.testing.allocator);
                try std.testing.expectEqualStrings(key, entry.key);
            }
            try std.testing.expect((try walk.next(std.testing.allocator)) == null);
        }
    }.run;
    try expectWalk(t, .{}, .forward, &.{ "b", "c", "f" });
    try expectWalk(t, .{}, .reverse, &.{ "f", "c", "b" });
    try expectWalk(t, .{ .lower = "b", .lower_open = true, .upper = "f", .upper_open = true }, .forward, &.{"c"});
    const f = (try t.get(allocator, "f")).?;
    defer allocator.free(f);
    try std.testing.expectEqualStrings("F", f);
    // [a, d): "b" from the snapshot and "c" of its own; a put after it
    // overrides it.
    try t.deleteRange("a", "d");
    try expectWalk(t, .{}, .forward, &.{"f"});
    try t.put("b", "again");
    try expectWalk(t, .{}, .forward, &.{ "b", "f" });
    try std.testing.expect((try t.get(allocator, "c")) == null);
    t.rollback();
    try expectWalk(t, .{}, .forward, &.{ "b", "d", "f" });
}
