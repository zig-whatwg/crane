//! WebIDL JavaScript Object
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-dictionaries (§ 3.2.23)
//!
//! Represents a JavaScript object with string-keyed properties. Used for
//! dictionary conversion, record types, and general object property access.
//!
//! MEMORY: JSObject owns all property keys and recursively manages nested objects.
//! Always call deinit() to prevent memory leaks.

const std = @import("std");

// Forward declaration - JSValue defined in primitives.zig
// This breaks the circular dependency
pub const JSValue = @import("primitives.zig").JSValue;

/// JavaScript object representation for WebIDL operations
///
/// Spec: § 3.2.23 - Dictionary conversion from JavaScript objects
///
/// This type represents a JavaScript object as a map of property names to values.
/// Per WebIDL spec, only own enumerable properties are accessible (no prototype chain).
///
/// # Memory Management
///
/// JSObject owns all property keys (duped strings) and recursively manages
/// nested objects. The allocator is tracked for proper cleanup.
///
/// Example:
/// ```zig
/// var obj = JSObject.init(allocator);
/// defer obj.deinit();
///
/// try obj.set("name", .{ .string = "Alice" });
/// const name = obj.get("name"); // ?JSValue
/// ```
///
/// # Performance
///
/// - Property access: O(1) average (HashMap)
/// - Memory overhead: ~48 bytes + property storage
/// - Small object optimization: Considered for future (≤4 properties)
pub const JSObject = struct {
    /// Allocator for property keys and nested objects
    allocator: std.mem.Allocator,

    /// Property storage: name → value
    /// Keys are owned (duped strings), values are owned (JSValue by value)
    properties: std.StringHashMap(JSValue),

    /// Initialize empty JavaScript object
    ///
    /// Example:
    /// ```zig
    /// var obj = JSObject.init(allocator);
    /// defer obj.deinit();
    /// ```
    pub fn init(allocator: std.mem.Allocator) JSObject {
        return .{
            .allocator = allocator,
            .properties = std.StringHashMap(JSValue).init(allocator),
        };
    }

    /// Clean up all properties and nested objects
    ///
    /// CRITICAL: This recursively frees:
    /// 1. All property keys (owned strings)
    /// 2. All nested objects (recursive deinit)
    /// 3. The HashMap itself
    ///
    /// Per WebIDL spec, objects own their properties.
    pub fn deinit(self: *JSObject) void {
        // Free all owned property keys
        var key_iter = self.properties.keyIterator();
        while (key_iter.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }

        // Recursively deinit nested objects
        var value_iter = self.properties.valueIterator();
        while (value_iter.next()) |value_ptr| {
            if (value_ptr.* == .object) {
                var nested = value_ptr.object;
                nested.deinit();
            }
        }

        self.properties.deinit();
    }

    /// Set property value
    ///
    /// Spec: § 3.2.23 Step 4 - Dictionary member conversion
    ///
    /// If property exists, updates value. If new property, dupes key.
    /// Takes ownership of value (stored by value in HashMap).
    ///
    /// Example:
    /// ```zig
    /// try obj.set("count", .{ .number = 42.0 });
    /// try obj.set("enabled", .{ .boolean = true });
    /// ```
    pub fn set(self: *JSObject, key: []const u8, value: JSValue) !void {
        // Check if key already exists
        if (self.properties.getEntry(key)) |entry| {
            // Update existing property - just replace value
            // Don't free old key (still in use)
            entry.value_ptr.* = value;
        } else {
            // New property - must dupe key
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            try self.properties.put(owned_key, value);
        }
    }

    /// Get property value
    ///
    /// Spec: § 7.1.1 - [[Get]] internal method
    ///
    /// Returns null if property does not exist (not in own properties).
    /// Per WebIDL, prototype chain is not traversed.
    ///
    /// Example:
    /// ```zig
    /// const value = obj.get("name");
    /// if (value) |v| {
    ///     // Property exists
    /// }
    /// ```
    pub fn get(self: JSObject, key: []const u8) ?JSValue {
        return self.properties.get(key);
    }

    /// Check if property exists
    ///
    /// Per WebIDL, only checks own enumerable properties.
    ///
    /// Example:
    /// ```zig
    /// if (obj.has("enabled")) {
    ///     // Property exists
    /// }
    /// ```
    pub fn has(self: JSObject, key: []const u8) bool {
        return self.properties.contains(key);
    }

    /// Get all property names
    ///
    /// Spec: § 3.2.17 Step 3 - EnumerableOwnPropertyNames
    ///
    /// Returns slice of property names. Caller owns slice (must free),
    /// but names are borrowed from JSObject (do not free individual names).
    ///
    /// Example:
    /// ```zig
    /// const names = try obj.keys(allocator);
    /// defer allocator.free(names);
    /// for (names) |name| {
    ///     std.debug.print("{s}\n", .{name});
    /// }
    /// ```
    pub fn keys(self: JSObject, allocator: std.mem.Allocator) ![][]const u8 {
        const key_list = try allocator.alloc([]const u8, self.properties.count());
        errdefer allocator.free(key_list);

        var iter = self.properties.keyIterator();
        var i: usize = 0;
        while (iter.next()) |key_ptr| : (i += 1) {
            key_list[i] = key_ptr.*;
        }

        return key_list;
    }

    /// Get property count
    ///
    /// Example:
    /// ```zig
    /// const n = obj.count();
    /// std.debug.print("Object has {} properties\n", .{n});
    /// ```
    pub fn count(self: JSObject) usize {
        return self.properties.count();
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;










