//! IndexedDB Key Range Implementation
//!
//! Implements IDBKeyRange per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#keyrange
//!
//! ## Spec Reference
//!
//! Algorithm: "convert a value to a key range"
//! Location: specs/algorithms/IndexedDB-3.json lines 238-260
//! URL: https://w3c.github.io/IndexedDB/#convert-a-value-to-a-key-range
//!
//! ## Usage
//!
//! ```zig
//! // Exact match
//! const exact = IDBKeyRange.only(IDBKey.number(5));
//!
//! // Lower bound (x >= 5)
//! const lower = IDBKeyRange.lowerBound(IDBKey.number(5), false);
//!
//! // Upper bound (x < 10)
//! const upper = IDBKeyRange.upperBound(IDBKey.number(10), true);
//!
//! // Range (5 <= x < 10)
//! const range = IDBKeyRange.bound(
//!     IDBKey.number(5),
//!     IDBKey.number(10),
//!     false,  // lowerOpen
//!     true    // upperOpen
//! );
//!
//! // Check if key is in range
//! const key = IDBKey.number(7);
//! if (range.includes(key)) {
//!     // key is in range
//! }
//! ```

const std = @import("std");
const key_mod = @import("key.zig");
const IDBKey = key_mod.IDBKey;
const compare = key_mod.compare;
const IDBError = @import("errors.zig").IDBError;

/// IDBKeyRange represents a continuous interval over keys
/// https://w3c.github.io/IndexedDB/#keyrange
pub const IDBKeyRange = struct {
    const Self = @This();

    /// Lower bound of the range (null = unbounded)
    lower: ?IDBKey,
    /// Upper bound of the range (null = unbounded)
    upper: ?IDBKey,
    /// If true, lower bound is excluded
    lower_open: bool,
    /// If true, upper bound is excluded
    upper_open: bool,

    allocator: ?std.mem.Allocator,

    /// Create an unbounded key range (matches all keys)
    /// https://w3c.github.io/IndexedDB/#unbounded-key-range
    pub fn unbounded() Self {
        return Self{
            .lower = null,
            .upper = null,
            .lower_open = true,
            .upper_open = true,
            .allocator = null,
        };
    }

    /// Create a key range containing only a single key
    /// https://w3c.github.io/IndexedDB/#dom-idbkeyrange-only
    ///
    /// IDBKeyRange.only(value) creates a range that matches only `value`.
    pub fn only(value: IDBKey) Self {
        return Self{
            .lower = value,
            .upper = value,
            .lower_open = false,
            .upper_open = false,
            .allocator = null,
        };
    }

    /// Create a key range with only a lower bound
    /// https://w3c.github.io/IndexedDB/#dom-idbkeyrange-lowerbound
    ///
    /// If open is false: key >= lower
    /// If open is true:  key > lower
    pub fn lowerBound(lower_key: IDBKey, open: bool) Self {
        return Self{
            .lower = lower_key,
            .upper = null,
            .lower_open = open,
            .upper_open = true,
            .allocator = null,
        };
    }

    /// Create a key range with only an upper bound
    /// https://w3c.github.io/IndexedDB/#dom-idbkeyrange-upperbound
    ///
    /// If open is false: key <= upper
    /// If open is true:  key < upper
    pub fn upperBound(upper_key: IDBKey, open: bool) Self {
        return Self{
            .lower = null,
            .upper = upper_key,
            .lower_open = true,
            .upper_open = open,
            .allocator = null,
        };
    }

    /// Create a key range with both bounds
    /// https://w3c.github.io/IndexedDB/#dom-idbkeyrange-bound
    ///
    /// Creates range [lower, upper], (lower, upper], [lower, upper), or (lower, upper)
    /// based on the open flags.
    pub fn bound(
        lower_key: IDBKey,
        upper_key: IDBKey,
        lower_open: bool,
        upper_open: bool,
    ) IDBError!Self {
        // Validate: lower must be <= upper
        const cmp = compare(lower_key, upper_key);
        if (cmp > 0) {
            return IDBError.DataError;
        }

        // If lower == upper and either bound is open, range is empty (invalid)
        if (cmp == 0 and (lower_open or upper_open)) {
            return IDBError.DataError;
        }

        return Self{
            .lower = lower_key,
            .upper = upper_key,
            .lower_open = lower_open,
            .upper_open = upper_open,
            .allocator = null,
        };
    }

    /// Clean up owned resources
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            _ = alloc;
            if (self.lower) |*lower| {
                var l = lower.*;
                l.deinit();
            }
            if (self.upper) |*upper| {
                var u = upper.*;
                u.deinit();
            }
        }
    }

    /// Check if the range is unbounded (matches all keys)
    pub fn isUnbounded(self: Self) bool {
        return self.lower == null and self.upper == null;
    }

    /// Check if a key is within this range
    /// https://w3c.github.io/IndexedDB/#dom-idbkeyrange-includes
    ///
    /// Returns true if key is within the range bounds.
    pub fn includes(self: Self, key: IDBKey) bool {
        // Check lower bound
        if (self.lower) |lower| {
            const cmp = compare(key, lower);
            if (self.lower_open) {
                // key must be > lower
                if (cmp <= 0) return false;
            } else {
                // key must be >= lower
                if (cmp < 0) return false;
            }
        }

        // Check upper bound
        if (self.upper) |upper| {
            const cmp = compare(key, upper);
            if (self.upper_open) {
                // key must be < upper
                if (cmp >= 0) return false;
            } else {
                // key must be <= upper
                if (cmp > 0) return false;
            }
        }

        return true;
    }

    /// Check if this range overlaps with another range
    pub fn overlaps(self: Self, other: Self) bool {
        // Check if self's lower bound is beyond other's upper bound
        if (self.lower != null and other.upper != null) {
            const cmp = compare(self.lower.?, other.upper.?);
            if (cmp > 0) return false;
            if (cmp == 0 and (self.lower_open or other.upper_open)) return false;
        }

        // Check if other's lower bound is beyond self's upper bound
        if (other.lower != null and self.upper != null) {
            const cmp = compare(other.lower.?, self.upper.?);
            if (cmp > 0) return false;
            if (cmp == 0 and (other.lower_open or self.upper_open)) return false;
        }

        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBKeyRange - only" {
    const range = IDBKeyRange.only(IDBKey.number(5));

    try std.testing.expect(range.includes(IDBKey.number(5)));
    try std.testing.expect(!range.includes(IDBKey.number(4)));
    try std.testing.expect(!range.includes(IDBKey.number(6)));
}

test "IDBKeyRange - lowerBound closed" {
    const range = IDBKeyRange.lowerBound(IDBKey.number(5), false);

    try std.testing.expect(range.includes(IDBKey.number(5)));
    try std.testing.expect(range.includes(IDBKey.number(6)));
    try std.testing.expect(range.includes(IDBKey.number(100)));
    try std.testing.expect(!range.includes(IDBKey.number(4)));
}

test "IDBKeyRange - lowerBound open" {
    const range = IDBKeyRange.lowerBound(IDBKey.number(5), true);

    try std.testing.expect(!range.includes(IDBKey.number(5)));
    try std.testing.expect(range.includes(IDBKey.number(6)));
    try std.testing.expect(!range.includes(IDBKey.number(4)));
}

test "IDBKeyRange - upperBound closed" {
    const range = IDBKeyRange.upperBound(IDBKey.number(10), false);

    try std.testing.expect(range.includes(IDBKey.number(10)));
    try std.testing.expect(range.includes(IDBKey.number(5)));
    try std.testing.expect(!range.includes(IDBKey.number(11)));
}

test "IDBKeyRange - upperBound open" {
    const range = IDBKeyRange.upperBound(IDBKey.number(10), true);

    try std.testing.expect(!range.includes(IDBKey.number(10)));
    try std.testing.expect(range.includes(IDBKey.number(9)));
    try std.testing.expect(!range.includes(IDBKey.number(11)));
}

test "IDBKeyRange - bound closed-closed" {
    const range = try IDBKeyRange.bound(
        IDBKey.number(5),
        IDBKey.number(10),
        false,
        false,
    );

    try std.testing.expect(range.includes(IDBKey.number(5)));
    try std.testing.expect(range.includes(IDBKey.number(7)));
    try std.testing.expect(range.includes(IDBKey.number(10)));
    try std.testing.expect(!range.includes(IDBKey.number(4)));
    try std.testing.expect(!range.includes(IDBKey.number(11)));
}

test "IDBKeyRange - bound open-open" {
    const range = try IDBKeyRange.bound(
        IDBKey.number(5),
        IDBKey.number(10),
        true,
        true,
    );

    try std.testing.expect(!range.includes(IDBKey.number(5)));
    try std.testing.expect(range.includes(IDBKey.number(7)));
    try std.testing.expect(!range.includes(IDBKey.number(10)));
}

test "IDBKeyRange - bound invalid (lower > upper)" {
    const result = IDBKeyRange.bound(
        IDBKey.number(10),
        IDBKey.number(5),
        false,
        false,
    );
    try std.testing.expectError(IDBError.DataError, result);
}

test "IDBKeyRange - bound invalid (equal with open)" {
    const result = IDBKeyRange.bound(
        IDBKey.number(5),
        IDBKey.number(5),
        true,
        false,
    );
    try std.testing.expectError(IDBError.DataError, result);
}

test "IDBKeyRange - unbounded" {
    const range = IDBKeyRange.unbounded();

    try std.testing.expect(range.isUnbounded());
    try std.testing.expect(range.includes(IDBKey.number(0)));
    try std.testing.expect(range.includes(IDBKey.string("anything")));
}

test "IDBKeyRange - overlaps" {
    const range1 = try IDBKeyRange.bound(
        IDBKey.number(0),
        IDBKey.number(10),
        false,
        false,
    );
    const range2 = try IDBKeyRange.bound(
        IDBKey.number(5),
        IDBKey.number(15),
        false,
        false,
    );
    const range3 = try IDBKeyRange.bound(
        IDBKey.number(20),
        IDBKey.number(30),
        false,
        false,
    );

    try std.testing.expect(range1.overlaps(range2));
    try std.testing.expect(range2.overlaps(range1));
    try std.testing.expect(!range1.overlaps(range3));
    try std.testing.expect(!range3.overlaps(range1));
}
