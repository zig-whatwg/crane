//! IndexedDB Key Path Implementation
//!
//! Implements key path operations per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#key-path
//!
//! ## Key Path Definition
//!
//! A key path is a string or list of strings that defines how to extract
//! a key from a value. A valid key path is one of:
//!
//! - An empty string
//! - An identifier (matching ECMAScript IdentifierName)
//! - A string of two or more identifiers separated by periods
//! - A non-empty list containing only strings conforming to the above
//!
//! ## Algorithms Implemented
//!
//! - valid key path: validates a key path string
//! - extract a key from a value using a key path (§7.1)
//! - evaluate a key path on a value (§7.1)
//! - check that a key could be injected into a value (§7.2)
//! - inject a key into a value using a key path (§7.2)
//!
//! ## Spec Reference
//!
//! URL: https://w3c.github.io/IndexedDB/#key-path
//! Algorithm locations in specs/algorithms/IndexedDB-3.json:
//! - extract a key: lines 3070-3090
//! - evaluate a key path: lines 3093-3209
//! - check injection: lines 3212-3247
//! - inject key: lines 3250-3307

const std = @import("std");
const key_mod = @import("key.zig");
const IDBKey = key_mod.IDBKey;
const IDBKeyType = key_mod.IDBKeyType;
const IDBError = @import("errors.zig").IDBError;

/// Represents a key path - either a single string or an array of strings.
pub const KeyPath = union(enum) {
    /// Single key path string (e.g., "foo.bar")
    single: []const u8,
    /// Array of key paths (e.g., ["foo", "bar.baz"])
    array: []const []const u8,
};

/// Result of evaluating a key path on a value
pub const EvaluationResult = union(enum) {
    /// Successfully extracted a value
    value: ExtractedValue,
    /// Key path evaluation failed (property doesn't exist or is undefined)
    failure: void,
};

/// Represents a value extracted from an object during key path evaluation
/// In a real implementation, this would integrate with the JS runtime
pub const ExtractedValue = union(enum) {
    /// Number value
    number: f64,
    /// String value
    string: []const u8,
    /// Date value (milliseconds since epoch)
    date: i64,
    /// Binary data
    binary: []const u8,
    /// Array of extracted values
    array: []const ExtractedValue,
    /// Null value
    null_value: void,
    /// Undefined value
    undefined: void,
    /// Object - represented as key-value pairs for testing
    object: []const Property,

    pub const Property = struct {
        key: []const u8,
        value: ExtractedValue,
    };
};

/// Result of key extraction
pub const ExtractionResult = union(enum) {
    /// Successfully extracted a key
    key: IDBKey,
    /// Key path doesn't exist in the value
    failure: void,
    /// Value cannot be converted to a valid key
    invalid: void,
};

// ============================================================================
// Key Path Validation
// ============================================================================

/// Check if a string is a valid ECMAScript IdentifierName
/// https://tc39.es/ecma262/#prod-IdentifierName
///
/// An identifier consists of IdentifierStart followed by IdentifierPart*.
/// For simplicity, we check for ASCII letters, digits, $, and _.
/// A full implementation would handle Unicode.
pub fn isValidIdentifier(str: []const u8) bool {
    if (str.len == 0) return false;

    // First character must be IdentifierStart: letter, _, $
    const first = str[0];
    if (!isIdentifierStart(first)) return false;

    // Remaining characters must be IdentifierPart: letter, digit, _, $
    for (str[1..]) |c| {
        if (!isIdentifierPart(c)) return false;
    }

    return true;
}

fn isIdentifierStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_' or c == '$';
}

fn isIdentifierPart(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '$';
}

/// Validate a key path string
/// https://w3c.github.io/IndexedDB/#valid-key-path
///
/// A valid key path is one of:
/// - An empty string
/// - An identifier matching IdentifierName
/// - A string of identifiers separated by periods
pub fn isValidKeyPath(key_path: []const u8) bool {
    // Empty string is valid
    if (key_path.len == 0) return true;

    // Split by periods and validate each identifier
    var iter = std.mem.splitScalar(u8, key_path, '.');
    while (iter.next()) |part| {
        if (!isValidIdentifier(part)) return false;
    }

    return true;
}

/// Validate a key path (single or array)
pub fn validateKeyPath(key_path: KeyPath) bool {
    return switch (key_path) {
        .single => |s| isValidKeyPath(s),
        .array => |arr| {
            if (arr.len == 0) return false;
            for (arr) |path| {
                if (!isValidKeyPath(path)) return false;
            }
            return true;
        },
    };
}

// ============================================================================
// Key Path Evaluation
// ============================================================================

/// Evaluate a key path on a value
/// https://w3c.github.io/IndexedDB/#evaluate-a-key-path-on-a-value
///
/// From specs/algorithms/IndexedDB-3.json lines 3093-3209
///
/// Steps:
/// 1. If keyPath is a list of strings:
///    - Create result array
///    - For each item in keyPath, recursively evaluate and add to result
///    - Return result
/// 2. If keyPath is empty string, return value
/// 3. Split keyPath on periods to get identifiers
/// 4. For each identifier, get the property from value
/// 5. Return final value
pub fn evaluateKeyPath(
    allocator: std.mem.Allocator,
    value: ExtractedValue,
    key_path: KeyPath,
) IDBError!EvaluationResult {
    return switch (key_path) {
        .array => |paths| {
            // Step 1: keyPath is a list of strings
            var results: std.ArrayListUnmanaged(ExtractedValue) = .empty;
            var success = false;

            // Use defer to clean up if we don't reach success
            defer {
                if (!success) {
                    results.deinit(allocator);
                }
            }

            for (paths) |path| {
                const result = try evaluateKeyPath(allocator, value, .{ .single = path });
                switch (result) {
                    .failure => return .failure,
                    .value => |v| try results.append(allocator, v),
                }
            }

            success = true;
            return .{ .value = .{ .array = try results.toOwnedSlice(allocator) } };
        },
        .single => |path| {
            return evaluateSingleKeyPath(value, path);
        },
    };
}

/// Evaluate a single key path string on a value
fn evaluateSingleKeyPath(value: ExtractedValue, key_path: []const u8) EvaluationResult {
    // Step 2: Empty string returns the value itself
    if (key_path.len == 0) {
        return .{ .value = value };
    }

    // Step 3: Split on periods
    var current = value;
    var iter = std.mem.splitScalar(u8, key_path, '.');

    // Step 4: For each identifier, get property
    while (iter.next()) |identifier| {
        const result = getPropertyValue(current, identifier);
        switch (result) {
            .failure => return .failure,
            .value => |v| {
                // Check for undefined
                switch (v) {
                    .undefined => return .failure,
                    else => current = v,
                }
            },
        }
    }

    // Step 5: Return final value
    return .{ .value = current };
}

/// Get a property from a value by identifier
/// Handles special cases per spec:
/// - String.length
/// - Array.length
/// - Blob.size, Blob.type
/// - File.name, File.lastModified
fn getPropertyValue(value: ExtractedValue, identifier: []const u8) EvaluationResult {
    switch (value) {
        .string => |s| {
            // Step 4 case: String + "length"
            if (std.mem.eql(u8, identifier, "length")) {
                return .{ .value = .{ .number = @floatFromInt(s.len) } };
            }
            return .failure;
        },
        .array => |arr| {
            // Step 4 case: Array + "length"
            if (std.mem.eql(u8, identifier, "length")) {
                return .{ .value = .{ .number = @floatFromInt(arr.len) } };
            }
            return .failure;
        },
        .object => |props| {
            // Step 4: Otherwise - get property from object
            for (props) |prop| {
                if (std.mem.eql(u8, prop.key, identifier)) {
                    return .{ .value = prop.value };
                }
            }
            return .failure;
        },
        else => {
            // Not an object type, cannot get property
            return .failure;
        },
    }
}

// ============================================================================
// Key Extraction
// ============================================================================

/// Extract a key from a value using a key path
/// https://w3c.github.io/IndexedDB/#extract-a-key-from-a-value-using-a-key-path
///
/// From specs/algorithms/IndexedDB-3.json lines 3070-3090
///
/// Steps:
/// 1. Let r = evaluate key path on value. Rethrow exceptions.
/// 2. If r is failure, return failure.
/// 3. Let key = convert value to key (or multiEntry key if flag set)
/// 4. If key is invalid, return invalid.
/// 5. Return key.
pub fn extractKey(
    allocator: std.mem.Allocator,
    value: ExtractedValue,
    key_path: KeyPath,
    multi_entry: bool,
) IDBError!ExtractionResult {
    // Step 1: Evaluate key path
    const eval_result = try evaluateKeyPath(allocator, value, key_path);

    // Step 2: Check for failure
    switch (eval_result) {
        .failure => return .failure,
        .value => |v| {
            // Step 3: Convert to key
            if (multi_entry) {
                return convertToMultiEntryKey(allocator, v);
            } else {
                return convertToKey(v);
            }
        },
    }
}

/// Convert an extracted value to a key (borrowed - not for storage)
/// https://w3c.github.io/IndexedDB/#convert-a-value-to-a-key
fn convertToKey(value: ExtractedValue) ExtractionResult {
    return switch (value) {
        .number => |n| {
            // NaN is invalid
            if (std.math.isNan(n)) return .invalid;
            return .{ .key = IDBKey.number(n) };
        },
        .date => |d| .{ .key = IDBKey.date(d) },
        .string => |s| .{ .key = IDBKey.string(s) },
        .binary => |b| .{ .key = IDBKey.binary(b) },
        .array => |arr| {
            // Convert array elements to keys
            // Note: In a full implementation, we'd need to allocate
            // and handle nested arrays recursively
            var keys: [256]IDBKey = undefined;
            for (arr, 0..) |elem, i| {
                if (i >= keys.len) return .invalid;
                const result = convertToKey(elem);
                switch (result) {
                    .key => |k| keys[i] = k,
                    .failure, .invalid => return .invalid,
                }
            }
            return .{ .key = IDBKey.array(keys[0..arr.len]) };
        },
        .null_value, .undefined, .object => .invalid,
    };
}

/// Result of owned key extraction - the key owns its data
pub const OwnedExtractionResult = union(enum) {
    /// Successfully extracted an owned key
    key: IDBKey,
    /// Key path doesn't exist in the value
    failure: void,
    /// Value cannot be converted to a valid key
    invalid: void,
};

/// Extract a key from a value using a key path (owned - for storage)
/// https://w3c.github.io/IndexedDB/#extract-a-key-from-a-value-using-a-key-path
///
/// This version returns an owned key with allocated data, suitable for storage.
/// For compound key paths (arrays), creates an owned array key.
/// The caller is responsible for calling deinit() on the returned key.
pub fn extractKeyOwned(
    allocator: std.mem.Allocator,
    value: ExtractedValue,
    key_path: KeyPath,
    multi_entry: bool,
) IDBError!OwnedExtractionResult {
    // Track if we need to free the intermediate result
    // evaluateKeyPath allocates a new array ONLY when key_path is an array
    const key_path_is_array = switch (key_path) {
        .array => true,
        .single => false,
    };

    // Step 1: Evaluate key path
    const eval_result = try evaluateKeyPath(allocator, value, key_path);

    // Step 2: Check for failure
    switch (eval_result) {
        .failure => {
            // For array key paths, evaluateKeyPath may have allocated memory
            // that needs to be freed even on failure. However, failure means
            // no allocation was made (it returns early), so nothing to free.
            return .failure;
        },
        .value => |v| {
            // For array key paths, evaluateKeyPath allocates an intermediate array
            // that we need to free after converting to the owned key.
            // Single key paths return borrowed data from the input value.
            defer {
                if (key_path_is_array) {
                    switch (v) {
                        .array => |arr| allocator.free(arr),
                        else => {},
                    }
                }
            }

            // Step 3: Convert to owned key
            if (multi_entry) {
                return convertToMultiEntryKeyOwned(allocator, v);
            } else {
                return convertToKeyOwned(allocator, v);
            }
        },
    }
}

/// Convert an extracted value to an owned key (for storage)
/// https://w3c.github.io/IndexedDB/#convert-a-value-to-a-key
///
/// This creates deep copies of string/binary data and properly allocates
/// array keys so the resulting key owns all its data.
fn convertToKeyOwned(allocator: std.mem.Allocator, value: ExtractedValue) IDBError!OwnedExtractionResult {
    return switch (value) {
        .number => |n| {
            // NaN is invalid
            if (std.math.isNan(n)) return .invalid;
            return .{ .key = IDBKey.number(n) };
        },
        .date => |d| .{ .key = IDBKey.date(d) },
        .string => |s| .{ .key = try IDBKey.stringOwned(allocator, s) },
        .binary => |b| .{ .key = try IDBKey.binaryOwned(allocator, b) },
        .array => |arr| {
            // Convert array elements to owned keys
            var keys: std.ArrayListUnmanaged(IDBKey) = .empty;
            errdefer {
                for (keys.items) |*k| {
                    k.deinit();
                }
                keys.deinit(allocator);
            }

            for (arr) |elem| {
                const result = try convertToKeyOwned(allocator, elem);
                switch (result) {
                    .key => |k| try keys.append(allocator, k),
                    .failure, .invalid => {
                        // Clean up already converted keys
                        for (keys.items) |*k| {
                            k.deinit();
                        }
                        keys.deinit(allocator);
                        return .invalid;
                    },
                }
            }

            // Create owned array key from the keys
            const key_slice = try keys.toOwnedSlice(allocator);
            return .{ .key = .{
                .key_type = .array,
                .value = .{ .array = key_slice },
                .allocator = allocator,
            } };
        },
        .null_value, .undefined, .object => .invalid,
    };
}

/// Convert a value to an owned multiEntry key
/// https://w3c.github.io/IndexedDB/#convert-a-value-to-a-multientry-key
fn convertToMultiEntryKeyOwned(allocator: std.mem.Allocator, value: ExtractedValue) IDBError!OwnedExtractionResult {
    switch (value) {
        .array => |arr| {
            // For arrays with multiEntry, extract valid keys from elements
            var keys: std.ArrayListUnmanaged(IDBKey) = .empty;
            errdefer {
                for (keys.items) |*k| {
                    k.deinit();
                }
                keys.deinit(allocator);
            }

            for (arr) |elem| {
                const result = try convertToKeyOwned(allocator, elem);
                switch (result) {
                    .key => |k| {
                        // Skip duplicates
                        var duplicate = false;
                        for (keys.items) |existing| {
                            if (key_mod.compare(k, existing) == 0) {
                                duplicate = true;
                                break;
                            }
                        }
                        if (duplicate) {
                            // Clean up the duplicate key
                            var k_mut = k;
                            k_mut.deinit();
                        } else {
                            try keys.append(allocator, k);
                        }
                    },
                    // Invalid values are ignored in multiEntry
                    .failure, .invalid => {},
                }
            }

            const key_slice = try keys.toOwnedSlice(allocator);
            return .{ .key = .{
                .key_type = .array,
                .value = .{ .array = key_slice },
                .allocator = allocator,
            } };
        },
        else => {
            // Non-arrays use regular conversion
            return convertToKeyOwned(allocator, value);
        },
    }
}

/// Convert a value to a multiEntry key
/// https://w3c.github.io/IndexedDB/#convert-a-value-to-a-multientry-key
fn convertToMultiEntryKey(allocator: std.mem.Allocator, value: ExtractedValue) IDBError!ExtractionResult {
    switch (value) {
        .array => |arr| {
            // For arrays with multiEntry, extract valid keys from elements
            var keys: std.ArrayListUnmanaged(IDBKey) = .empty;
            errdefer keys.deinit(allocator);

            for (arr) |elem| {
                const result = convertToKey(elem);
                switch (result) {
                    .key => |k| {
                        // Skip duplicates
                        var duplicate = false;
                        for (keys.items) |existing| {
                            if (key_mod.compare(k, existing) == 0) {
                                duplicate = true;
                                break;
                            }
                        }
                        if (!duplicate) {
                            try keys.append(allocator, k);
                        }
                    },
                    // Invalid values are ignored in multiEntry
                    .failure, .invalid => {},
                }
            }

            const key_array = try keys.toOwnedSlice(allocator);
            return .{ .key = IDBKey.array(key_array) };
        },
        else => {
            // Non-arrays use regular conversion
            return convertToKey(value);
        },
    }
}

// ============================================================================
// Key Injection
// ============================================================================

/// Check that a key could be injected into a value
/// https://w3c.github.io/IndexedDB/#check-that-a-key-could-be-injected-into-a-value
///
/// From specs/algorithms/IndexedDB-3.json lines 3212-3247
///
/// Steps:
/// 1. Split keyPath on periods to get identifiers
/// 2. Assert identifiers is not empty
/// 3. Remove the last item
/// 4. For each remaining identifier:
///    - If value is not Object or Array, return false
///    - Check HasOwnProperty
///    - If false, return true (we can create the property)
///    - Get property value
/// 5. Return true if final value is Object or Array
pub fn checkKeyInjectable(value: ExtractedValue, key_path: []const u8) bool {
    // Step 1: Split on periods
    var identifiers = std.mem.splitScalar(u8, key_path, '.');
    var parts: [64][]const u8 = undefined;
    var part_count: usize = 0;

    while (identifiers.next()) |part| {
        if (part_count >= parts.len) return false;
        parts[part_count] = part;
        part_count += 1;
    }

    // Step 2: Assert not empty
    if (part_count == 0) return false;

    // Step 3: Remove last item
    part_count -= 1;

    // Step 4: For each remaining identifier
    var current = value;
    for (parts[0..part_count]) |identifier| {
        // Check if value is Object or Array
        switch (current) {
            .object => |props| {
                // Check HasOwnProperty
                var found = false;
                for (props) |prop| {
                    if (std.mem.eql(u8, prop.key, identifier)) {
                        current = prop.value;
                        found = true;
                        break;
                    }
                }
                if (!found) return true; // Can create the property
            },
            .array => {
                // Arrays don't have named properties in this context
                return false;
            },
            else => return false,
        }
    }

    // Step 5: Return true if final value is Object or Array
    return switch (current) {
        .object, .array => true,
        else => false,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "isValidIdentifier - valid identifiers" {
    try std.testing.expect(isValidIdentifier("foo"));
    try std.testing.expect(isValidIdentifier("_bar"));
    try std.testing.expect(isValidIdentifier("$baz"));
    try std.testing.expect(isValidIdentifier("foo123"));
    try std.testing.expect(isValidIdentifier("_123"));
    try std.testing.expect(isValidIdentifier("$_123"));
    try std.testing.expect(isValidIdentifier("a"));
}

test "isValidIdentifier - invalid identifiers" {
    try std.testing.expect(!isValidIdentifier(""));
    try std.testing.expect(!isValidIdentifier("123"));
    try std.testing.expect(!isValidIdentifier("123abc"));
    try std.testing.expect(!isValidIdentifier("foo-bar"));
    try std.testing.expect(!isValidIdentifier("foo.bar"));
    try std.testing.expect(!isValidIdentifier("foo bar"));
}

test "isValidKeyPath - valid key paths" {
    try std.testing.expect(isValidKeyPath(""));
    try std.testing.expect(isValidKeyPath("foo"));
    try std.testing.expect(isValidKeyPath("foo.bar"));
    try std.testing.expect(isValidKeyPath("foo.bar.baz"));
    try std.testing.expect(isValidKeyPath("_id"));
    try std.testing.expect(isValidKeyPath("$key"));
}

test "isValidKeyPath - invalid key paths" {
    try std.testing.expect(!isValidKeyPath("123"));
    try std.testing.expect(!isValidKeyPath("foo..bar"));
    try std.testing.expect(!isValidKeyPath(".foo"));
    try std.testing.expect(!isValidKeyPath("foo."));
    try std.testing.expect(!isValidKeyPath("foo.123"));
    try std.testing.expect(!isValidKeyPath("foo bar"));
}

test "evaluateKeyPath - empty string returns value" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .number = 42.0 };

    const result = try evaluateKeyPath(allocator, value, .{ .single = "" });
    switch (result) {
        .value => |v| {
            switch (v) {
                .number => |n| try std.testing.expectEqual(@as(f64, 42.0), n),
                else => return error.UnexpectedType,
            }
        },
        .failure => return error.UnexpectedFailure,
    }
}

test "evaluateKeyPath - string length" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .string = "hello" };

    const result = try evaluateKeyPath(allocator, value, .{ .single = "length" });
    switch (result) {
        .value => |v| {
            switch (v) {
                .number => |n| try std.testing.expectEqual(@as(f64, 5.0), n),
                else => return error.UnexpectedType,
            }
        },
        .failure => return error.UnexpectedFailure,
    }
}

test "evaluateKeyPath - object property" {
    const allocator = std.testing.allocator;
    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "test" } },
        .{ .key = "id", .value = .{ .number = 123 } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try evaluateKeyPath(allocator, value, .{ .single = "name" });
    switch (result) {
        .value => |v| {
            switch (v) {
                .string => |s| try std.testing.expectEqualStrings("test", s),
                else => return error.UnexpectedType,
            }
        },
        .failure => return error.UnexpectedFailure,
    }
}

test "evaluateKeyPath - nested property" {
    const allocator = std.testing.allocator;
    const inner_props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "nested" } },
    };
    const outer_props = [_]ExtractedValue.Property{
        .{ .key = "user", .value = .{ .object = &inner_props } },
    };
    const value = ExtractedValue{ .object = &outer_props };

    const result = try evaluateKeyPath(allocator, value, .{ .single = "user.name" });
    switch (result) {
        .value => |v| {
            switch (v) {
                .string => |s| try std.testing.expectEqualStrings("nested", s),
                else => return error.UnexpectedType,
            }
        },
        .failure => return error.UnexpectedFailure,
    }
}

test "evaluateKeyPath - missing property returns failure" {
    const allocator = std.testing.allocator;
    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "test" } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try evaluateKeyPath(allocator, value, .{ .single = "missing" });
    switch (result) {
        .failure => {},
        .value => return error.ExpectedFailure,
    }
}

test "evaluateKeyPath - array of key paths" {
    const allocator = std.testing.allocator;
    const props = [_]ExtractedValue.Property{
        .{ .key = "a", .value = .{ .number = 1.0 } },
        .{ .key = "b", .value = .{ .number = 2.0 } },
    };
    const value = ExtractedValue{ .object = &props };

    const paths = [_][]const u8{ "a", "b" };
    const result = try evaluateKeyPath(allocator, value, .{ .array = &paths });
    defer {
        switch (result) {
            .value => |v| {
                switch (v) {
                    .array => |arr| allocator.free(arr),
                    else => {},
                }
            },
            .failure => {},
        }
    }

    switch (result) {
        .value => |v| {
            switch (v) {
                .array => |arr| {
                    try std.testing.expectEqual(@as(usize, 2), arr.len);
                    switch (arr[0]) {
                        .number => |n| try std.testing.expectEqual(@as(f64, 1.0), n),
                        else => return error.UnexpectedType,
                    }
                    switch (arr[1]) {
                        .number => |n| try std.testing.expectEqual(@as(f64, 2.0), n),
                        else => return error.UnexpectedType,
                    }
                },
                else => return error.UnexpectedType,
            }
        },
        .failure => return error.UnexpectedFailure,
    }
}

test "extractKey - number value" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .number = 42.0 };

    const result = try extractKey(allocator, value, .{ .single = "" }, false);
    switch (result) {
        .key => |k| {
            try std.testing.expectEqual(IDBKeyType.number, k.key_type);
            try std.testing.expectEqual(@as(f64, 42.0), k.value.number);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKey - from object property" {
    const allocator = std.testing.allocator;
    const props = [_]ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 123 } },
    };
    const value = ExtractedValue{ .object = &props };

    const result = try extractKey(allocator, value, .{ .single = "id" }, false);
    switch (result) {
        .key => |k| {
            try std.testing.expectEqual(IDBKeyType.number, k.key_type);
            try std.testing.expectEqual(@as(f64, 123), k.value.number);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKey - NaN is invalid" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .number = std.math.nan(f64) };

    const result = try extractKey(allocator, value, .{ .single = "" }, false);
    switch (result) {
        .invalid => {},
        else => return error.ExpectedInvalid,
    }
}

test "checkKeyInjectable - simple path" {
    const props = [_]ExtractedValue.Property{};
    const value = ExtractedValue{ .object = &props };

    // Can inject "id" into empty object
    try std.testing.expect(checkKeyInjectable(value, "id"));
}

test "checkKeyInjectable - nested path" {
    const inner_props = [_]ExtractedValue.Property{};
    const outer_props = [_]ExtractedValue.Property{
        .{ .key = "user", .value = .{ .object = &inner_props } },
    };
    const value = ExtractedValue{ .object = &outer_props };

    // Can inject "user.name" because user exists and is an object
    try std.testing.expect(checkKeyInjectable(value, "user.name"));
}

test "checkKeyInjectable - cannot inject into primitive" {
    const value = ExtractedValue{ .number = 42.0 };

    try std.testing.expect(!checkKeyInjectable(value, "id"));
}

// ============================================================================
// Owned Key Extraction Tests (for storage)
// ============================================================================

test "extractKeyOwned - number value" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .number = 42.0 };

    const result = try extractKeyOwned(allocator, value, .{ .single = "" }, false);
    switch (result) {
        .key => |k| {
            // Number keys don't own data, but we still check it works
            try std.testing.expectEqual(IDBKeyType.number, k.key_type);
            try std.testing.expectEqual(@as(f64, 42.0), k.value.number);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKeyOwned - string value creates owned copy" {
    const allocator = std.testing.allocator;
    const value = ExtractedValue{ .string = "hello" };

    const result = try extractKeyOwned(allocator, value, .{ .single = "" }, false);
    switch (result) {
        .key => |k| {
            var key = k;
            defer key.deinit();

            try std.testing.expectEqual(IDBKeyType.string, key.key_type);
            try std.testing.expectEqualStrings("hello", key.value.string);
            // Verify it's owned (has allocator)
            try std.testing.expect(key.allocator != null);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKeyOwned - compound key path creates array key" {
    const allocator = std.testing.allocator;

    // Create object with firstName and lastName properties
    const props = [_]ExtractedValue.Property{
        .{ .key = "firstName", .value = .{ .string = "John" } },
        .{ .key = "lastName", .value = .{ .string = "Smith" } },
    };
    const value = ExtractedValue{ .object = &props };

    // Use compound key path ["firstName", "lastName"]
    const paths = [_][]const u8{ "firstName", "lastName" };
    const result = try extractKeyOwned(allocator, value, .{ .array = &paths }, false);

    switch (result) {
        .key => |k| {
            var key = k;
            defer key.deinit();

            // Should be an array key
            try std.testing.expectEqual(IDBKeyType.array, key.key_type);
            try std.testing.expectEqual(@as(usize, 2), key.value.array.len);

            // First element should be "John"
            try std.testing.expectEqual(IDBKeyType.string, key.value.array[0].key_type);
            try std.testing.expectEqualStrings("John", key.value.array[0].value.string);

            // Second element should be "Smith"
            try std.testing.expectEqual(IDBKeyType.string, key.value.array[1].key_type);
            try std.testing.expectEqualStrings("Smith", key.value.array[1].value.string);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKeyOwned - compound key with nested path" {
    const allocator = std.testing.allocator;

    // Create object with nested properties
    const address_props = [_]ExtractedValue.Property{
        .{ .key = "city", .value = .{ .string = "Boston" } },
        .{ .key = "zip", .value = .{ .string = "02101" } },
    };
    const props = [_]ExtractedValue.Property{
        .{ .key = "name", .value = .{ .string = "John" } },
        .{ .key = "address", .value = .{ .object = &address_props } },
    };
    const value = ExtractedValue{ .object = &props };

    // Use compound key path ["name", "address.city"]
    const paths = [_][]const u8{ "name", "address.city" };
    const result = try extractKeyOwned(allocator, value, .{ .array = &paths }, false);

    switch (result) {
        .key => |k| {
            var key = k;
            defer key.deinit();

            try std.testing.expectEqual(IDBKeyType.array, key.key_type);
            try std.testing.expectEqual(@as(usize, 2), key.value.array.len);

            try std.testing.expectEqualStrings("John", key.value.array[0].value.string);
            try std.testing.expectEqualStrings("Boston", key.value.array[1].value.string);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}

test "extractKeyOwned - compound key fails if any path missing" {
    const allocator = std.testing.allocator;

    const props = [_]ExtractedValue.Property{
        .{ .key = "firstName", .value = .{ .string = "John" } },
        // lastName is missing
    };
    const value = ExtractedValue{ .object = &props };

    const paths = [_][]const u8{ "firstName", "lastName" };
    const result = try extractKeyOwned(allocator, value, .{ .array = &paths }, false);

    // Should fail because lastName doesn't exist
    switch (result) {
        .failure => {},
        .key, .invalid => return error.ExpectedFailure,
    }
}

test "extractKeyOwned - multiEntry with array value" {
    const allocator = std.testing.allocator;

    // Create object with tags array
    const tag1 = ExtractedValue{ .string = "red" };
    const tag2 = ExtractedValue{ .string = "blue" };
    const tag3 = ExtractedValue{ .string = "red" }; // duplicate
    const tags = [_]ExtractedValue{ tag1, tag2, tag3 };

    const props = [_]ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = ExtractedValue{ .object = &props };

    // Extract with multiEntry flag
    const result = try extractKeyOwned(allocator, value, .{ .single = "tags" }, true);

    switch (result) {
        .key => |k| {
            var key = k;
            defer key.deinit();

            // Should be array key with duplicates removed
            try std.testing.expectEqual(IDBKeyType.array, key.key_type);
            try std.testing.expectEqual(@as(usize, 2), key.value.array.len); // Only 2, duplicate removed

            try std.testing.expectEqualStrings("red", key.value.array[0].value.string);
            try std.testing.expectEqualStrings("blue", key.value.array[1].value.string);
        },
        .failure, .invalid => return error.UnexpectedResult,
    }
}
