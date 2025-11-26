//! IndexedDB Key Implementation
//!
//! Implements the key model per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#key-construct
//!
//! ## Key Types
//!
//! A key has an associated type which is one of: number, date, string,
//! binary, or array.
//!
//! ## Key Ordering
//!
//! Per spec (§3.1.3), the order of types is:
//! - array > binary > string > date > number
//!
//! When comparing keys of different types, the type with higher order
//! is considered greater.
//!
//! ## Spec Reference
//!
//! Algorithm: "compare two keys"
//! Location: specs/algorithms/IndexedDB-3.json lines 21-185
//! URL: https://w3c.github.io/IndexedDB/#compare-two-keys

const std = @import("std");
const IDBError = @import("errors.zig").IDBError;

/// Key type enumeration
/// https://w3c.github.io/IndexedDB/#key-type
///
/// Order matters! Per spec §3.1.3:
/// array > binary > string > date > number
///
/// We assign values so that higher type = higher enum value
pub const IDBKeyType = enum(u8) {
    number = 0,
    date = 1,
    string = 2,
    binary = 3,
    array = 4,

    /// Get the type ordering value for comparison
    /// Higher value = greater type
    pub fn order(self: IDBKeyType) u8 {
        return @intFromEnum(self);
    }
};

/// IndexedDB Key
/// https://w3c.github.io/IndexedDB/#key-construct
///
/// A key is a value used to organize and retrieve records.
pub const IDBKey = struct {
    const Self = @This();

    key_type: IDBKeyType,
    value: KeyValue,
    allocator: ?std.mem.Allocator,

    /// Key value union
    pub const KeyValue = union(IDBKeyType) {
        number: f64,
        date: i64, // milliseconds since epoch
        string: []const u8,
        binary: []const u8,
        array: []const IDBKey,
    };

    /// Create a number key
    pub fn number(val: f64) Self {
        return Self{
            .key_type = .number,
            .value = .{ .number = val },
            .allocator = null,
        };
    }

    /// Create a date key
    pub fn date(milliseconds: i64) Self {
        return Self{
            .key_type = .date,
            .value = .{ .date = milliseconds },
            .allocator = null,
        };
    }

    /// Create a string key (borrowed)
    pub fn string(val: []const u8) Self {
        return Self{
            .key_type = .string,
            .value = .{ .string = val },
            .allocator = null,
        };
    }

    /// Create a string key (owned)
    pub fn stringOwned(allocator: std.mem.Allocator, val: []const u8) !Self {
        const copy = try allocator.dupe(u8, val);
        return Self{
            .key_type = .string,
            .value = .{ .string = copy },
            .allocator = allocator,
        };
    }

    /// Create a binary key (borrowed)
    pub fn binary(val: []const u8) Self {
        return Self{
            .key_type = .binary,
            .value = .{ .binary = val },
            .allocator = null,
        };
    }

    /// Create a binary key (owned)
    pub fn binaryOwned(allocator: std.mem.Allocator, val: []const u8) !Self {
        const copy = try allocator.dupe(u8, val);
        return Self{
            .key_type = .binary,
            .value = .{ .binary = copy },
            .allocator = allocator,
        };
    }

    /// Create an array key (borrowed)
    pub fn array(val: []const IDBKey) Self {
        return Self{
            .key_type = .array,
            .value = .{ .array = val },
            .allocator = null,
        };
    }

    /// Clean up owned resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            switch (self.key_type) {
                .string => alloc.free(self.value.string),
                .binary => alloc.free(self.value.binary),
                .array => {
                    for (self.value.array) |*k| {
                        var key_mut = k.*;
                        key_mut.deinit();
                    }
                    alloc.free(self.value.array);
                },
                else => {},
            }
        }
    }

    /// Clone a key
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return switch (self.key_type) {
            .number => Self{
                .key_type = .number,
                .value = .{ .number = self.value.number },
                .allocator = null,
            },
            .date => Self{
                .key_type = .date,
                .value = .{ .date = self.value.date },
                .allocator = null,
            },
            .string => try stringOwned(allocator, self.value.string),
            .binary => try binaryOwned(allocator, self.value.binary),
            .array => {
                const arr = try allocator.alloc(IDBKey, self.value.array.len);
                errdefer allocator.free(arr);

                for (self.value.array, 0..) |k, i| {
                    arr[i] = try k.clone(allocator);
                }

                return Self{
                    .key_type = .array,
                    .value = .{ .array = arr },
                    .allocator = allocator,
                };
            },
        };
    }
};

/// Compare two keys
/// https://w3c.github.io/IndexedDB/#compare-two-keys
///
/// Algorithm from specs/algorithms/IndexedDB-3.json lines 21-185
///
/// Steps:
/// 1. Let ta be the type of a.
/// 2. Let tb be the type of b.
/// 3. If ta does not equal tb:
///    - If ta is array, return 1.
///    - If tb is array, return -1.
///    - If ta is binary, return 1.
///    - If tb is binary, return -1.
///    - If ta is string, return 1.
///    - If tb is string, return -1.
///    - If ta is date, return 1.
///    - Assert: tb is date.
///    - Return -1.
/// 4. Let va be the value of a.
/// 5. Let vb be the value of b.
/// 6. Switch on ta:
///    - number/date: Compare numerically
///    - string: Compare by code unit
///    - binary: Compare by byte
///    - array: Compare element by element
pub fn compare(a: IDBKey, b: IDBKey) i16 {
    const ta = a.key_type;
    const tb = b.key_type;

    // Step 3: Different types
    if (ta != tb) {
        // Per spec: array > binary > string > date > number
        // Check from highest to lowest
        if (ta == .array) return 1;
        if (tb == .array) return -1;
        if (ta == .binary) return 1;
        if (tb == .binary) return -1;
        if (ta == .string) return 1;
        if (tb == .string) return -1;
        if (ta == .date) return 1;
        // tb must be date, ta must be number
        return -1;
    }

    // Step 6: Same type - compare values
    return switch (ta) {
        .number => compareNumbers(a.value.number, b.value.number),
        .date => compareDates(a.value.date, b.value.date),
        .string => compareStrings(a.value.string, b.value.string),
        .binary => compareBinary(a.value.binary, b.value.binary),
        .array => compareArrays(a.value.array, b.value.array),
    };
}

/// Compare number values
fn compareNumbers(va: f64, vb: f64) i16 {
    // Handle NaN specially - NaN compares less than any value
    const a_nan = std.math.isNan(va);
    const b_nan = std.math.isNan(vb);

    if (a_nan and b_nan) return 0;
    if (a_nan) return -1;
    if (b_nan) return 1;

    if (va > vb) return 1;
    if (va < vb) return -1;
    return 0;
}

/// Compare date values (milliseconds since epoch)
fn compareDates(va: i64, vb: i64) i16 {
    if (va > vb) return 1;
    if (va < vb) return -1;
    return 0;
}

/// Compare strings by code unit
/// https://infra.spec.whatwg.org/#code-unit-less-than
fn compareStrings(va: []const u8, vb: []const u8) i16 {
    const order = std.mem.order(u8, va, vb);
    return switch (order) {
        .lt => -1,
        .gt => 1,
        .eq => 0,
    };
}

/// Compare binary by byte
/// https://infra.spec.whatwg.org/#byte-less-than
fn compareBinary(va: []const u8, vb: []const u8) i16 {
    const min_len = @min(va.len, vb.len);
    for (0..min_len) |i| {
        if (va[i] < vb[i]) return -1;
        if (va[i] > vb[i]) return 1;
    }
    if (va.len < vb.len) return -1;
    if (va.len > vb.len) return 1;
    return 0;
}

/// Compare arrays element by element
fn compareArrays(va: []const IDBKey, vb: []const IDBKey) i16 {
    const length = @min(va.len, vb.len);

    for (0..length) |i| {
        const c = compare(va[i], vb[i]);
        if (c != 0) return c;
    }

    // If all compared elements are equal, shorter array is less
    if (va.len > vb.len) return 1;
    if (va.len < vb.len) return -1;
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "IDBKey - compare numbers" {
    const key1 = IDBKey.number(1.0);
    const key2 = IDBKey.number(2.0);
    const key3 = IDBKey.number(1.0);

    try std.testing.expectEqual(@as(i16, -1), compare(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), compare(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), compare(key1, key3));
}

test "IDBKey - compare strings" {
    const key1 = IDBKey.string("apple");
    const key2 = IDBKey.string("banana");
    const key3 = IDBKey.string("apple");

    try std.testing.expectEqual(@as(i16, -1), compare(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), compare(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), compare(key1, key3));
}

test "IDBKey - compare dates" {
    const key1 = IDBKey.date(1000);
    const key2 = IDBKey.date(2000);
    const key3 = IDBKey.date(1000);

    try std.testing.expectEqual(@as(i16, -1), compare(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), compare(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), compare(key1, key3));
}

test "IDBKey - compare binary" {
    const key1 = IDBKey.binary(&[_]u8{ 1, 2, 3 });
    const key2 = IDBKey.binary(&[_]u8{ 1, 2, 4 });
    const key3 = IDBKey.binary(&[_]u8{ 1, 2, 3 });

    try std.testing.expectEqual(@as(i16, -1), compare(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), compare(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), compare(key1, key3));
}

test "IDBKey - compare different types (spec ordering)" {
    // Per spec: array > binary > string > date > number
    const number_key = IDBKey.number(100.0);
    const date_key = IDBKey.date(100);
    const string_key = IDBKey.string("a");
    const binary_key = IDBKey.binary(&[_]u8{1});
    const array_key = IDBKey.array(&[_]IDBKey{});

    // number < date
    try std.testing.expectEqual(@as(i16, -1), compare(number_key, date_key));
    try std.testing.expectEqual(@as(i16, 1), compare(date_key, number_key));

    // date < string
    try std.testing.expectEqual(@as(i16, -1), compare(date_key, string_key));
    try std.testing.expectEqual(@as(i16, 1), compare(string_key, date_key));

    // string < binary
    try std.testing.expectEqual(@as(i16, -1), compare(string_key, binary_key));
    try std.testing.expectEqual(@as(i16, 1), compare(binary_key, string_key));

    // binary < array
    try std.testing.expectEqual(@as(i16, -1), compare(binary_key, array_key));
    try std.testing.expectEqual(@as(i16, 1), compare(array_key, binary_key));

    // number < array (extreme case)
    try std.testing.expectEqual(@as(i16, -1), compare(number_key, array_key));
    try std.testing.expectEqual(@as(i16, 1), compare(array_key, number_key));
}

test "IDBKey - compare arrays" {
    const arr1 = [_]IDBKey{ IDBKey.number(1), IDBKey.number(2) };
    const arr2 = [_]IDBKey{ IDBKey.number(1), IDBKey.number(3) };
    const arr3 = [_]IDBKey{ IDBKey.number(1), IDBKey.number(2) };
    const arr4 = [_]IDBKey{IDBKey.number(1)};

    const key1 = IDBKey.array(&arr1);
    const key2 = IDBKey.array(&arr2);
    const key3 = IDBKey.array(&arr3);
    const key4 = IDBKey.array(&arr4);

    try std.testing.expectEqual(@as(i16, -1), compare(key1, key2));
    try std.testing.expectEqual(@as(i16, 1), compare(key2, key1));
    try std.testing.expectEqual(@as(i16, 0), compare(key1, key3));

    // Shorter array < longer array when prefix matches
    try std.testing.expectEqual(@as(i16, -1), compare(key4, key1));
    try std.testing.expectEqual(@as(i16, 1), compare(key1, key4));
}

test "IDBKey - clone" {
    const allocator = std.testing.allocator;

    var original = try IDBKey.stringOwned(allocator, "test");
    defer original.deinit();

    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expectEqual(@as(i16, 0), compare(original, cloned));
    try std.testing.expectEqualStrings("test", cloned.value.string);
}
