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

test "JSObject - init and deinit" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try testing.expectEqual(@as(usize, 0), obj.count());
}

test "JSObject - set and get properties" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("name", .{ .string = "Alice" });
    try obj.set("age", .{ .number = 30.0 });
    try obj.set("active", .{ .boolean = true });

    const name = obj.get("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Alice", name.?.string);

    const age = obj.get("age");
    try testing.expect(age != null);
    try testing.expectEqual(@as(f64, 30.0), age.?.number);

    const active = obj.get("active");
    try testing.expect(active != null);
    try testing.expect(active.?.boolean);
}

test "JSObject - has property" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("exists", .{ .boolean = true });

    try testing.expect(obj.has("exists"));
    try testing.expect(!obj.has("missing"));
}

test "JSObject - overwrite property" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("value", .{ .number = 1.0 });
    try obj.set("value", .{ .number = 2.0 });

    const value = obj.get("value");
    try testing.expectEqual(@as(f64, 2.0), value.?.number);
}

test "JSObject - keys iteration" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("a", .{ .number = 1.0 });
    try obj.set("b", .{ .number = 2.0 });
    try obj.set("c", .{ .number = 3.0 });

    const property_keys = try obj.keys(testing.allocator);
    defer testing.allocator.free(property_keys);

    try testing.expectEqual(@as(usize, 3), property_keys.len);

    // Verify all keys are present (order not guaranteed with HashMap)
    var has_a = false;
    var has_b = false;
    var has_c = false;
    for (property_keys) |key| {
        if (std.mem.eql(u8, key, "a")) has_a = true;
        if (std.mem.eql(u8, key, "b")) has_b = true;
        if (std.mem.eql(u8, key, "c")) has_c = true;
    }
    try testing.expect(has_a and has_b and has_c);
}

test "JSObject - count" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try testing.expectEqual(@as(usize, 0), obj.count());

    try obj.set("a", .{ .number = 1.0 });
    try testing.expectEqual(@as(usize, 1), obj.count());

    try obj.set("b", .{ .number = 2.0 });
    try testing.expectEqual(@as(usize, 2), obj.count());

    // Overwrite doesn't increase count
    try obj.set("a", .{ .number = 10.0 });
    try testing.expectEqual(@as(usize, 2), obj.count());
}

test "JSObject - nested objects" {
    var parent = JSObject.init(testing.allocator);
    defer parent.deinit();

    var child = JSObject.init(testing.allocator);
    try child.set("value", .{ .number = 42.0 });

    try parent.set("child", .{ .object = child });

    const retrieved = parent.get("child");
    try testing.expect(retrieved != null);
    try testing.expect(retrieved.? == .object);

    // Access nested value
    const nested_value = retrieved.?.object.get("value");
    try testing.expectEqual(@as(f64, 42.0), nested_value.?.number);
}

test "JSObject - empty object" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try testing.expectEqual(@as(usize, 0), obj.count());
    try testing.expect(obj.get("anything") == null);
    try testing.expect(!obj.has("anything"));
}

test "JSObject - unicode property names" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("名前", .{ .string = "Alice" });
    try obj.set("年齢", .{ .number = 30.0 });

    try testing.expect(obj.has("名前"));
    try testing.expect(obj.has("年齢"));

    const name = obj.get("名前");
    try testing.expectEqualStrings("Alice", name.?.string);
}

test "JSObject - memory safety with nested objects" {
    // This test verifies no memory leaks with nested structures
    // std.testing.allocator will catch leaks
    var parent = JSObject.init(testing.allocator);
    defer parent.deinit();

    var child1 = JSObject.init(testing.allocator);
    try child1.set("value", .{ .number = 1.0 });

    var child2 = JSObject.init(testing.allocator);
    try child2.set("value", .{ .number = 2.0 });

    try parent.set("child1", .{ .object = child1 });
    try parent.set("child2", .{ .object = child2 });

    // parent.deinit() should clean up both children
    // If any memory leaks, std.testing.allocator will fail the test
}
