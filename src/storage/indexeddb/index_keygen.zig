//! IndexedDB Index Key Generation
//!
//! Implements index key generation algorithms per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
//!
//! ## Overview
//!
//! When a record is stored in an object store, index keys must be generated
//! for each index that references the store. This module provides the
//! algorithms to:
//!
//! 1. Extract index keys from values using key paths
//! 2. Handle multiEntry indexes (array values create multiple entries)
//! 3. Check and enforce unique constraints
//! 4. Update all indexes when a record is stored
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
//! Steps for updating indexes (step 5 in the algorithm)

const std = @import("std");
const key_mod = @import("key.zig");
const key_path_mod = @import("key_path.zig");
const IDBKey = key_mod.IDBKey;
const IDBKeyType = key_mod.IDBKeyType;
const KeyPath = key_path_mod.KeyPath;
const ExtractedValue = key_path_mod.ExtractedValue;
const ExtractionResult = key_path_mod.ExtractionResult;
const IDBError = @import("errors.zig").IDBError;
const IDBIndex = @import("index.zig").IDBIndex;

/// Result of generating index keys for a single index
pub const IndexKeyResult = union(enum) {
    /// Successfully generated a single key (non-multiEntry or non-array)
    single_key: IDBKey,
    /// Successfully generated multiple keys (multiEntry with array)
    multi_keys: []const IDBKey,
    /// Key extraction failed (no key path match)
    failure: void,
    /// Value cannot be converted to valid key
    invalid: void,
    /// Extraction threw an exception
    exception: void,
};

/// Options for index key generation
pub const IndexKeyGenOptions = struct {
    /// Index key path
    key_path: KeyPath,
    /// Whether the index has multiEntry enabled
    multi_entry: bool = false,
    /// Whether the index has unique constraint
    unique: bool = false,
};

// ============================================================================
// Index Key Generation
// ============================================================================

/// Generate index key(s) from a value for a single index.
///
/// Implements step 5.1 of "store a record into an object store":
/// "Let index key be the result of extracting a key from a value using a key path
/// with value, index's key path, and index's multiEntry flag."
///
/// ## Spec Reference
/// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store (step 5.1)
///
/// ## Parameters
/// - `allocator`: Memory allocator for key storage
/// - `value`: The value to extract keys from
/// - `options`: Index configuration (key path, multiEntry flag)
///
/// ## Returns
/// IndexKeyResult indicating success (single or multi keys) or failure
pub fn generateIndexKey(
    allocator: std.mem.Allocator,
    value: ExtractedValue,
    options: IndexKeyGenOptions,
) IDBError!IndexKeyResult {
    // Step 5.1: Extract a key using the key path and multiEntry flag
    const result = try key_path_mod.extractKey(
        allocator,
        value,
        options.key_path,
        options.multi_entry,
    );

    return switch (result) {
        .failure => .failure,
        .invalid => .invalid,
        .key => |k| {
            // For multiEntry with array keys, we need to return multiple keys
            if (options.multi_entry and k.key_type == .array) {
                // Return the array of subkeys
                return .{ .multi_keys = k.value.array };
            } else {
                return .{ .single_key = k };
            }
        },
    };
}

/// Check if adding index keys would violate unique constraint.
///
/// Implements steps 5.3 and 5.4 of "store a record into an object store":
/// - Step 5.3: For non-multiEntry or non-array keys
/// - Step 5.4: For multiEntry with array keys
///
/// ## Spec Reference
/// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store (steps 5.3-5.4)
///
/// ## Parameters
/// - `index`: The index to check against
/// - `key_result`: The generated index key(s)
///
/// ## Returns
/// - `true` if unique constraint would be violated
/// - `false` if it's safe to add the key(s)
pub fn wouldViolateUnique(index: *const IDBIndex, key_result: IndexKeyResult) bool {
    if (!index.unique) return false;

    switch (key_result) {
        .single_key => |k| {
            // Step 5.3: Check if index already contains a record with equal key
            return indexContainsKey(index, k);
        },
        .multi_keys => |keys| {
            // Step 5.4: For multiEntry arrays, check each subkey
            for (keys) |k| {
                if (indexContainsKey(index, k)) {
                    return true;
                }
            }
            return false;
        },
        .failure, .invalid, .exception => return false,
    }
}

/// Check if an index already contains a record with the given key.
fn indexContainsKey(index: *const IDBIndex, key: IDBKey) bool {
    for (index.entries.items) |entry| {
        if (key_mod.compare(entry.index_key, key) == 0) {
            return true;
        }
    }
    return false;
}

/// Add index entries for a record.
///
/// Implements steps 5.5 and 5.6 of "store a record into an object store":
/// - Step 5.5: For non-multiEntry or non-array keys, add single entry
/// - Step 5.6: For multiEntry with array keys, add entry for each subkey
///
/// ## Spec Reference
/// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store (steps 5.5-5.6)
///
/// ## Parameters
/// - `index`: The index to add entries to
/// - `key_result`: The generated index key(s)
/// - `primary_key`: The primary key of the record
///
/// ## Returns
/// Error if allocation fails or constraint violated
pub fn addIndexEntries(
    index: *IDBIndex,
    key_result: IndexKeyResult,
    primary_key: IDBKey,
) IDBError!void {
    switch (key_result) {
        .single_key => |k| {
            // Step 5.5: Store single record in index
            try index.addEntry(k, primary_key);
        },
        .multi_keys => |keys| {
            // Step 5.6: For multiEntry arrays, store a record for each subkey
            for (keys) |k| {
                // Ignore if key is array (nested arrays not allowed in multiEntry)
                if (k.key_type != .array) {
                    try index.addEntry(k, primary_key);
                }
            }
        },
        .failure, .invalid, .exception => {
            // Step 5.2: Take no further actions for this index
        },
    }
}

/// Update all indexes when storing a record.
///
/// Implements step 5 of "store a record into an object store":
/// "For each index which references store..."
///
/// This is the main entry point for index key generation during record storage.
///
/// ## Spec Reference
/// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store (step 5)
///
/// ## Parameters
/// - `allocator`: Memory allocator
/// - `indexes`: Slice of indexes that reference the object store
/// - `value`: The value being stored
/// - `primary_key`: The primary key of the record
///
/// ## Returns
/// - `null` on success
/// - `IDBError.ConstraintError` if unique constraint violated
pub fn updateIndexesForRecord(
    allocator: std.mem.Allocator,
    indexes: []IDBIndex,
    value: ExtractedValue,
    primary_key: IDBKey,
) IDBError!void {
    // Step 5: For each index which references store
    for (indexes) |*index| {
        // Convert string key_path to KeyPath union
        const key_path: KeyPath = if (index.key_path) |kp|
            .{ .single = kp }
        else
            continue; // Skip indexes without key path

        // Step 5.1: Extract index key
        const key_result = try generateIndexKey(allocator, value, .{
            .key_path = key_path,
            .multi_entry = index.multi_entry,
            .unique = index.unique,
        });

        // Step 5.2: If exception, invalid, or failure, skip this index
        switch (key_result) {
            .failure, .invalid, .exception => continue,
            else => {},
        }

        // Steps 5.3-5.4: Check unique constraint
        if (wouldViolateUnique(index, key_result)) {
            return IDBError.ConstraintError;
        }

        // Steps 5.5-5.6: Add index entries
        try addIndexEntries(index, key_result, primary_key);
    }
}

/// Remove all index entries for a primary key.
///
/// Used when deleting or replacing a record - must remove old index entries first.
///
/// ## Parameters
/// - `indexes`: Slice of indexes that reference the object store
/// - `primary_key`: The primary key of the record being removed
pub fn removeIndexEntriesForPrimaryKey(
    indexes: []IDBIndex,
    primary_key: IDBKey,
) void {
    for (indexes) |*index| {
        index.removeEntriesForPrimaryKey(primary_key);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "generateIndexKey - simple property" {
    const allocator = std.testing.allocator;

    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "test" } },
        .{ .key = "age", .value = .{ .number = 25 } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try generateIndexKey(allocator, value, .{
        .key_path = .{ .single = "name" },
    });

    switch (result) {
        .single_key => |k| {
            try std.testing.expectEqual(IDBKeyType.string, k.key_type);
            try std.testing.expectEqualStrings("test", k.value.string);
        },
        else => return error.UnexpectedResult,
    }
}

test "generateIndexKey - nested property" {
    const allocator = std.testing.allocator;

    const inner_props = [_]ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 123 } },
    };
    const outer_props = [_]ExtractedValue.Property{
        .{ .key = "user", .value = .{ .object = &inner_props } },
    };
    const value = ExtractedValue{ .object = &outer_props };

    const result = try generateIndexKey(allocator, value, .{
        .key_path = .{ .single = "user.id" },
    });

    switch (result) {
        .single_key => |k| {
            try std.testing.expectEqual(IDBKeyType.number, k.key_type);
            try std.testing.expectEqual(@as(f64, 123), k.value.number);
        },
        else => return error.UnexpectedResult,
    }
}

test "generateIndexKey - missing property returns failure" {
    const allocator = std.testing.allocator;

    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "test" } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try generateIndexKey(allocator, value, .{
        .key_path = .{ .single = "missing" },
    });

    switch (result) {
        .failure => {},
        else => return error.ExpectedFailure,
    }
}

test "generateIndexKey - multiEntry with array" {
    const allocator = std.testing.allocator;

    // Create array value
    const arr_items = [_]ExtractedValue{
        .{ .string = "tag1" },
        .{ .string = "tag2" },
        .{ .string = "tag3" },
    };
    const props = [_]ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &arr_items } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try generateIndexKey(allocator, value, .{
        .key_path = .{ .single = "tags" },
        .multi_entry = true,
    });
    defer {
        switch (result) {
            .multi_keys => |keys| allocator.free(keys),
            else => {},
        }
    }

    switch (result) {
        .multi_keys => |keys| {
            try std.testing.expectEqual(@as(usize, 3), keys.len);
            try std.testing.expectEqual(IDBKeyType.string, keys[0].key_type);
            try std.testing.expectEqualStrings("tag1", keys[0].value.string);
        },
        else => return error.ExpectedMultiKeys,
    }
}

test "generateIndexKey - invalid value type" {
    const allocator = std.testing.allocator;

    // null cannot be converted to a key
    const value = ExtractedValue{ .null_value = {} };

    const result = try generateIndexKey(allocator, value, .{
        .key_path = .{ .single = "" },
    });

    switch (result) {
        .invalid => {},
        else => return error.ExpectedInvalid,
    }
}

test "wouldViolateUnique - detects duplicate" {
    const allocator = std.testing.allocator;

    // Setup database and transaction
    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var index = IDBIndex.init(allocator, "idx1", &store);
    defer index.deinit();
    index.unique = true;

    // Add existing entry
    try index.addEntry(IDBKey.string("existing"), IDBKey.number(1));

    // Test - same key should violate unique
    const result = IndexKeyResult{ .single_key = IDBKey.string("existing") };
    try std.testing.expect(wouldViolateUnique(&index, result));

    // Different key should not violate
    const result2 = IndexKeyResult{ .single_key = IDBKey.string("different") };
    try std.testing.expect(!wouldViolateUnique(&index, result2));
}

test "wouldViolateUnique - non-unique index allows duplicates" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var index = IDBIndex.init(allocator, "idx1", &store);
    defer index.deinit();
    index.unique = false; // Not unique

    try index.addEntry(IDBKey.string("existing"), IDBKey.number(1));

    // Same key should NOT violate when unique=false
    const result = IndexKeyResult{ .single_key = IDBKey.string("existing") };
    try std.testing.expect(!wouldViolateUnique(&index, result));
}

test "addIndexEntries - single key" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var index = IDBIndex.init(allocator, "idx1", &store);
    defer index.deinit();

    const key_result = IndexKeyResult{ .single_key = IDBKey.string("test") };
    const primary_key = IDBKey.number(42);

    try addIndexEntries(&index, key_result, primary_key);

    try std.testing.expectEqual(@as(usize, 1), index.entries.items.len);
    try std.testing.expectEqual(IDBKeyType.string, index.entries.items[0].index_key.key_type);
}

test "addIndexEntries - multi keys" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var index = IDBIndex.init(allocator, "idx1", &store);
    defer index.deinit();

    const keys = [_]IDBKey{
        IDBKey.string("tag1"),
        IDBKey.string("tag2"),
        IDBKey.string("tag3"),
    };
    const key_result = IndexKeyResult{ .multi_keys = &keys };
    const primary_key = IDBKey.number(42);

    try addIndexEntries(&index, key_result, primary_key);

    // Should have 3 entries, all pointing to same primary key
    try std.testing.expectEqual(@as(usize, 3), index.entries.items.len);
}

test "addIndexEntries - failure/invalid skipped" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var index = IDBIndex.init(allocator, "idx1", &store);
    defer index.deinit();

    const primary_key = IDBKey.number(42);

    // Failure should be skipped
    try addIndexEntries(&index, .failure, primary_key);
    try std.testing.expectEqual(@as(usize, 0), index.entries.items.len);

    // Invalid should be skipped
    try addIndexEntries(&index, .invalid, primary_key);
    try std.testing.expectEqual(@as(usize, 0), index.entries.items.len);
}

test "updateIndexesForRecord - full workflow" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Create two indexes - we'll work with them directly as an array
    // Note: We must clean up via the array since updateIndexesForRecord modifies them
    var indexes: [2]IDBIndex = undefined;
    indexes[0] = IDBIndex.init(allocator, "name_idx", &store);
    indexes[0].key_path = "name";
    indexes[1] = IDBIndex.init(allocator, "age_idx", &store);
    indexes[1].key_path = "age";

    defer {
        indexes[0].deinit();
        indexes[1].deinit();
    }

    // Create a value
    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "Alice" } },
        .{ .key = "age", .value = .{ .number = 30 } },
    };
    const value = ExtractedValue{ .object = &props };

    // Update indexes
    try updateIndexesForRecord(allocator, &indexes, value, IDBKey.number(1));

    // Both indexes should have entries
    try std.testing.expectEqual(@as(usize, 1), indexes[0].entries.items.len);
    try std.testing.expectEqual(@as(usize, 1), indexes[1].entries.items.len);
}

test "updateIndexesForRecord - unique constraint violation" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Create index directly in array to avoid copy issues
    var indexes: [1]IDBIndex = undefined;
    indexes[0] = IDBIndex.init(allocator, "email_idx", &store);
    indexes[0].key_path = "email";
    indexes[0].unique = true;
    defer indexes[0].deinit();

    // Add existing entry
    try indexes[0].addEntry(IDBKey.string("alice@example.com"), IDBKey.number(1));

    // Try to add record with same email
    const props = [_]ExtractedValue.Property{
        .{ .key = "email", .value = .{ .string = "alice@example.com" } },
    };
    const value = ExtractedValue{ .object = &props };

    // Should fail with constraint error
    const result = updateIndexesForRecord(allocator, &indexes, value, IDBKey.number(2));
    try std.testing.expectError(IDBError.ConstraintError, result);
}

test "removeIndexEntriesForPrimaryKey" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = @import("object_store.zig").IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Create index directly in array to avoid copy issues
    var indexes: [1]IDBIndex = undefined;
    indexes[0] = IDBIndex.init(allocator, "idx1", &store);
    defer indexes[0].deinit();

    // Add multiple entries with different primary keys
    try indexes[0].addEntry(IDBKey.string("a"), IDBKey.number(1));
    try indexes[0].addEntry(IDBKey.string("b"), IDBKey.number(1));
    try indexes[0].addEntry(IDBKey.string("c"), IDBKey.number(2));

    try std.testing.expectEqual(@as(usize, 3), indexes[0].entries.items.len);

    // Remove entries for primary key 1
    removeIndexEntriesForPrimaryKey(&indexes, IDBKey.number(1));

    // Should only have entry for primary key 2
    try std.testing.expectEqual(@as(usize, 1), indexes[0].entries.items.len);
    try std.testing.expectEqual(@as(f64, 2), indexes[0].entries.items[0].primary_key.value.number);
}
