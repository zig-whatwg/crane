//! Object Store Persistence for IndexedDB
//!
//! Persists object store data to SQLite tables. Handles:
//! - Key encoding/decoding using IDBKEY format
//! - Value serialization (structured clone placeholder)
//! - Key path extraction for inline keys
//! - Auto-increment key generation
//!
//! ## SQLite Schema
//!
//! ```sql
//! CREATE TABLE object_store_data (
//!     object_store_id INTEGER NOT NULL,
//!     key BLOB NOT NULL COLLATE IDBKEY,
//!     value BLOB NOT NULL,
//!     PRIMARY KEY (object_store_id, key),
//!     FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
//! ) WITHOUT ROWID;
//! ```
//!
//! ## Key Encoding
//!
//! Keys are encoded as binary blobs using IDBKey encoding:
//! - Type tag (1 byte): number(1), date(2), string(3), binary(4), array(5)
//! - Data (variable): type-specific encoding for proper collation ordering
//!
//! ## Spec References
//!
//! - W3C IndexedDB 3.0: https://w3c.github.io/IndexedDB/
//! - Object Store: https://w3c.github.io/IndexedDB/#object-store-construct

const std = @import("std");
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyType = @import("key.zig").IDBKeyType;
const KeyPath = @import("key_path.zig").KeyPath;

// ============================================================================
// Key Encoding/Decoding
// ============================================================================

/// IDB Key type tags for encoding
pub const KeyTypeTag = enum(u8) {
    /// Negative infinity (for range bounds)
    neg_infinity = 0,
    /// Number (IEEE 754 double)
    number = 1,
    /// Date (milliseconds since epoch)
    date = 2,
    /// String (UTF-8)
    string = 3,
    /// Binary (ArrayBuffer)
    binary = 4,
    /// Array (ordered elements)
    array = 5,
    /// Positive infinity (for range bounds)
    pos_infinity = 255,
};

/// Encode an IDBKey to bytes for SQLite storage
pub fn encodeKey(allocator: std.mem.Allocator, key: IDBKey) ![]u8 {
    return switch (key) {
        .number => |n| try encodeNumber(allocator, n),
        .string => |s| try encodeString(allocator, s),
        .date => |d| try encodeDate(allocator, d),
        .binary => |b| try encodeBinary(allocator, b),
        .array => |arr| try encodeArray(allocator, arr),
        .none => error.InvalidKey,
    };
}

/// Encode a number key (IEEE 754 double with sign flip for ordering)
fn encodeNumber(allocator: std.mem.Allocator, value: f64) ![]u8 {
    var result = try allocator.alloc(u8, 9);
    result[0] = @intFromEnum(KeyTypeTag.number);

    // Convert to big-endian bytes with sign flip for proper ordering
    var bits: u64 = @bitCast(value);

    // Flip sign bit and conditionally flip all bits for negative numbers
    // This ensures: -Inf < -1 < 0 < 1 < Inf
    if (value < 0 or (value == 0 and 1.0 / value < 0)) {
        bits = ~bits; // Flip all bits for negative
    } else {
        bits ^= (@as(u64, 1) << 63); // Flip just sign bit for positive
    }

    // Write as big-endian
    inline for (0..8) |i| {
        result[1 + i] = @intCast((bits >> @intCast(56 - i * 8)) & 0xFF);
    }

    return result;
}

/// Encode a string key
fn encodeString(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, 1 + value.len);
    result[0] = @intFromEnum(KeyTypeTag.string);
    @memcpy(result[1..], value);
    return result;
}

/// Encode a date key (milliseconds since epoch)
fn encodeDate(allocator: std.mem.Allocator, millis: i64) ![]u8 {
    var result = try allocator.alloc(u8, 9);
    result[0] = @intFromEnum(KeyTypeTag.date);

    // Write as big-endian with offset for proper ordering
    const u: u64 = @bitCast(millis +% std.math.minInt(i64));
    inline for (0..8) |i| {
        result[1 + i] = @intCast((u >> @intCast(56 - i * 8)) & 0xFF);
    }

    return result;
}

/// Encode a binary key
fn encodeBinary(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, 1 + value.len);
    result[0] = @intFromEnum(KeyTypeTag.binary);
    @memcpy(result[1..], value);
    return result;
}

/// Encode an array key (recursive encoding of elements)
fn encodeArray(allocator: std.mem.Allocator, arr: []const IDBKey) ![]u8 {
    // Calculate total size needed
    var total_size: usize = 1 + 4; // tag + length (4 bytes)

    var encoded_elements = try allocator.alloc([]u8, arr.len);
    defer {
        for (encoded_elements) |e| {
            allocator.free(e);
        }
        allocator.free(encoded_elements);
    }

    for (arr, 0..) |elem, i| {
        encoded_elements[i] = try encodeKey(allocator, elem);
        total_size += 4 + encoded_elements[i].len; // length prefix + data
    }

    var result = try allocator.alloc(u8, total_size);
    var pos: usize = 0;

    // Type tag
    result[pos] = @intFromEnum(KeyTypeTag.array);
    pos += 1;

    // Array length (big-endian u32)
    const len_u32: u32 = @intCast(arr.len);
    result[pos] = @intCast((len_u32 >> 24) & 0xFF);
    result[pos + 1] = @intCast((len_u32 >> 16) & 0xFF);
    result[pos + 2] = @intCast((len_u32 >> 8) & 0xFF);
    result[pos + 3] = @intCast(len_u32 & 0xFF);
    pos += 4;

    // Elements with length prefix
    for (encoded_elements) |elem| {
        const elem_len: u32 = @intCast(elem.len);
        result[pos] = @intCast((elem_len >> 24) & 0xFF);
        result[pos + 1] = @intCast((elem_len >> 16) & 0xFF);
        result[pos + 2] = @intCast((elem_len >> 8) & 0xFF);
        result[pos + 3] = @intCast(elem_len & 0xFF);
        pos += 4;

        @memcpy(result[pos .. pos + elem.len], elem);
        pos += elem.len;
    }

    return result;
}

/// Decode bytes to an IDBKey
pub fn decodeKey(allocator: std.mem.Allocator, data: []const u8) !IDBKey {
    if (data.len == 0) return error.InvalidKey;

    const tag: KeyTypeTag = @enumFromInt(data[0]);

    return switch (tag) {
        .number => decodeNumber(data[1..]),
        .string => decodeString(allocator, data[1..]),
        .date => decodeDate(data[1..]),
        .binary => decodeBinary(allocator, data[1..]),
        .array => decodeArray(allocator, data[1..]),
        .neg_infinity, .pos_infinity => error.InvalidKey,
    };
}

fn decodeNumber(data: []const u8) !IDBKey {
    if (data.len < 8) return error.InvalidKey;

    // Read big-endian u64
    var bits: u64 = 0;
    inline for (0..8) |i| {
        bits |= @as(u64, data[i]) << @intCast(56 - i * 8);
    }

    // Reverse the sign flip encoding
    if ((bits & (@as(u64, 1) << 63)) != 0) {
        bits ^= (@as(u64, 1) << 63); // Positive: flip sign bit back
    } else {
        bits = ~bits; // Negative: flip all bits back
    }

    const value: f64 = @bitCast(bits);
    return IDBKey{ .number = value };
}

fn decodeString(allocator: std.mem.Allocator, data: []const u8) !IDBKey {
    const str = try allocator.dupe(u8, data);
    return IDBKey{ .string = str };
}

fn decodeDate(data: []const u8) !IDBKey {
    if (data.len < 8) return error.InvalidKey;

    var u: u64 = 0;
    inline for (0..8) |i| {
        u |= @as(u64, data[i]) << @intCast(56 - i * 8);
    }

    const millis: i64 = @bitCast(u -% @as(u64, @bitCast(std.math.minInt(i64))));
    return IDBKey{ .date = millis };
}

fn decodeBinary(allocator: std.mem.Allocator, data: []const u8) !IDBKey {
    const bin = try allocator.dupe(u8, data);
    return IDBKey{ .binary = bin };
}

fn decodeArray(allocator: std.mem.Allocator, data: []const u8) !IDBKey {
    if (data.len < 4) return error.InvalidKey;

    // Read array length (big-endian u32)
    const len: u32 = (@as(u32, data[0]) << 24) |
        (@as(u32, data[1]) << 16) |
        (@as(u32, data[2]) << 8) |
        @as(u32, data[3]);

    var elements = try allocator.alloc(IDBKey, len);
    errdefer allocator.free(elements);

    var pos: usize = 4;
    for (0..len) |i| {
        if (pos + 4 > data.len) return error.InvalidKey;

        // Read element length
        const elem_len: u32 = (@as(u32, data[pos]) << 24) |
            (@as(u32, data[pos + 1]) << 16) |
            (@as(u32, data[pos + 2]) << 8) |
            @as(u32, data[pos + 3]);
        pos += 4;

        if (pos + elem_len > data.len) return error.InvalidKey;

        elements[i] = try decodeKey(allocator, data[pos .. pos + elem_len]);
        pos += elem_len;
    }

    return IDBKey{ .array = elements };
}

// ============================================================================
// Object Store Record
// ============================================================================

/// A single record in an object store
pub const ObjectStoreRecord = struct {
    /// Primary key
    key: IDBKey,
    /// Encoded key bytes (for SQLite storage)
    encoded_key: []const u8,
    /// Value as bytes (structured clone serialized)
    value: []const u8,
    /// Allocator used
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, key: IDBKey, value: []const u8) !Self {
        const encoded = try encodeKey(allocator, key);
        errdefer allocator.free(encoded);

        const value_copy = try allocator.dupe(u8, value);
        errdefer allocator.free(value_copy);

        return Self{
            .key = key,
            .encoded_key = encoded,
            .value = value_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.encoded_key);
        self.allocator.free(self.value);
        self.* = undefined;
    }
};

// ============================================================================
// Auto-Increment Key Generator
// ============================================================================

/// Generates auto-increment keys per W3C IndexedDB spec
pub const AutoIncrementGenerator = struct {
    /// Current key generator value (next key to use)
    current: u64,
    /// Maximum value per spec (2^53 to fit in IEEE 754 double)
    pub const MAX_VALUE: u64 = 1 << 53;

    const Self = @This();

    pub fn init(start: u64) Self {
        return Self{ .current = start };
    }

    /// Generate the next auto-increment key
    pub fn next(self: *Self) !u64 {
        if (self.current >= MAX_VALUE) {
            return error.KeyGeneratorOverflow;
        }

        const key = self.current;
        self.current += 1;
        return key;
    }

    /// Possibly update generator based on a key that was just stored
    /// Per spec: If key > current, set current = floor(key) + 1
    pub fn maybeUpdateCurrent(self: *Self, key: f64) void {
        if (key >= 0 and @floor(key) >= @as(f64, @floatFromInt(self.current))) {
            const floored: u64 = @intFromFloat(@floor(key));
            if (floored < MAX_VALUE) {
                self.current = floored + 1;
            }
        }
    }

    /// Reset the generator (usually after rollback)
    pub fn reset(self: *Self, value: u64) void {
        self.current = value;
    }
};

// ============================================================================
// Object Store Persistence Manager
// ============================================================================

/// Manages persistence of object store data to SQLite
pub const ObjectStorePersistence = struct {
    /// Object store ID in SQLite
    store_id: i64,
    /// Object store name
    name: []const u8,
    /// Key path (null for out-of-line keys)
    key_path: ?[]const u8,
    /// Auto-increment generator (if enabled)
    auto_increment: ?AutoIncrementGenerator,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        store_id: i64,
        name: []const u8,
        key_path: ?[]const u8,
        auto_increment: bool,
        current_key: u64,
    ) !Self {
        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const kp_copy = if (key_path) |kp| try allocator.dupe(u8, kp) else null;
        errdefer if (kp_copy) |kp| allocator.free(kp);

        return Self{
            .store_id = store_id,
            .name = name_copy,
            .key_path = kp_copy,
            .auto_increment = if (auto_increment) AutoIncrementGenerator.init(current_key) else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        if (self.key_path) |kp| {
            self.allocator.free(kp);
        }
        self.* = undefined;
    }

    /// Check if this store uses inline keys (has key path)
    pub fn hasInlineKeys(self: Self) bool {
        return self.key_path != null;
    }

    /// Check if this store uses auto-increment
    pub fn hasAutoIncrement(self: Self) bool {
        return self.auto_increment != null;
    }

    /// Generate next auto-increment key
    pub fn generateKey(self: *Self) !u64 {
        if (self.auto_increment) |*gen| {
            return gen.next();
        }
        return error.NoAutoIncrement;
    }

    /// Update auto-increment after storing a key
    pub fn updateKeyGenerator(self: *Self, key: IDBKey) void {
        if (self.auto_increment) |*gen| {
            if (key == .number) {
                gen.maybeUpdateCurrent(key.number);
            }
        }
    }
};

// ============================================================================
// SQL Statements for Object Store Operations
// ============================================================================

pub const ObjectStoreSQL = struct {
    /// Insert or replace a record
    pub const upsert = "INSERT OR REPLACE INTO object_store_data (object_store_id, key, value) VALUES (?, ?, ?)";

    /// Select a record by key
    pub const select_by_key = "SELECT value FROM object_store_data WHERE object_store_id = ? AND key = ?";

    /// Delete a record by key
    pub const delete_by_key = "DELETE FROM object_store_data WHERE object_store_id = ? AND key = ?";

    /// Check if key exists
    pub const exists = "SELECT 1 FROM object_store_data WHERE object_store_id = ? AND key = ? LIMIT 1";

    /// Count all records
    pub const count_all = "SELECT COUNT(*) FROM object_store_data WHERE object_store_id = ?";

    /// Count records in range
    pub const count_range = "SELECT COUNT(*) FROM object_store_data WHERE object_store_id = ? AND key >= ? AND key <= ?";

    /// Delete all records
    pub const clear = "DELETE FROM object_store_data WHERE object_store_id = ?";

    /// Get all keys (ascending)
    pub const get_all_keys_asc = "SELECT key FROM object_store_data WHERE object_store_id = ? ORDER BY key ASC";

    /// Get all keys (descending)
    pub const get_all_keys_desc = "SELECT key FROM object_store_data WHERE object_store_id = ? ORDER BY key DESC";

    /// Get all records (ascending)
    pub const get_all_asc = "SELECT key, value FROM object_store_data WHERE object_store_id = ? ORDER BY key ASC";

    /// Get all records (descending)
    pub const get_all_desc = "SELECT key, value FROM object_store_data WHERE object_store_id = ? ORDER BY key DESC";
};

// ============================================================================
// Tests
// ============================================================================

test "encodeKey and decodeKey - number" {
    const allocator = std.testing.allocator;

    const key = IDBKey{ .number = 42.5 };
    const encoded = try encodeKey(allocator, key);
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(u8, @intFromEnum(KeyTypeTag.number)), encoded[0]);
    try std.testing.expectEqual(@as(usize, 9), encoded.len);

    const decoded = try decodeKey(allocator, encoded);
    try std.testing.expectEqual(key.number, decoded.number);
}

test "encodeKey and decodeKey - string" {
    const allocator = std.testing.allocator;

    const key = IDBKey{ .string = "hello" };
    const encoded = try encodeKey(allocator, key);
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(u8, @intFromEnum(KeyTypeTag.string)), encoded[0]);

    const decoded = try decodeKey(allocator, encoded);
    defer allocator.free(decoded.string);

    try std.testing.expectEqualStrings("hello", decoded.string);
}

test "encodeKey - number ordering" {
    const allocator = std.testing.allocator;

    // Test that encoded numbers sort correctly
    const neg_inf = try encodeKey(allocator, IDBKey{ .number = -std.math.inf(f64) });
    defer allocator.free(neg_inf);

    const neg_one = try encodeKey(allocator, IDBKey{ .number = -1 });
    defer allocator.free(neg_one);

    const zero = try encodeKey(allocator, IDBKey{ .number = 0 });
    defer allocator.free(zero);

    const one = try encodeKey(allocator, IDBKey{ .number = 1 });
    defer allocator.free(one);

    const pos_inf = try encodeKey(allocator, IDBKey{ .number = std.math.inf(f64) });
    defer allocator.free(pos_inf);

    // Byte-by-byte comparison should give correct ordering
    try std.testing.expect(std.mem.order(u8, neg_inf, neg_one) == .lt);
    try std.testing.expect(std.mem.order(u8, neg_one, zero) == .lt);
    try std.testing.expect(std.mem.order(u8, zero, one) == .lt);
    try std.testing.expect(std.mem.order(u8, one, pos_inf) == .lt);
}

test "AutoIncrementGenerator - basic" {
    var gen = AutoIncrementGenerator.init(1);

    try std.testing.expectEqual(@as(u64, 1), try gen.next());
    try std.testing.expectEqual(@as(u64, 2), try gen.next());
    try std.testing.expectEqual(@as(u64, 3), try gen.next());
}

test "AutoIncrementGenerator - maybeUpdateCurrent" {
    var gen = AutoIncrementGenerator.init(1);

    // Key lower than current - no update
    gen.maybeUpdateCurrent(0.5);
    try std.testing.expectEqual(@as(u64, 1), try gen.next());

    // Key higher than current - update
    gen.maybeUpdateCurrent(100.9);
    try std.testing.expectEqual(@as(u64, 101), try gen.next());
}

test "ObjectStorePersistence - init and deinit" {
    const allocator = std.testing.allocator;

    var persistence = try ObjectStorePersistence.init(
        allocator,
        1,
        "testStore",
        "id",
        true,
        1,
    );
    defer persistence.deinit();

    try std.testing.expectEqual(@as(i64, 1), persistence.store_id);
    try std.testing.expectEqualStrings("testStore", persistence.name);
    try std.testing.expect(persistence.hasInlineKeys());
    try std.testing.expect(persistence.hasAutoIncrement());
}

test "ObjectStorePersistence - out-of-line keys" {
    const allocator = std.testing.allocator;

    var persistence = try ObjectStorePersistence.init(
        allocator,
        2,
        "noKeyPath",
        null,
        false,
        0,
    );
    defer persistence.deinit();

    try std.testing.expect(!persistence.hasInlineKeys());
    try std.testing.expect(!persistence.hasAutoIncrement());
}

test "ObjectStoreRecord - init and deinit" {
    const allocator = std.testing.allocator;

    const key = IDBKey{ .number = 1 };
    var record = try ObjectStoreRecord.init(allocator, key, "test value");
    defer record.deinit();

    try std.testing.expectEqual(@as(f64, 1), record.key.number);
    try std.testing.expectEqualStrings("test value", record.value);
    try std.testing.expect(record.encoded_key.len > 0);
}
