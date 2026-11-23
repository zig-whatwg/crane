//! kit/memory_store: the storage engine (docs/platform-protocol.md 6.6) in
//! memory - an ordered, transactional key-value store with byte-ordered keys.
//! Every platform has it: it is the store of a Browser with no profile
//! directory (decision 12; the user's ruling 2026-11-21 keeps it the
//! no-profile engine), as kit/sqlite is the store of one with a profile.
//!
//! A platform embeds a `Stores` in its per-Browser state and answers
//! `openStore` / `deleteStore` through it; the operations on a store, a
//! transaction and a cursor are this module's own and alias directly.
//!
//! MULTI-VERSION (lane prof1; the integrator's plan 2026-11-21: "read
//! snapshot = sequence number, no copy"), as LevelDB keeps its versions
//! (google/leveldb, BSD-3, reproduced not copied: db/dbformat.h tags every
//! entry with the SequenceNumber of the write that made it; db/snapshot.h, a
//! snapshot IS a sequence number "kept in a doubly-linked list in the DB";
//! DBImpl::Get reads the newest entry at or below it; compaction drops what
//! no live snapshot can see):
//!
//! - Each key keeps its versions, oldest first: (commit sequence, value or
//!   deleted). The store counts its commits (`committed`).
//! - A transaction's snapshot is `committed` at its begin; it reads, for
//!   each key, the newest version at or below it. Nothing is copied, so a
//!   transaction costs the same over a store of any size. Every open
//!   transaction's snapshot is listed (`snapshots`), LevelDB's snapshot list.
//! - A write transaction keeps its changes apart (`changes`, ordered by key:
//!   a value, or a deletion) and reads them over its snapshot. Its commit
//!   appends one version per changed key at sequence `committed + 1` and
//!   then publishes that sequence - all under the store's lock, after
//!   reserving every allocation first, so a commit is whole or not at all.
//!   An abort drops the changes. One writer at a time: a second
//!   `beginTransaction(.write)` while one is open is `error.Conflict`.
//! - A commit prunes the keys it touched: of the versions at or below the
//!   oldest live snapshot, only the newest stays (no snapshot can tell the
//!   others apart), and a key whose one remaining version is a deletion no
//!   snapshot predates goes.
//! - A cursor keeps its place as a key, not an index: each step looks up
//!   the next key past it, so commits that insert or remove keys meanwhile
//!   never move it.
//!
//! The lock guards the table, the commit count and the snapshot list; it is
//! held for one lookup or one step of a cursor at a time, never across a
//! caller's work.

const std = @import("std");
const platform = @import("platform");

const Bytes = platform.Bytes;
const StoreError = platform.StoreError;

fn lock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexLockUncancelable(mutex);
}

fn unlock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexUnlock(mutex);
}

/// One value of a key, made by the commit `seq`. A null value: the commit
/// deleted the key.
const Version = struct {
    seq: u64,
    value: ?[]u8,
};

const Entry = struct {
    key: []u8,
    /// Oldest first.
    versions: std.ArrayListUnmanaged(Version) = .empty,

    /// The value a snapshot at `snapshot` reads: the newest version at or
    /// below it, or null when there is none or it is a deletion.
    fn valueAt(self: *const Entry, snapshot: u64) ?[]const u8 {
        var i = self.versions.items.len;
        while (i > 0) {
            i -= 1;
            const version = self.versions.items[i];
            if (version.seq <= snapshot) return version.value;
        }
        return null;
    }

    fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        for (self.versions.items) |version| if (version.value) |value| allocator.free(value);
        self.versions.deinit(allocator);
        allocator.free(self.key);
    }

    /// Drop the versions no snapshot at or above `oldest` can tell apart:
    /// below the newest one at or below it. True when what is left is a
    /// deletion no snapshot predates - the key can go.
    fn prune(self: *Entry, allocator: std.mem.Allocator, oldest: u64) bool {
        var keep_from: usize = 0;
        for (self.versions.items, 0..) |version, i| {
            if (version.seq <= oldest) keep_from = i;
        }
        for (self.versions.items[0..keep_from]) |version| if (version.value) |value| allocator.free(value);
        if (keep_from > 0) {
            const rest = self.versions.items.len - keep_from;
            std.mem.copyForwards(Version, self.versions.items[0..rest], self.versions.items[keep_from..]);
            self.versions.shrinkRetainingCapacity(rest);
        }
        return self.versions.items.len == 1 and self.versions.items[0].value == null and self.versions.items[0].seq <= oldest;
    }
};

/// The keys, sorted, each with its versions.
const Table = struct {
    entries: std.ArrayListUnmanaged(Entry) = .empty,

    fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        for (self.entries.items) |*entry| entry.deinit(allocator);
        self.entries.deinit(allocator);
    }

    /// The index of `key`, or where it would go.
    fn find(self: *const Table, key: []const u8) struct { index: usize, found: bool } {
        var low: usize = 0;
        var high: usize = self.entries.items.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            switch (std.mem.order(u8, self.entries.items[mid].key, key)) {
                .lt => low = mid + 1,
                .gt => high = mid,
                .eq => return .{ .index = mid, .found = true },
            }
        }
        return .{ .index = low, .found = false };
    }
};

fn inRange(range: platform.KeyRange, key: []const u8) bool {
    return !belowRange(range, key) and !aboveRange(range, key);
}

fn belowRange(range: platform.KeyRange, key: []const u8) bool {
    if (!range.has_lower) return false;
    return switch (std.mem.order(u8, key, range.lower.slice())) {
        .lt => true,
        .eq => range.lower_open,
        .gt => false,
    };
}

fn aboveRange(range: platform.KeyRange, key: []const u8) bool {
    if (!range.has_upper) return false;
    return switch (std.mem.order(u8, key, range.upper.slice())) {
        .gt => true,
        .eq => range.upper_open,
        .lt => false,
    };
}

const StoreData = struct {
    /// The protocol handle of this store is this field's address: a Browser
    /// whose stores are of two engines (kit/browser_state: kit/sqlite under
    /// a profile directory) tells them apart by it.
    engine: platform.StorageEngine = .memory,
    allocator: std.mem.Allocator,
    name: []u8,
    mutex: std.Io.Mutex = .init,
    table: Table = .{},
    /// The sequence of the last commit.
    committed: u64 = 0,
    /// The snapshots of the open transactions, one per transaction.
    snapshots: std.ArrayListUnmanaged(u64) = .empty,
    writer_open: bool = false,

    fn destroy(self: *StoreData) void {
        self.table.deinit(self.allocator);
        self.snapshots.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Under the lock: the oldest snapshot any open transaction reads, or
    /// the last commit when none is open.
    fn oldestSnapshot(self: *const StoreData) u64 {
        var oldest = self.committed;
        for (self.snapshots.items) |snapshot| oldest = @min(oldest, snapshot);
        return oldest;
    }

    /// Under the lock: forget one transaction's snapshot.
    fn dropSnapshot(self: *StoreData, snapshot: u64) void {
        for (self.snapshots.items, 0..) |held, i| {
            if (held != snapshot) continue;
            _ = self.snapshots.swapRemove(i);
            return;
        }
    }
};

/// A Browser's stores, by name. Embedded in a platform's per-Browser state.
pub const Stores = struct {
    allocator: std.mem.Allocator,
    mutex: std.Io.Mutex = .init,
    stores: std.ArrayList(*StoreData) = .empty,

    pub fn init(allocator: std.mem.Allocator) Stores {
        return .{ .allocator = allocator };
    }

    /// Every store the Browser opened goes with it.
    pub fn deinit(self: *Stores) void {
        for (self.stores.items) |data| data.destroy();
        self.stores.deinit(self.allocator);
    }

    fn lookup(self: *Stores, name: []const u8) ?usize {
        for (self.stores.items, 0..) |data, i| {
            if (std.mem.eql(u8, data.name, name)) return i;
        }
        return null;
    }

    /// The protocol's `openStore` for a Browser whose stores are these.
    pub fn open(self: *Stores, name: platform.Str, options: platform.StoreOptions) StoreError!*platform.Store {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        if (self.lookup(name.slice())) |i| return @ptrCast(&self.stores.items[i].engine);
        if (!options.create) return error.NotFound;
        const data = try self.allocator.create(StoreData);
        errdefer self.allocator.destroy(data);
        data.* = .{ .allocator = self.allocator, .name = try self.allocator.dupe(u8, name.slice()) };
        errdefer self.allocator.free(data.name);
        try self.stores.append(self.allocator, data);
        return @ptrCast(&data.engine);
    }

    /// The protocol's `deleteStore`.
    pub fn delete(self: *Stores, name: platform.Str) StoreError!void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        const i = self.lookup(name.slice()) orelse return error.NotFound;
        const data = self.stores.orderedRemove(i);
        data.destroy();
    }
};

fn storeData(store: *platform.Store) *StoreData {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(store));
    return @alignCast(@fieldParentPtr("engine", engine));
}

/// Stores live as long as their Browser (or until deleted): closing a handle
/// leaves the data in place.
pub fn closeStore(store: *platform.Store) void {
    _ = store;
}

/// A write transaction's change of one key: its new value, or null - the
/// key deleted. OWNED.
const Change = struct {
    key: []u8,
    value: ?[]u8,
    /// The commit moved the key into the table, which owns it now.
    moved: bool = false,
};

const Transaction = struct {
    /// The handle is this field's address (see StoreData.engine).
    engine: platform.StorageEngine = .memory,
    data: *StoreData,
    mode: platform.TransactionMode,
    snapshot: u64,
    /// A write transaction's changes, sorted by key.
    changes: std.ArrayListUnmanaged(Change) = .empty,

    fn findChange(self: *const Transaction, key: []const u8) struct { index: usize, found: bool } {
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

    /// Record `value` (null: a deletion) for `key`, copied.
    fn change(self: *Transaction, key: []const u8, value: ?[]const u8) StoreError!void {
        const allocator = self.data.allocator;
        const owned_value: ?[]u8 = if (value) |bytes| try allocator.dupe(u8, bytes) else null;
        errdefer if (owned_value) |bytes| allocator.free(bytes);
        const at = self.findChange(key);
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

    fn freeChanges(self: *Transaction) void {
        const allocator = self.data.allocator;
        for (self.changes.items) |item| {
            if (!item.moved) allocator.free(item.key);
            if (item.value) |value| allocator.free(value);
        }
        self.changes.deinit(allocator);
        self.changes = .empty;
    }
};

fn transactionOf(transaction: *platform.StoreTransaction) *Transaction {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(transaction));
    return @alignCast(@fieldParentPtr("engine", engine));
}

/// A snapshot (the last commit's sequence) and, for a write, the store's
/// one writer. Nothing is copied.
pub fn beginTransaction(store: *platform.Store, mode: platform.TransactionMode) StoreError!*platform.StoreTransaction {
    const data = storeData(store);
    const transaction = try data.allocator.create(Transaction);
    errdefer data.allocator.destroy(transaction);
    lock(&data.mutex);
    defer unlock(&data.mutex);
    if (mode == .write and data.writer_open) return error.Conflict;
    try data.snapshots.append(data.allocator, data.committed);
    transaction.* = .{ .data = data, .mode = mode, .snapshot = data.committed };
    if (mode == .write) data.writer_open = true;
    return @ptrCast(&transaction.engine);
}

fn end(transaction: *Transaction) void {
    const data = transaction.data;
    transaction.freeChanges();
    lock(&data.mutex);
    data.dropSnapshot(transaction.snapshot);
    if (transaction.mode == .write) data.writer_open = false;
    unlock(&data.mutex);
    data.allocator.destroy(transaction);
}

/// A write's changes become the store's at one new sequence, whole: every
/// allocation is reserved before anything is published.
pub fn commitTransaction(handle: *platform.StoreTransaction) StoreError!void {
    const transaction = transactionOf(handle);
    defer end(transaction);
    if (transaction.mode != .write or transaction.changes.items.len == 0) return;
    const data = transaction.data;
    const allocator = data.allocator;
    lock(&data.mutex);
    defer unlock(&data.mutex);

    // Reserve: a slot for each new key, a version for each existing one.
    var new_keys: usize = 0;
    for (transaction.changes.items) |item| {
        const at = data.table.find(item.key);
        if (at.found) {
            try data.table.entries.items[at.index].versions.ensureUnusedCapacity(allocator, 1);
        } else if (item.value != null) new_keys += 1;
    }
    try data.table.entries.ensureUnusedCapacity(allocator, new_keys);
    var first_versions: std.ArrayListUnmanaged(std.ArrayListUnmanaged(Version)) = .empty;
    defer first_versions.deinit(allocator);
    try first_versions.ensureTotalCapacity(allocator, new_keys);
    errdefer for (first_versions.items) |*list| list.deinit(allocator);
    for (0..new_keys) |_| {
        var list: std.ArrayListUnmanaged(Version) = .empty;
        try list.ensureTotalCapacity(allocator, 1);
        first_versions.appendAssumeCapacity(list);
    }

    // Publish: nothing below fails.
    const seq = data.committed + 1;
    var next_list: usize = 0;
    for (transaction.changes.items) |*item| {
        const at = data.table.find(item.key);
        if (at.found) {
            data.table.entries.items[at.index].versions.appendAssumeCapacity(.{ .seq = seq, .value = item.value });
            item.value = null;
            continue;
        }
        const value = item.value orelse continue;
        var versions = first_versions.items[next_list];
        next_list += 1;
        versions.appendAssumeCapacity(.{ .seq = seq, .value = value });
        // The table owns the key from here; the change keeps a view of it.
        data.table.entries.insertAssumeCapacity(at.index, .{ .key = item.key, .versions = versions });
        item.value = null;
        item.moved = true;
    }
    first_versions.clearRetainingCapacity();
    data.committed = seq;

    // Prune the keys this commit gave a second version (a key it made has
    // one), its own snapshot no longer counted.
    data.dropSnapshot(transaction.snapshot);
    transaction.snapshot = std.math.maxInt(u64);
    const oldest = data.oldestSnapshot();
    for (transaction.changes.items) |item| {
        if (item.moved) continue;
        const at = data.table.find(item.key);
        if (!at.found) continue;
        if (data.table.entries.items[at.index].prune(allocator, oldest)) {
            var removed = data.table.entries.orderedRemove(at.index);
            removed.deinit(allocator);
        }
    }
}

pub fn abortTransaction(handle: *platform.StoreTransaction) void {
    end(transactionOf(handle));
}

/// The value `transaction` reads for `key`: its own change, else its
/// snapshot's. OWNED.
pub fn storeGet(handle: *platform.StoreTransaction, allocator: std.mem.Allocator, key: Bytes) StoreError!?[]u8 {
    const transaction = transactionOf(handle);
    if (transaction.mode == .write) {
        const at = transaction.findChange(key.slice());
        if (at.found) {
            const value = transaction.changes.items[at.index].value orelse return null;
            return try allocator.dupe(u8, value);
        }
    }
    const data = transaction.data;
    lock(&data.mutex);
    defer unlock(&data.mutex);
    const at = data.table.find(key.slice());
    if (!at.found) return null;
    const value = data.table.entries.items[at.index].valueAt(transaction.snapshot) orelse return null;
    return try allocator.dupe(u8, value);
}

pub fn storePut(handle: *platform.StoreTransaction, key: Bytes, value: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    try transaction.change(key.slice(), value.slice());
}

pub fn storeDelete(handle: *platform.StoreTransaction, key: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    try transaction.change(key.slice(), null);
}

/// Every key `transaction` sees in `range` - its own changes and its
/// snapshot's keys - deleted.
pub fn storeDeleteRange(handle: *platform.StoreTransaction, range: platform.KeyRange) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    const data = transaction.data;
    const allocator = data.allocator;
    // The snapshot's live keys in the range, copied under the lock.
    var keys: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (keys.items) |key| allocator.free(key);
        keys.deinit(allocator);
    }
    {
        lock(&data.mutex);
        defer unlock(&data.mutex);
        const start = if (range.has_lower) data.table.find(range.lower.slice()).index else 0;
        for (data.table.entries.items[start..]) |entry| {
            if (aboveRange(range, entry.key)) break;
            if (!inRange(range, entry.key)) continue;
            if (entry.valueAt(transaction.snapshot) == null) continue;
            const key = try allocator.dupe(u8, entry.key);
            keys.append(allocator, key) catch |err| {
                allocator.free(key);
                return err;
            };
        }
    }
    for (keys.items) |key| try transaction.change(key, null);
    for (transaction.changes.items) |*item| {
        if (!inRange(range, item.key)) continue;
        if (item.value) |value| allocator.free(value);
        item.value = null;
    }
}

const Cursor = struct {
    /// The handle is this field's address (see StoreData.engine).
    engine: platform.StorageEngine = .memory,
    transaction: *Transaction,
    range: platform.KeyRange,
    direction: platform.CursorDirection,
    /// The key it last returned (empty and `started` false before the
    /// first): each step finds the next key past it.
    position: std.ArrayListUnmanaged(u8) = .empty,
    started: bool = false,
    /// The range's bounds, copied: the caller's Bytes are borrowed.
    lower: []u8,
    upper: []u8,
};

pub fn openCursor(handle: *platform.StoreTransaction, range: platform.KeyRange, direction: platform.CursorDirection) StoreError!*platform.StoreCursor {
    const transaction = transactionOf(handle);
    const allocator = transaction.data.allocator;
    const cursor = try allocator.create(Cursor);
    errdefer allocator.destroy(cursor);
    const lower = try allocator.dupe(u8, range.lower.slice());
    errdefer allocator.free(lower);
    const upper = try allocator.dupe(u8, range.upper.slice());
    var copied = range;
    copied.lower = Bytes.from(lower);
    copied.upper = Bytes.from(upper);
    cursor.* = .{
        .transaction = transaction,
        .range = copied,
        .direction = direction,
        .lower = lower,
        .upper = upper,
    };
    return @ptrCast(&cursor.engine);
}

fn cursorOf(handle: *platform.StoreCursor) *Cursor {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(handle));
    return @alignCast(@fieldParentPtr("engine", engine));
}

/// Whether `key` lies past the cursor's place in its direction (any key,
/// before the first step).
fn pastPosition(cursor: *const Cursor, key: []const u8) bool {
    if (!cursor.started) return true;
    const order = std.mem.order(u8, key, cursor.position.items);
    return if (cursor.direction == .forward) order == .gt else order == .lt;
}

/// Whether `a` comes before `b` in the cursor's direction.
fn before(direction: platform.CursorDirection, a: []const u8, b: []const u8) bool {
    const order = std.mem.order(u8, a, b);
    return if (direction == .forward) order == .lt else order == .gt;
}

/// Whether the cursor has walked out of its range: past the upper bound
/// going forward, below the lower going back.
fn beyondRange(cursor: *const Cursor, key: []const u8) bool {
    return if (cursor.direction == .forward) aboveRange(cursor.range, key) else belowRange(cursor.range, key);
}

/// Whether the cursor has yet to reach its range.
fn shortOfRange(cursor: *const Cursor, key: []const u8) bool {
    return if (cursor.direction == .forward) belowRange(cursor.range, key) else aboveRange(cursor.range, key);
}

/// The next key and value past the cursor's place in the transaction's
/// view - its own changes merged over its snapshot - within the range.
/// OWNED.
pub fn cursorNext(handle: *platform.StoreCursor, allocator: std.mem.Allocator) StoreError!?platform.KeyValue {
    const cursor = cursorOf(handle);
    const transaction = cursor.transaction;
    const data = transaction.data;
    while (true) {
        // The transaction's own next change past the place.
        var change: ?*const Change = null;
        if (transaction.changes.items.len != 0) change = nextChange(cursor);

        lock(&data.mutex);
        const table_entry = nextTableEntry(cursor);
        // The nearer of the two; a change of the same key overrides.
        const use_change = if (change) |c| if (table_entry) |t| !before(cursor.direction, t.key, c.key) else true else false;
        if (!use_change and table_entry == null) {
            unlock(&data.mutex);
            return null;
        }
        const key = if (use_change) change.?.key else table_entry.?.key;
        if (beyondRange(cursor, key)) {
            unlock(&data.mutex);
            return null;
        }
        const value: ?[]const u8 = if (use_change) change.?.value else table_entry.?.valueAt(transaction.snapshot);
        // The place moves to this key, whatever it holds.
        cursor.position.clearRetainingCapacity();
        cursor.position.appendSlice(data.allocator, key) catch |err| {
            unlock(&data.mutex);
            return err;
        };
        cursor.started = true;
        const live = value orelse {
            unlock(&data.mutex);
            continue;
        };
        const owned_key = allocator.dupe(u8, key) catch |err| {
            unlock(&data.mutex);
            return err;
        };
        const owned_value = allocator.dupe(u8, live) catch |err| {
            unlock(&data.mutex);
            allocator.free(owned_key);
            return err;
        };
        unlock(&data.mutex);
        return .{ .key = Bytes.from(owned_key), .value = Bytes.from(owned_value) };
    }
}

/// The transaction's first change past the cursor's place and in reach of
/// its range (a deletion included: it hides the snapshot's key).
fn nextChange(cursor: *const Cursor) ?*const Change {
    const changes = cursor.transaction.changes.items;
    if (cursor.direction == .forward) {
        var i: usize = if (cursor.started) blk: {
            const at = cursor.transaction.findChange(cursor.position.items);
            break :blk if (at.found) at.index + 1 else at.index;
        } else if (cursor.range.has_lower) cursor.transaction.findChange(cursor.range.lower.slice()).index else 0;
        while (i < changes.len) : (i += 1) {
            if (shortOfRange(cursor, changes[i].key)) continue;
            return &changes[i];
        }
        return null;
    }
    var i: usize = if (cursor.started) cursor.transaction.findChange(cursor.position.items).index else if (cursor.range.has_upper) blk: {
        const at = cursor.transaction.findChange(cursor.range.upper.slice());
        break :blk if (at.found) at.index + 1 else at.index;
    } else changes.len;
    while (i > 0) {
        i -= 1;
        if (!pastPosition(cursor, changes[i].key) or shortOfRange(cursor, changes[i].key)) continue;
        return &changes[i];
    }
    return null;
}

/// Under the lock: the table's first key past the cursor's place, in reach
/// of its range, that its snapshot can see (as a value or a deletion: a key
/// made after the snapshot is not there for it).
fn nextTableEntry(cursor: *const Cursor) ?*const Entry {
    const entries = cursor.transaction.data.table.entries.items;
    const snapshot = cursor.transaction.snapshot;
    if (cursor.direction == .forward) {
        var i: usize = if (cursor.started) blk: {
            const at = cursor.transaction.data.table.find(cursor.position.items);
            break :blk if (at.found) at.index + 1 else at.index;
        } else if (cursor.range.has_lower) cursor.transaction.data.table.find(cursor.range.lower.slice()).index else 0;
        while (i < entries.len) : (i += 1) {
            const entry = &entries[i];
            if (shortOfRange(cursor, entry.key)) continue;
            if (aboveRange(cursor.range, entry.key)) return entry;
            if (entry.valueAt(snapshot) == null) continue;
            return entry;
        }
        return null;
    }
    var i: usize = if (cursor.started) cursor.transaction.data.table.find(cursor.position.items).index else if (cursor.range.has_upper) blk: {
        const at = cursor.transaction.data.table.find(cursor.range.upper.slice());
        break :blk if (at.found) at.index + 1 else at.index;
    } else entries.len;
    while (i > 0) {
        i -= 1;
        const entry = &entries[i];
        if (!pastPosition(cursor, entry.key) or shortOfRange(cursor, entry.key)) continue;
        if (belowRange(cursor.range, entry.key)) return entry;
        if (entry.valueAt(snapshot) == null) continue;
        return entry;
    }
    return null;
}

pub fn closeCursor(handle: *platform.StoreCursor) void {
    const cursor = cursorOf(handle);
    const allocator = cursor.transaction.data.allocator;
    cursor.position.deinit(allocator);
    allocator.free(cursor.lower);
    allocator.free(cursor.upper);
    allocator.destroy(cursor);
}

/// The bytes of what the last commit holds: its keys and live values.
pub fn storeSize(store: *platform.Store) StoreError!u64 {
    const data = storeData(store);
    lock(&data.mutex);
    defer unlock(&data.mutex);
    var total: u64 = 0;
    for (data.table.entries.items) |entry| {
        const value = entry.valueAt(data.committed) orelse continue;
        total += entry.key.len + value.len;
    }
    return total;
}
