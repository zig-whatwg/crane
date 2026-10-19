//! IndexedDB Factory Implementation
//!
//! Implements IDBFactory per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbfactory
//!
//! ## Methods
//!
//! - `open(name, version)` - Opens a connection to a database
//! - `deleteDatabase(name)` - Deletes a database
//! - `databases()` - Returns list of database info
//! - `cmp(first, second)` - Compares two keys
//!
//! ## Spec Reference
//!
//! Algorithm: "IDBFactory/open"
//! Location: specs/algorithms/IndexedDB-3.json lines 391-463

const std = @import("std");
const IDBKey = @import("key.zig").IDBKey;
const compareKeys = @import("key.zig").compare;
const IDBOpenDBRequest = @import("request.zig").IDBOpenDBRequest;
const IDBDatabase = @import("database.zig").IDBDatabase;
const IDBError = @import("errors.zig").IDBError;
const server_mod = @import("server.zig");
const IDBServer = server_mod.IDBServer;
const StorageKey = @import("../standard.zig").StorageKey;

/// Database info returned by databases() method, its name OWNED: free the
/// list with `server.freeInfos`.
/// https://w3c.github.io/IndexedDB/#dictdef-idbdatabaseinfo
pub const IDBDatabaseInfo = server_mod.DatabaseInfo;

/// IDBFactory interface, engine-free: one storage key's view of an
/// IndexedDB server (server.zig). The platform object (the IDBFactory impl)
/// uses the Browser's server directly; this view serves native callers and
/// tests, with synchronous opens and no connection queue.
/// https://w3c.github.io/IndexedDB/#idbfactory
pub const IDBFactory = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// A server of its own (`init`), used unless `shared` names another.
    own_server: IDBServer,
    /// The server this view shares with others (`initShared`): a Browser's.
    shared: ?*IDBServer = null,

    /// Storage key for this factory (determined by environment)
    storage_key: ?StorageKey,

    /// A factory with a server of its own: it shares nothing.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .own_server = IDBServer.init(allocator),
            .storage_key = null,
        };
    }

    /// A factory over `server`, shared with every other factory over it.
    pub fn initShared(allocator: std.mem.Allocator, shared: *IDBServer) Self {
        var self = init(allocator);
        self.shared = shared;
        return self;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.own_server.deinit();
    }

    pub fn server(self: *Self) *IDBServer {
        return self.shared orelse &self.own_server;
    }

    /// Set the storage key (usually derived from the origin)
    pub fn setStorageKey(self: *Self, origin: []const u8) void {
        self.storage_key = StorageKey.initBorrowed(origin);
    }

    /// Open a database connection
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-open
    pub fn open(self: *Self, name: []const u8, version: ?u64) IDBError!*IDBOpenDBRequest {
        return self.openConnection(name, version, false);
    }

    /// Script queues upgrade completion before making a version durable.
    pub fn openPending(self: *Self, name: []const u8, version: ?u64) IDBError!*IDBOpenDBRequest {
        return self.openConnection(name, version, true);
    }

    fn openConnection(self: *Self, name: []const u8, version: ?u64, pending_upgrade: bool) IDBError!*IDBOpenDBRequest {
        // Step 1: If version is 0, throw TypeError
        if (version) |v| if (v == 0) return IDBError.TypeError;
        // Step 3: Check storage key
        const storage_key = self.storage_key orelse return IDBError.SecurityError;

        const request = try self.allocator.create(IDBOpenDBRequest);
        errdefer self.allocator.destroy(request);
        request.* = IDBOpenDBRequest.init(self.allocator);
        request.base.source_type = .factory;

        const database = try self.server().uniqueDatabase(storage_key, name);
        defer self.server().release(database);
        const old_version = self.server().currentVersion(database);
        const target_version = version orelse if (old_version == 0) 1 else old_version;
        if (target_version < old_version) {
            request.base.setError(IDBError.VersionError);
            return request;
        }
        const opened = try self.server().openConnection(database, target_version, pending_upgrade, self.allocator, server_mod.Endpoint.here());
        if (opened.old_version == 0) {
            request.old_version = 0;
            request.new_version = target_version;
        } else if (target_version > opened.old_version) {
            request.old_version = opened.old_version;
            request.new_version = target_version;
        }
        request.base.setResult(.{ .database = opened.connection });
        return request;
    }

    /// Delete a database
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-deletedatabase
    pub fn deleteDatabase(self: *Self, name: []const u8) IDBError!*IDBOpenDBRequest {
        const storage_key = self.storage_key orelse return IDBError.SecurityError;
        const request = try self.allocator.create(IDBOpenDBRequest);
        errdefer self.allocator.destroy(request);
        request.* = IDBOpenDBRequest.init(self.allocator);
        const database = try self.server().uniqueDatabase(storage_key, name);
        defer self.server().release(database);
        request.old_version = self.server().deleteDatabase(database);
        request.new_version = null; // null indicates deletion
        request.base.setResult(.{ .undefined = {} });
        return request;
    }

    /// Get list of databases
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
    pub fn databases(self: *Self) IDBError![]IDBDatabaseInfo {
        const storage_key = self.storage_key orelse return IDBError.SecurityError;
        return self.server().databaseInfos(storage_key, self.allocator);
    }

    /// Compare two keys
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
    pub fn cmp(_: *Self, first: IDBKey, second: IDBKey) i16 {
        return compareKeys(first, second);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBFactory - init and deinit" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();

    try std.testing.expect(factory.storage_key == null);
}

test "IDBFactory - open requires storage key" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();

    // Without storage key, should fail
    const result = factory.open("test", null);
    try std.testing.expectError(IDBError.SecurityError, result);
}

test "IDBFactory - open with version 0 fails" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");

    // Version 0 should throw TypeError
    const result = factory.open("test", 0);
    try std.testing.expectError(IDBError.TypeError, result);
}

test "IDBFactory - open creates new database" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");

    const request = try factory.open("testdb", 1);
    defer {
        if (request.base.result) |r| {
            if (r == .database) {
                r.database.deinit();
                allocator.destroy(r.database);
            }
        }
        allocator.destroy(request);
    }

    try std.testing.expect(request.base.done_flag);
    try std.testing.expectEqual(@as(u64, 0), request.old_version);
    try std.testing.expectEqual(@as(?u64, 1), request.new_version);
}

test "IDBFactory - deleteDatabase" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");

    // First create a database
    const open_req = try factory.open("testdb", 1);
    if (open_req.base.result) |r| {
        if (r == .database) {
            r.database.deinit();
            allocator.destroy(r.database);
        }
    }
    allocator.destroy(open_req);

    // Now delete it
    const delete_req = try factory.deleteDatabase("testdb");
    defer allocator.destroy(delete_req);

    try std.testing.expect(delete_req.base.done_flag);
    try std.testing.expectEqual(@as(u64, 1), delete_req.old_version);
    try std.testing.expectEqual(@as(?u64, null), delete_req.new_version);
}

test "IDBFactory - cmp" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();

    const key1 = IDBKey.number(1);
    const key2 = IDBKey.number(2);
    const key3 = IDBKey.number(1);

    try std.testing.expectEqual(@as(i16, -1), factory.cmp(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), factory.cmp(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), factory.cmp(key1, key3));
}

test "IDBFactory - databases" {
    const allocator = std.testing.allocator;

    var factory = IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");

    // Create some databases
    const req1 = try factory.open("db1", 1);
    if (req1.base.result) |r| {
        if (r == .database) {
            r.database.deinit();
            allocator.destroy(r.database);
        }
    }
    allocator.destroy(req1);

    const req2 = try factory.open("db2", 2);
    if (req2.base.result) |r| {
        if (r == .database) {
            r.database.deinit();
            allocator.destroy(r.database);
        }
    }
    allocator.destroy(req2);

    // Get databases list
    const dbs = try factory.databases();
    defer server_mod.freeInfos(allocator, dbs);

    try std.testing.expectEqual(@as(usize, 2), dbs.len);
}
