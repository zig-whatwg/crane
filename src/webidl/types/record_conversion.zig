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








