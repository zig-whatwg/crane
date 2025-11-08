//! WebIDL Record Type Conversion
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-record (§ 3.2.17)
//!
//! Records are ordered maps with string keys converted from JavaScript objects.
//! Equivalent to `record<DOMString, V>` in WebIDL.
//!
//! # Usage
//!
//! ```zig
//! // Convert JavaScript object to record<DOMString, DOMString>
//! const headers = try webidl.toRecord(
//!     []const u8,
//!     []const u8,
//!     allocator,
//!     js_value,
//! );
//! defer headers.deinit();
//! ```

const std = @import("std");
const primitives = @import("primitives.zig");
const object = @import("object.zig");
const dictionaries = @import("dictionaries.zig");

pub const JSValue = primitives.JSValue;
pub const JSObject = object.JSObject;

/// Convert JavaScript object to WebIDL record<K, V>
///
/// Spec: WebIDL § 3.2.17 - Record types
///
/// Algorithm:
/// 1. If Type(V) is not Object, throw TypeError
/// 2. Let result be empty ordered map
/// 3. Let keys be ? EnumerableOwnPropertyNames(V, "key")
/// 4. For each key in keys:
///    a. Let typedKey be key converted to type K
///    b. Let value be ? Get(V, key)
///    c. Let typedValue be value converted to type V
///    d. Set result[typedKey] = typedValue
/// 5. Return result
///
/// # Parameters
/// - `K`: Key type (typically `[]const u8` for DOMString)
/// - `V`: Value type (any WebIDL type)
/// - `allocator`: Allocator for the HashMap
/// - `value`: JavaScript value (must be .object)
///
/// # Returns
/// StringHashMap with converted key-value pairs
///
/// # Example
/// ```zig
/// // JavaScript: { "en": "Hello", "es": "Hola", "fr": "Bonjour" }
/// // WebIDL: record<DOMString, DOMString>
///
/// const translations = try webidl.toRecord(
///     []const u8,
///     []const u8,
///     allocator,
///     js_value,
/// );
/// defer translations.deinit();
///
/// // translations.get("en") -> "Hello"
/// ```
pub fn toRecord(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    value: JSValue,
) !std.StringHashMap(V) {
    // Step 1: Validate object
    const obj = try value.asObject();

    // Step 2: Create result map
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    // Step 3: Get enumerable own property names
    const property_keys = try obj.keys(allocator);
    defer allocator.free(property_keys);

    // Step 4: Convert each property
    for (property_keys) |key| {
        // Step 4a: Convert key (for record<K, V>, K is typically DOMString)
        const typed_key = try convertKey(K, key, allocator);
        errdefer if (K != []const u8) allocator.free(typed_key);

        // Step 4b: Get value
        const prop_value = obj.get(key) orelse continue;

        // Step 4c: Convert value
        const typed_value = try dictionaries.convertToType(V, prop_value);

        // Step 4d: Store in result
        try result.put(typed_key, typed_value);
    }

    return result;
}

/// Convert key to target type
///
/// Per WebIDL, record keys are always converted to DOMString.
/// For simplicity, we support []const u8 (UTF-8 strings).
fn convertKey(comptime K: type, key: []const u8, allocator: std.mem.Allocator) !K {
    // Most common case: DOMString ([]const u8)
    if (K == []const u8) {
        return key; // No conversion needed
    }

    // For other key types, would need proper conversion
    // WebIDL spec only defines DOMString keys for records
    _ = allocator;
    @compileError("Record key type must be []const u8 (DOMString)");
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "toRecord - string to string" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("en", .{ .string = "Hello" });
    try obj.set("es", .{ .string = "Hola" });
    try obj.set("fr", .{ .string = "Bonjour" });

    var record = try toRecord(
        []const u8,
        []const u8,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    try testing.expectEqual(@as(usize, 3), record.count());
    try testing.expectEqualStrings("Hello", record.get("en").?);
    try testing.expectEqualStrings("Hola", record.get("es").?);
    try testing.expectEqualStrings("Bonjour", record.get("fr").?);
}

test "toRecord - string to number" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("age", .{ .number = 30.0 });
    try obj.set("count", .{ .number = 42.0 });

    var record = try toRecord(
        []const u8,
        i32,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    try testing.expectEqual(@as(usize, 2), record.count());
    try testing.expectEqual(@as(i32, 30), record.get("age").?);
    try testing.expectEqual(@as(i32, 42), record.get("count").?);
}

test "toRecord - string to boolean" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("enabled", .{ .boolean = true });
    try obj.set("active", .{ .boolean = false });

    var record = try toRecord(
        []const u8,
        bool,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    try testing.expectEqual(@as(usize, 2), record.count());
    try testing.expect(record.get("enabled").?);
    try testing.expect(!record.get("active").?);
}

test "toRecord - string to optional" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("a", .{ .number = 42.0 });
    try obj.set("b", .{ .null = {} });
    try obj.set("c", .{ .undefined = {} });

    var record = try toRecord(
        []const u8,
        ?i32,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    try testing.expectEqual(@as(usize, 3), record.count());
    try testing.expectEqual(@as(?i32, 42), record.get("a").?);
    try testing.expectEqual(@as(?i32, null), record.get("b").?);
    try testing.expectEqual(@as(?i32, null), record.get("c").?);
}

test "toRecord - empty object" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    var record = try toRecord(
        []const u8,
        []const u8,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    try testing.expectEqual(@as(usize, 0), record.count());
}

test "toRecord - not an object error" {
    const result = toRecord(
        []const u8,
        []const u8,
        testing.allocator,
        .{ .string = "not an object" },
    );

    try testing.expectError(error.TypeError, result);
}

test "toRecord - real-world example (HTTP headers)" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("Content-Type", .{ .string = "application/json" });
    try obj.set("Accept", .{ .string = "text/html" });
    try obj.set("Authorization", .{ .string = "Bearer token123" });

    var headers = try toRecord(
        []const u8,
        []const u8,
        testing.allocator,
        .{ .object = obj },
    );
    defer headers.deinit();

    try testing.expectEqual(@as(usize, 3), headers.count());
    try testing.expectEqualStrings("application/json", headers.get("Content-Type").?);
    try testing.expectEqualStrings("text/html", headers.get("Accept").?);
    try testing.expectEqualStrings("Bearer token123", headers.get("Authorization").?);
}

test "toRecord - unicode keys" {
    var obj = JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("名前", .{ .string = "Alice" });
    try obj.set("年齢", .{ .string = "30" }); // Changed to string to match record type

    var record = try toRecord(
        []const u8,
        []const u8,
        testing.allocator,
        .{ .object = obj },
    );
    defer record.deinit();

    const name_value = record.get("名前");
    try testing.expect(name_value != null);
    try testing.expectEqualStrings("Alice", name_value.?);
}
