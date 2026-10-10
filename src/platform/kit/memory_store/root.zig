//! kit/memory_store: the storage engine (docs/platform-protocol.md 6.6) in
//! memory - an ordered, transactional key-value store with byte-ordered keys.
//! Every platform has it: it is the store of a Browser with no profile
//! directory (decision 12), and in step 0 of the platform protocol it is the
//! only engine behind the protocol (kit/sqlite and kit/leveldb join in recipes
//! step 4, when IndexedDB's persistence moves over the protocol). Nothing
//! calls the protocol's storage operations yet.
//!
//! A platform embeds a `Stores` in its per-Browser state and answers
//! `openStore` / `deleteStore` through it; the operations on a store, a
//! transaction and a cursor are this module's own and alias directly.
//!
//! Transactions: a read transaction works on a snapshot taken at its start; a
//! write transaction on a private copy that `commitTransaction` installs. One
//! writer at a time: a second `beginTransaction(.write)` while one is open is
//! `error.Conflict`. Simple and exact, not fast: copies are whole.

const std = @import("std");
const platform = @import("platform");

const Bytes = platform.Bytes;
const StoreError = platform.StoreError;

fn lock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexLock(mutex);
}

fn unlock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexUnlock(mutex);
}

const Entry = struct {
    key: []u8,
    value: []u8,
};

/// A sorted, owned list of entries.
const Table = struct {
    entries: std.ArrayList(Entry) = .empty,

    fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| {
            allocator.free(entry.key);
            allocator.free(entry.value);
        }
        self.entries.deinit(allocator);
    }

    fn clone(self: *const Table, allocator: std.mem.Allocator) StoreError!Table {
        var copy: Table = .{};
        errdefer copy.deinit(allocator);
        try copy.entries.ensureTotalCapacity(allocator, self.entries.items.len);
        for (self.entries.items) |entry| {
            const key = try allocator.dupe(u8, entry.key);
            const value = allocator.dupe(u8, entry.value) catch {
                allocator.free(key);
                return error.OutOfMemory;
            };
            copy.entries.appendAssumeCapacity(.{ .key = key, .value = value });
        }
        return copy;
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

    fn put(self: *Table, allocator: std.mem.Allocator, key: []const u8, value: []const u8) StoreError!void {
        const at = self.find(key);
        const owned_value = try allocator.dupe(u8, value);
        if (at.found) {
            allocator.free(self.entries.items[at.index].value);
            self.entries.items[at.index].value = owned_value;
            return;
        }
        errdefer allocator.free(owned_value);
        const owned_key = try allocator.dupe(u8, key);
        errdefer allocator.free(owned_key);
        try self.entries.insert(allocator, at.index, .{ .key = owned_key, .value = owned_value });
    }

    fn remove(self: *Table, allocator: std.mem.Allocator, index: usize) void {
        const entry = self.entries.orderedRemove(index);
        allocator.free(entry.key);
        allocator.free(entry.value);
    }

    fn size(self: *const Table) u64 {
        var total: u64 = 0;
        for (self.entries.items) |entry| total += entry.key.len + entry.value.len;
        return total;
    }
};

fn inRange(range: platform.KeyRange, key: []const u8) bool {
    if (range.has_lower) {
        switch (std.mem.order(u8, key, range.lower.slice())) {
            .lt => return false,
            .eq => if (range.lower_open) return false,
            .gt => {},
        }
    }
    if (range.has_upper) {
        switch (std.mem.order(u8, key, range.upper.slice())) {
            .gt => return false,
            .eq => if (range.upper_open) return false,
            .lt => {},
        }
    }
    return true;
}

const StoreData = struct {
    allocator: std.mem.Allocator,
    name: []u8,
    mutex: std.Io.Mutex = .init,
    table: Table = .{},
    writer_open: bool = false,
    closed: bool = false,

    fn destroy(self: *StoreData) void {
        self.table.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
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
        if (self.lookup(name.slice())) |i| return @ptrCast(self.stores.items[i]);
        if (!options.create) return error.NotFound;
        const data = try self.allocator.create(StoreData);
        errdefer self.allocator.destroy(data);
        data.* = .{ .allocator = self.allocator, .name = try self.allocator.dupe(u8, name.slice()) };
        errdefer self.allocator.free(data.name);
        try self.stores.append(self.allocator, data);
        return @ptrCast(data);
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
    return @ptrCast(@alignCast(store));
}

/// Stores live as long as their Browser (or until deleted): closing a handle
/// leaves the data in place.
pub fn closeStore(store: *platform.Store) void {
    _ = store;
}

const Transaction = struct {
    data: *StoreData,
    mode: platform.TransactionMode,
    view: Table,
};

fn transactionOf(transaction: *platform.StoreTransaction) *Transaction {
    return @ptrCast(@alignCast(transaction));
}

pub fn beginTransaction(store: *platform.Store, mode: platform.TransactionMode) StoreError!*platform.StoreTransaction {
    const data = storeData(store);
    lock(&data.mutex);
    defer unlock(&data.mutex);
    if (mode == .write) {
        if (data.writer_open) return error.Conflict;
    }
    const transaction = try data.allocator.create(Transaction);
    errdefer data.allocator.destroy(transaction);
    transaction.* = .{ .data = data, .mode = mode, .view = try data.table.clone(data.allocator) };
    if (mode == .write) data.writer_open = true;
    return @ptrCast(transaction);
}

fn end(transaction: *Transaction) void {
    const data = transaction.data;
    if (transaction.mode == .write) {
        lock(&data.mutex);
        data.writer_open = false;
        unlock(&data.mutex);
    }
    transaction.view.deinit(data.allocator);
    data.allocator.destroy(transaction);
}

pub fn commitTransaction(handle: *platform.StoreTransaction) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode == .write) {
        const data = transaction.data;
        lock(&data.mutex);
        var old = data.table;
        data.table = transaction.view;
        transaction.view = .{};
        unlock(&data.mutex);
        old.deinit(data.allocator);
    }
    end(transaction);
}

pub fn abortTransaction(handle: *platform.StoreTransaction) void {
    end(transactionOf(handle));
}

pub fn storeGet(handle: *platform.StoreTransaction, allocator: std.mem.Allocator, key: Bytes) StoreError!?[]u8 {
    const transaction = transactionOf(handle);
    const at = transaction.view.find(key.slice());
    if (!at.found) return null;
    return try allocator.dupe(u8, transaction.view.entries.items[at.index].value);
}

pub fn storePut(handle: *platform.StoreTransaction, key: Bytes, value: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    try transaction.view.put(transaction.data.allocator, key.slice(), value.slice());
}

pub fn storeDelete(handle: *platform.StoreTransaction, key: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    const at = transaction.view.find(key.slice());
    if (at.found) transaction.view.remove(transaction.data.allocator, at.index);
}

pub fn storeDeleteRange(handle: *platform.StoreTransaction, range: platform.KeyRange) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    var i: usize = transaction.view.entries.items.len;
    while (i > 0) {
        i -= 1;
        if (inRange(range, transaction.view.entries.items[i].key)) transaction.view.remove(transaction.data.allocator, i);
    }
}

const Cursor = struct {
    transaction: *Transaction,
    range: platform.KeyRange,
    direction: platform.CursorDirection,
    /// The next index to look at (forward), or one past it (reverse).
    next: usize,
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
        .next = if (direction == .forward) 0 else transaction.view.entries.items.len,
        .lower = lower,
        .upper = upper,
    };
    return @ptrCast(cursor);
}

pub fn cursorNext(handle: *platform.StoreCursor, allocator: std.mem.Allocator) StoreError!?platform.KeyValue {
    const cursor: *Cursor = @ptrCast(@alignCast(handle));
    const entries = cursor.transaction.view.entries.items;
    while (true) {
        const entry = switch (cursor.direction) {
            .forward => blk: {
                if (cursor.next >= entries.len) return null;
                cursor.next += 1;
                break :blk entries[cursor.next - 1];
            },
            .reverse => blk: {
                if (cursor.next == 0) return null;
                cursor.next -= 1;
                break :blk entries[cursor.next];
            },
        };
        if (!inRange(cursor.range, entry.key)) continue;
        const key = try allocator.dupe(u8, entry.key);
        errdefer allocator.free(key);
        const value = try allocator.dupe(u8, entry.value);
        return .{ .key = Bytes.from(key), .value = Bytes.from(value) };
    }
}

pub fn closeCursor(handle: *platform.StoreCursor) void {
    const cursor: *Cursor = @ptrCast(@alignCast(handle));
    const allocator = cursor.transaction.data.allocator;
    allocator.free(cursor.lower);
    allocator.free(cursor.upper);
    allocator.destroy(cursor);
}

pub fn storeSize(store: *platform.Store) StoreError!u64 {
    const data = storeData(store);
    lock(&data.mutex);
    defer unlock(&data.mutex);
    return data.table.size();
}
