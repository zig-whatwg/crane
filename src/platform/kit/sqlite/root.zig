//! kit/sqlite: the storage engine (docs/platform-protocol.md 6.6) over SQLite,
//! for a Browser with a profile directory - every platform's (the user's
//! ruling, 2026-11-21: "SQLite everywhere"; Firefox and Safari keep their
//! profile state in SQLite, Chrome its cookies). A Browser with no profile
//! directory keeps kit/memory_store.
//!
//! Layout: one database file per store, `<profile>/stores/<hex(name)>.sqlite`,
//! holding one table, `kv(key BLOB PRIMARY KEY, value BLOB) WITHOUT ROWID`. A
//! BLOB compares with memcmp() and a shorter prefix first (sqlite.org
//! datatype3 "Comparison Expressions", collating sequence BINARY), which is
//! 6.6's one key order: lexicographic over unsigned bytes. A file per store
//! lets two stores' writers work at once, as 6.6's "one writer at a time" is
//! per store; deleteStore removes the files.
//!
//! Connections: SQLite's transactions are per connection, and 6.6 runs one
//! transaction per calling thread, so each transaction takes a connection of
//! its own from the store's idle list (opened on demand, returned at its
//! end): readers run beside the writer, each on its snapshot - WAL readers
//! see the database as of their read transaction's start, which `begin`
//! takes at once. One writer per store: a second write transaction while one
//! is open is error.Conflict at once, as kit/memory_store answers.
//!
//! Pragmas, where the engines that keep their profiles in SQLite agree:
//! - journal_mode=WAL: WebKit's SQLiteDatabase::open (Source/WebCore/
//!   platform/sql/SQLiteDatabase.cpp, useWALJournalMode: "PRAGMA
//!   journal_mode=WAL;") and Firefox's profile databases, whose mozStorage
//!   connection assumes it ("Normal is the suggested value for WAL journals",
//!   storage/mozStorageConnection.cpp Connection::initializeInternal).
//! - synchronous: they differ - mozStorage sets NORMAL (initializeInternal:
//!   "PRAGMA synchronous = NORMAL;", OFF on Android), WebKit leaves SQLite's
//!   default, FULL (SQLiteDatabase only offers setSynchronous()). 6.6 says a
//!   persistent store's commit is "durable on return", which in WAL mode is
//!   FULL's guarantee alone (NORMAL may roll back the last commits after a
//!   power loss: sqlite.org pragma.html#pragma_synchronous): FULL, WebKit's.
//! - busy_timeout 100 ms: mozStorage's DEFAULT_ASYNC_BUSY_TIMEOUT_MS. Only a
//!   checkpoint can make a reader wait: the profile lock keeps every other
//!   process out (kit/posix ProfileLock), and writers never queue (Conflict).
//! - temp_store=MEMORY: WebKit's SQLiteDatabase::open.
//!
//! The C API is declared here (`c`): no header is needed on any host, only
//! the library, which the adapters declare (their platform_build.zig, src/platform/
//! platform_build_protocol.zig).
const std = @import("std");
const platform = @import("platform");
const host = @import("host");

const Bytes = platform.Bytes;
const StoreError = platform.StoreError;

/// The SQLite C API this store uses (sqlite.org/c3ref).
const c = struct {
    const sqlite3 = opaque {};
    const sqlite3_stmt = opaque {};

    const OK = 0;
    const BUSY = 5;
    const LOCKED = 6;
    const NOMEM = 7;
    const READONLY = 8;
    const IOERR = 10;
    const CORRUPT = 11;
    const FULL = 13;
    const CANTOPEN = 14;
    const NOTADB = 26;
    const ROW = 100;
    const DONE = 101;

    const OPEN_READWRITE = 0x00000002;
    const OPEN_CREATE = 0x00000004;
    const OPEN_URI = 0x00000040;
    const OPEN_NOMUTEX = 0x00008000;

    /// SQLITE_TRANSIENT: SQLite copies the bound bytes before the call
    /// returns.
    const TRANSIENT: ?*const fn (?*anyopaque) callconv(.c) void = @ptrFromInt(std.math.maxInt(usize));

    extern fn sqlite3_open_v2(filename: [*:0]const u8, db: *?*sqlite3, flags: c_int, vfs: ?[*:0]const u8) c_int;
    extern fn sqlite3_close_v2(db: ?*sqlite3) c_int;
    extern fn sqlite3_exec(db: *sqlite3, sql: [*:0]const u8, callback: ?*const anyopaque, arg: ?*anyopaque, errmsg: ?*?[*:0]u8) c_int;
    extern fn sqlite3_busy_timeout(db: *sqlite3, ms: c_int) c_int;
    extern fn sqlite3_prepare_v2(db: *sqlite3, sql: [*]const u8, bytes: c_int, stmt: *?*sqlite3_stmt, tail: ?*?[*]const u8) c_int;
    extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
    extern fn sqlite3_finalize(stmt: ?*sqlite3_stmt) c_int;
    extern fn sqlite3_bind_blob(stmt: *sqlite3_stmt, index: c_int, value: ?*const anyopaque, bytes: c_int, destructor: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
    extern fn sqlite3_column_blob(stmt: *sqlite3_stmt, column: c_int) ?*const anyopaque;
    extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, column: c_int) c_int;
    extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, column: c_int) i64;
};

fn lock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexLockUncancelable(mutex);
}

fn unlock(mutex: *std.Io.Mutex) void {
    std.Io.Threaded.mutexUnlock(mutex);
}

/// A result code as the protocol's StoreError (primary codes: the low byte
/// of an extended one).
fn storeError(code: c_int) StoreError {
    return switch (code & 0xff) {
        c.NOMEM => error.OutOfMemory,
        c.BUSY, c.LOCKED => error.Conflict,
        c.CORRUPT, c.NOTADB => error.Corrupt,
        c.FULL => error.QuotaExceeded,
        else => error.Io,
    };
}

fn check(code: c_int) StoreError!void {
    if (code != c.OK) return storeError(code);
}

/// The one table of a store file, and the connection's settings.
const schema =
    \\PRAGMA journal_mode=WAL;
    \\PRAGMA synchronous=FULL;
    \\PRAGMA temp_store=MEMORY;
    \\CREATE TABLE IF NOT EXISTS kv(key BLOB PRIMARY KEY NOT NULL, value BLOB NOT NULL) WITHOUT ROWID;
;

/// One connection to a store's file.
const Connection = struct {
    db: *c.sqlite3,

    fn open(path: [:0]const u8) StoreError!Connection {
        var db: ?*c.sqlite3 = null;
        const code = c.sqlite3_open_v2(path.ptr, &db, c.OPEN_READWRITE | c.OPEN_CREATE | c.OPEN_URI | c.OPEN_NOMUTEX, null);
        if (code != c.OK) {
            _ = c.sqlite3_close_v2(db);
            return storeError(code);
        }
        const handle = db.?;
        errdefer _ = c.sqlite3_close_v2(handle);
        _ = c.sqlite3_busy_timeout(handle, 100);
        try check(c.sqlite3_exec(handle, schema, null, null, null));
        return .{ .db = handle };
    }

    fn close(self: Connection) void {
        _ = c.sqlite3_close_v2(self.db);
    }

    fn exec(self: Connection, sql: [:0]const u8) StoreError!void {
        return check(c.sqlite3_exec(self.db, sql.ptr, null, null, null));
    }

    fn prepare(self: Connection, sql: []const u8) StoreError!*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        const code = c.sqlite3_prepare_v2(self.db, sql.ptr, @intCast(sql.len), &stmt, null);
        if (code != c.OK) {
            _ = c.sqlite3_finalize(stmt);
            return storeError(code);
        }
        return stmt.?;
    }
};

fn bindBytes(stmt: *c.sqlite3_stmt, index: c_int, bytes: []const u8) StoreError!void {
    // A zero-length BLOB, never NULL: a key or value of no bytes is one.
    const empty = [_]u8{0};
    const ptr: *const anyopaque = if (bytes.len == 0) &empty else bytes.ptr;
    try check(c.sqlite3_bind_blob(stmt, index, ptr, @intCast(bytes.len), c.TRANSIENT));
}

fn columnBytes(stmt: *c.sqlite3_stmt, column: c_int) []const u8 {
    const len: usize = @intCast(c.sqlite3_column_bytes(stmt, column));
    if (len == 0) return &.{};
    const ptr: [*]const u8 = @ptrCast(c.sqlite3_column_blob(stmt, column) orelse return &.{});
    return ptr[0..len];
}

/// One store: its file and its idle connections.
const StoreData = struct {
    /// The protocol handle of this store is this field's address (as
    /// kit/memory_store's): kit/browser_state tells the engines apart by it.
    engine: platform.StorageEngine = .sqlite,
    allocator: std.mem.Allocator,
    name: []u8,
    /// The file's path, or a shared-cache memory URI for an in_memory store.
    path: [:0]u8,
    mutex: std.Io.Mutex = .init,
    writer_open: bool = false,
    idle: std.ArrayList(Connection) = .empty,
    /// An in_memory store's own connection, kept open for the store's life:
    /// a shared-cache memory database lives while one is.
    anchor: ?Connection = null,

    fn take(self: *StoreData) StoreError!Connection {
        lock(&self.mutex);
        const reused = self.idle.pop();
        unlock(&self.mutex);
        return reused orelse Connection.open(self.path);
    }

    fn give(self: *StoreData, connection: Connection) void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        self.idle.append(self.allocator, connection) catch connection.close();
    }

    fn destroy(self: *StoreData) void {
        for (self.idle.items) |connection| connection.close();
        self.idle.deinit(self.allocator);
        if (self.anchor) |connection| connection.close();
        self.allocator.free(self.path);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }
};

/// A Browser's stores under its profile directory. Embedded in kit/browser_state.
pub const Stores = struct {
    allocator: std.mem.Allocator,
    /// `<profile>/stores`, owned.
    directory: []u8,
    mutex: std.Io.Mutex = .init,
    stores: std.ArrayList(*StoreData) = .empty,

    /// The stores of the profile at `profile_dir` (made when missing).
    pub fn open(allocator: std.mem.Allocator, profile_dir: []const u8) StoreError!Stores {
        const directory = std.fs.path.join(allocator, &.{ profile_dir, "stores" }) catch return error.OutOfMemory;
        errdefer allocator.free(directory);
        std.Io.Dir.cwd().createDirPath(host.io(), directory) catch return error.Io;
        return .{ .allocator = allocator, .directory = directory };
    }

    pub fn deinit(self: *Stores) void {
        for (self.stores.items) |data| data.destroy();
        self.stores.deinit(self.allocator);
        self.allocator.free(self.directory);
    }

    fn lookup(self: *Stores, name: []const u8) ?usize {
        for (self.stores.items, 0..) |data, i| {
            if (std.mem.eql(u8, data.name, name)) return i;
        }
        return null;
    }

    /// `<directory>/<hex(name)>.sqlite`: any name, as a safe file name.
    fn pathOf(self: *const Stores, name: []const u8) StoreError![:0]u8 {
        const hex = std.fmt.allocPrint(self.allocator, "{x}", .{name}) catch return error.OutOfMemory;
        defer self.allocator.free(hex);
        return std.fmt.allocPrintSentinel(self.allocator, "{s}/{s}.sqlite", .{ self.directory, hex }, 0) catch error.OutOfMemory;
    }

    /// The protocol's `openStore`: the named store's file, made when
    /// `options.create`; NotFound otherwise when it has none. An in_memory
    /// store is a shared-cache memory database of its own.
    pub fn openStore(self: *Stores, name: platform.Str, options: platform.StoreOptions) StoreError!*platform.Store {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        if (self.lookup(name.slice())) |i| return @ptrCast(&self.stores.items[i].engine);
        const data = try self.allocator.create(StoreData);
        errdefer self.allocator.destroy(data);
        const owned_name = try self.allocator.dupe(u8, name.slice());
        errdefer self.allocator.free(owned_name);
        const path: [:0]u8 = if (options.in_memory)
            std.fmt.allocPrintSentinel(self.allocator, "file:crane-memory-{x}?mode=memory&cache=shared", .{@intFromPtr(data)}, 0) catch return error.OutOfMemory
        else
            try self.pathOf(name.slice());
        errdefer self.allocator.free(path);
        if (!options.in_memory and !options.create) {
            std.Io.Dir.cwd().access(host.io(), path, .{}) catch return error.NotFound;
        }
        data.* = .{ .allocator = self.allocator, .name = owned_name, .path = path };
        // The first connection makes the file and its table now, so a store
        // that cannot be made fails at its open.
        const first = try Connection.open(path);
        if (options.in_memory) data.anchor = first else data.idle.append(self.allocator, first) catch {
            first.close();
            return error.OutOfMemory;
        };
        errdefer if (data.anchor) |anchor| anchor.close();
        try self.stores.append(self.allocator, data);
        return @ptrCast(&data.engine);
    }

    /// The protocol's `deleteStore`: the store and its files go.
    pub fn deleteStore(self: *Stores, name: platform.Str) StoreError!void {
        lock(&self.mutex);
        defer unlock(&self.mutex);
        const i = self.lookup(name.slice()) orelse {
            // A store of an earlier Browser on this profile, never opened by
            // this one: its files.
            const path = try self.pathOf(name.slice());
            defer self.allocator.free(path);
            return deleteFiles(self.allocator, path, true);
        };
        const data = self.stores.orderedRemove(i);
        const in_memory = data.anchor != null;
        const path = self.allocator.dupe(u8, data.path) catch {
            data.destroy();
            return error.OutOfMemory;
        };
        defer self.allocator.free(path);
        data.destroy();
        if (!in_memory) try deleteFiles(self.allocator, path, false);
    }
};

/// A store file and its WAL companions.
fn deleteFiles(allocator: std.mem.Allocator, path: []const u8, must_exist: bool) StoreError!void {
    const io = host.io();
    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => if (must_exist) return error.NotFound,
        else => return error.Io,
    };
    for ([_][]const u8{ "-wal", "-shm" }) |suffix| {
        const companion = std.fmt.allocPrint(allocator, "{s}{s}", .{ path, suffix }) catch return error.OutOfMemory;
        defer allocator.free(companion);
        cwd.deleteFile(io, companion) catch {};
    }
}

fn storeData(store: *platform.Store) *StoreData {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(store));
    return @alignCast(@fieldParentPtr("engine", engine));
}

/// Stores live as long as their Browser (or until deleted): closing a handle
/// leaves the data in place, as kit/memory_store's.
pub fn closeStore(store: *platform.Store) void {
    _ = store;
}

const Transaction = struct {
    /// The handle is this field's address (see StoreData.engine).
    engine: platform.StorageEngine = .sqlite,
    data: *StoreData,
    mode: platform.TransactionMode,
    connection: Connection,
};

fn transactionOf(transaction: *platform.StoreTransaction) *Transaction {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(transaction));
    return @alignCast(@fieldParentPtr("engine", engine));
}

pub fn beginTransaction(store: *platform.Store, mode: platform.TransactionMode) StoreError!*platform.StoreTransaction {
    const data = storeData(store);
    if (mode == .write) {
        lock(&data.mutex);
        defer unlock(&data.mutex);
        if (data.writer_open) return error.Conflict;
        data.writer_open = true;
    }
    errdefer if (mode == .write) {
        lock(&data.mutex);
        data.writer_open = false;
        unlock(&data.mutex);
    };
    const connection = try data.take();
    errdefer data.give(connection);
    // A write transaction takes the write lock at once (IMMEDIATE); a read
    // one takes its snapshot at once - a WAL read transaction starts at its
    // first read - so it sees the store as of its begin, as 6.6 asks.
    switch (mode) {
        .write => try connection.exec("BEGIN IMMEDIATE;"),
        .read => {
            try connection.exec("BEGIN DEFERRED;");
            connection.exec("SELECT count(*) FROM kv WHERE 0;") catch |err| {
                connection.exec("ROLLBACK;") catch {};
                return err;
            };
        },
    }
    const transaction = data.allocator.create(Transaction) catch {
        connection.exec("ROLLBACK;") catch {};
        return error.OutOfMemory;
    };
    transaction.* = .{ .data = data, .mode = mode, .connection = connection };
    return @ptrCast(&transaction.engine);
}

fn end(transaction: *Transaction) void {
    const data = transaction.data;
    data.give(transaction.connection);
    if (transaction.mode == .write) {
        lock(&data.mutex);
        data.writer_open = false;
        unlock(&data.mutex);
    }
    data.allocator.destroy(transaction);
}

/// Durable on return (synchronous=FULL in WAL mode): the commit's frames are
/// synced to the WAL before COMMIT returns.
pub fn commitTransaction(handle: *platform.StoreTransaction) StoreError!void {
    const transaction = transactionOf(handle);
    defer end(transaction);
    transaction.connection.exec("COMMIT;") catch |err| {
        transaction.connection.exec("ROLLBACK;") catch {};
        return err;
    };
}

pub fn abortTransaction(handle: *platform.StoreTransaction) void {
    const transaction = transactionOf(handle);
    transaction.connection.exec("ROLLBACK;") catch {};
    end(transaction);
}

pub fn storeGet(handle: *platform.StoreTransaction, allocator: std.mem.Allocator, key: Bytes) StoreError!?[]u8 {
    const transaction = transactionOf(handle);
    const stmt = try transaction.connection.prepare("SELECT value FROM kv WHERE key = ?1;");
    defer _ = c.sqlite3_finalize(stmt);
    try bindBytes(stmt, 1, key.slice());
    return switch (c.sqlite3_step(stmt)) {
        c.ROW => try allocator.dupe(u8, columnBytes(stmt, 0)),
        c.DONE => null,
        else => |code| storeError(code),
    };
}

fn stepDone(stmt: *c.sqlite3_stmt) StoreError!void {
    const code = c.sqlite3_step(stmt);
    if (code != c.DONE) return storeError(code);
}

pub fn storePut(handle: *platform.StoreTransaction, key: Bytes, value: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    const stmt = try transaction.connection.prepare("INSERT OR REPLACE INTO kv(key, value) VALUES(?1, ?2);");
    defer _ = c.sqlite3_finalize(stmt);
    try bindBytes(stmt, 1, key.slice());
    try bindBytes(stmt, 2, value.slice());
    try stepDone(stmt);
}

pub fn storeDelete(handle: *platform.StoreTransaction, key: Bytes) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    const stmt = try transaction.connection.prepare("DELETE FROM kv WHERE key = ?1;");
    defer _ = c.sqlite3_finalize(stmt);
    try bindBytes(stmt, 1, key.slice());
    try stepDone(stmt);
}

/// The WHERE clause of `range` over `key` (bound as ?1 and ?2), and the
/// bounds it binds, in order.
const RangeSql = struct {
    clause: []const u8,
    binds_lower: bool,
    binds_upper: bool,

    fn of(range: platform.KeyRange) RangeSql {
        // [lower: none, open, closed][upper: none, open, closed]
        const table = [3][3][]const u8{
            .{ "1", "key < ?2", "key <= ?2" },
            .{ "key > ?1", "key > ?1 AND key < ?2", "key > ?1 AND key <= ?2" },
            .{ "key >= ?1", "key >= ?1 AND key < ?2", "key >= ?1 AND key <= ?2" },
        };
        const lower: usize = if (!range.has_lower) 0 else if (range.lower_open) 1 else 2;
        const upper: usize = if (!range.has_upper) 0 else if (range.upper_open) 1 else 2;
        return .{ .clause = table[lower][upper], .binds_lower = range.has_lower, .binds_upper = range.has_upper };
    }

    fn bind(self: RangeSql, stmt: *c.sqlite3_stmt, range: platform.KeyRange) StoreError!void {
        if (self.binds_lower) try bindBytes(stmt, 1, range.lower.slice());
        if (self.binds_upper) try bindBytes(stmt, 2, range.upper.slice());
    }
};

pub fn storeDeleteRange(handle: *platform.StoreTransaction, range: platform.KeyRange) StoreError!void {
    const transaction = transactionOf(handle);
    if (transaction.mode != .write) return error.Conflict;
    const where = RangeSql.of(range);
    var sql_buffer: [128]u8 = undefined;
    const sql = std.fmt.bufPrint(&sql_buffer, "DELETE FROM kv WHERE {s};", .{where.clause}) catch unreachable;
    const stmt = try transaction.connection.prepare(sql);
    defer _ = c.sqlite3_finalize(stmt);
    try where.bind(stmt, range);
    try stepDone(stmt);
}

const Cursor = struct {
    /// The handle is this field's address (see StoreData.engine).
    engine: platform.StorageEngine = .sqlite,
    allocator: std.mem.Allocator,
    stmt: *c.sqlite3_stmt,
    done: bool = false,
};

pub fn openCursor(handle: *platform.StoreTransaction, range: platform.KeyRange, direction: platform.CursorDirection) StoreError!*platform.StoreCursor {
    const transaction = transactionOf(handle);
    const where = RangeSql.of(range);
    var sql_buffer: [160]u8 = undefined;
    const sql = std.fmt.bufPrint(&sql_buffer, "SELECT key, value FROM kv WHERE {s} ORDER BY key {s};", .{ where.clause, if (direction == .forward) "ASC" else "DESC" }) catch unreachable;
    const stmt = try transaction.connection.prepare(sql);
    errdefer _ = c.sqlite3_finalize(stmt);
    // The bounds are bound now, copied by SQLite (SQLITE_TRANSIENT): the
    // caller's Bytes are borrowed for this call only.
    try where.bind(stmt, range);
    const cursor = try transaction.data.allocator.create(Cursor);
    cursor.* = .{ .allocator = transaction.data.allocator, .stmt = stmt };
    return @ptrCast(&cursor.engine);
}

fn cursorOf(handle: *platform.StoreCursor) *Cursor {
    const engine: *platform.StorageEngine = @ptrCast(@alignCast(handle));
    return @alignCast(@fieldParentPtr("engine", engine));
}

pub fn cursorNext(handle: *platform.StoreCursor, allocator: std.mem.Allocator) StoreError!?platform.KeyValue {
    const cursor = cursorOf(handle);
    if (cursor.done) return null;
    switch (c.sqlite3_step(cursor.stmt)) {
        c.ROW => {
            const key = try allocator.dupe(u8, columnBytes(cursor.stmt, 0));
            errdefer allocator.free(key);
            const value = try allocator.dupe(u8, columnBytes(cursor.stmt, 1));
            return .{ .key = Bytes.from(key), .value = Bytes.from(value) };
        },
        c.DONE => {
            cursor.done = true;
            return null;
        },
        else => |code| return storeError(code),
    }
}

pub fn closeCursor(handle: *platform.StoreCursor) void {
    const cursor = cursorOf(handle);
    _ = c.sqlite3_finalize(cursor.stmt);
    cursor.allocator.destroy(cursor);
}

/// The bytes of the store's keys and values (Storage 6's usage), read on a
/// connection of its own: any thread.
pub fn storeSize(store: *platform.Store) StoreError!u64 {
    const data = storeData(store);
    const connection = try data.take();
    defer data.give(connection);
    const stmt = try connection.prepare("SELECT coalesce(sum(length(key) + length(value)), 0) FROM kv;");
    defer _ = c.sqlite3_finalize(stmt);
    return switch (c.sqlite3_step(stmt)) {
        c.ROW => @intCast(@max(0, c.sqlite3_column_int64(stmt, 0))),
        else => |code| storeError(code),
    };
}

test "a range's clause and binds" {
    const all = RangeSql.of(.{});
    try std.testing.expectEqualStrings("1", all.clause);
    const both = RangeSql.of(.{ .has_lower = true, .has_upper = true, .upper_open = true });
    try std.testing.expectEqualStrings("key >= ?1 AND key < ?2", both.clause);
    const upper_only = RangeSql.of(.{ .has_upper = true });
    try std.testing.expectEqualStrings("key <= ?2", upper_only.clause);
    const lower_open = RangeSql.of(.{ .has_lower = true, .lower_open = true });
    try std.testing.expectEqualStrings("key > ?1", lower_open.clause);
}
