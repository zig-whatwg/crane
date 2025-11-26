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

/// Database info returned by databases() method
/// https://w3c.github.io/IndexedDB/#dictdef-idbdatabaseinfo
pub const IDBDatabaseInfo = struct {
    name: []const u8,
    version: u64,
};

/// Storage key for identifying database ownership
/// Per spec: "A storage key determines which storage areas are available"
pub const StorageKey = struct {
    /// Origin string (e.g., "https://example.com")
    origin: []const u8,

    pub fn eql(self: StorageKey, other: StorageKey) bool {
        return std.mem.eql(u8, self.origin, other.origin);
    }
};

/// Database metadata stored in the database list
const DatabaseMetadata = struct {
    name: []const u8,
    version: u64,
    /// Connections to this database
    connections: std.ArrayListUnmanaged(*IDBDatabase),

    fn deinit(self: *DatabaseMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.connections.deinit(allocator);
    }
};

/// IDBFactory interface
/// https://w3c.github.io/IndexedDB/#idbfactory
///
/// The entry point for accessing IndexedDB databases.
pub const IDBFactory = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Map of storage key origin -> database name -> metadata
    /// Simplified: we use a flat map keyed by "origin:dbname"
    databases_map: std.StringHashMap(DatabaseMetadata),

    /// Storage key for this factory (determined by environment)
    storage_key: ?StorageKey,

    /// Initialize a new IDBFactory
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .databases_map = std.StringHashMap(DatabaseMetadata).init(allocator),
            .storage_key = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        var it = self.databases_map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.databases_map.deinit();
    }

    /// Set the storage key (usually derived from the origin)
    pub fn setStorageKey(self: *Self, origin: []const u8) void {
        self.storage_key = StorageKey{ .origin = origin };
    }

    /// Open a database connection
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-open
    ///
    /// Steps from spec (lines 391-463):
    /// 1. If version is 0 (zero), throw a TypeError.
    /// 2. Let environment be this's relevant settings object.
    /// 3. Let storageKey be the result of running obtain a storage key.
    /// 4. Let request be a new open request.
    /// 5. Run steps in parallel to open database connection.
    /// 6. Return a new IDBOpenDBRequest object for request.
    pub fn open(self: *Self, name: []const u8, version: ?u64) IDBError!*IDBOpenDBRequest {
        // Step 1: If version is 0, throw TypeError
        if (version) |v| {
            if (v == 0) {
                return IDBError.TypeError;
            }
        }

        // Step 3: Check storage key
        if (self.storage_key == null) {
            return IDBError.SecurityError;
        }

        // Step 4: Create new open request
        const request = try self.allocator.create(IDBOpenDBRequest);
        errdefer self.allocator.destroy(request);

        request.* = IDBOpenDBRequest.init(self.allocator);

        // Set request source info
        request.base.source_type = .factory;

        // Step 5: Open database connection (simplified - synchronous for now)
        // In a real implementation, this would be async
        const db_key = try self.makeDatabaseKey(name);
        errdefer self.allocator.free(db_key);

        const existing = self.databases_map.get(db_key);
        const target_version = version orelse if (existing) |e| e.version else 1;

        if (existing) |metadata| {
            // Database exists - check version
            if (version) |v| {
                if (v < metadata.version) {
                    // Requested version is lower than current
                    request.base.setError(IDBError.VersionError);
                    self.allocator.free(db_key);
                    return request;
                } else if (v > metadata.version) {
                    // Upgrade needed
                    request.old_version = metadata.version;
                    request.new_version = v;
                }
            }
            self.allocator.free(db_key);
        } else {
            // New database
            request.old_version = 0;
            request.new_version = target_version;

            // Create metadata entry
            const name_copy = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(name_copy);

            const metadata = DatabaseMetadata{
                .name = name_copy,
                .version = target_version,
                .connections = .{},
            };

            try self.databases_map.put(db_key, metadata);
        }

        // Create the database connection
        const db = try self.allocator.create(IDBDatabase);
        errdefer self.allocator.destroy(db);

        db.* = IDBDatabase.init(self.allocator, name, target_version);

        // Set result
        request.base.setResult(.{ .database = db });

        return request;
    }

    /// Delete a database
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-deletedatabase
    ///
    /// Steps from spec (lines 464-500):
    /// 1. Let environment be this's relevant settings object.
    /// 2. Let storageKey be the result of running obtain a storage key.
    /// 3. Let request be a new open request.
    /// 4. Run steps in parallel to delete database.
    /// 5. Return a new IDBOpenDBRequest object for request.
    pub fn deleteDatabase(self: *Self, name: []const u8) IDBError!*IDBOpenDBRequest {
        // Check storage key
        if (self.storage_key == null) {
            return IDBError.SecurityError;
        }

        // Create new open request
        const request = try self.allocator.create(IDBOpenDBRequest);
        errdefer self.allocator.destroy(request);

        request.* = IDBOpenDBRequest.init(self.allocator);

        // Find and delete database
        const db_key = try self.makeDatabaseKey(name);
        defer self.allocator.free(db_key);

        if (self.databases_map.fetchRemove(db_key)) |kv| {
            // Found and removed
            request.old_version = kv.value.version;
            request.new_version = null; // null indicates deletion

            // Clean up metadata
            self.allocator.free(kv.key);
            var metadata = kv.value;

            // Close all connections
            for (metadata.connections.items) |conn| {
                conn.close();
            }
            metadata.deinit(self.allocator);

            // Mark request as done
            request.base.setResult(.{ .undefined = {} });
        } else {
            // Database doesn't exist - still succeeds per spec
            request.old_version = 0;
            request.new_version = null;
            request.base.setResult(.{ .undefined = {} });
        }

        return request;
    }

    /// Get list of databases
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
    ///
    /// Returns a Promise that resolves to a sequence of IDBDatabaseInfo.
    pub fn databases(self: *Self) IDBError![]IDBDatabaseInfo {
        if (self.storage_key == null) {
            return IDBError.SecurityError;
        }

        const storage_key = self.storage_key.?;
        const prefix = try std.fmt.allocPrint(self.allocator, "{s}:", .{storage_key.origin});
        defer self.allocator.free(prefix);

        // Count matching databases
        var count: usize = 0;
        var it = self.databases_map.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                count += 1;
            }
        }

        // Allocate result array
        const result = try self.allocator.alloc(IDBDatabaseInfo, count);
        errdefer self.allocator.free(result);

        // Fill array
        var idx: usize = 0;
        it = self.databases_map.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                result[idx] = IDBDatabaseInfo{
                    .name = entry.value_ptr.name,
                    .version = entry.value_ptr.version,
                };
                idx += 1;
            }
        }

        return result;
    }

    /// Compare two keys
    /// https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
    ///
    /// Returns:
    /// - 1 if first > second
    /// - -1 if first < second
    /// - 0 if first == second
    pub fn cmp(_: *Self, first: IDBKey, second: IDBKey) i16 {
        return compareKeys(first, second);
    }

    // Internal helpers

    fn makeDatabaseKey(self: *Self, name: []const u8) ![]u8 {
        const storage_key = self.storage_key orelse return IDBError.SecurityError;
        return try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ storage_key.origin, name });
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
    defer allocator.free(dbs);

    try std.testing.expectEqual(@as(usize, 2), dbs.len);
}
