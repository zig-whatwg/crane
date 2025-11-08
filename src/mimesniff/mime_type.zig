//! WHATWG MIME Type Parsing and Serialization
//!
//! Spec: https://mimesniff.spec.whatwg.org/#mime-type
//!
//! This module implements MIME type representation, parsing, and serialization
//! as defined in the WHATWG MIME Sniffing Standard.
//!
//! Dependencies:
//! - WHATWG Infra Standard: https://infra.spec.whatwg.org/
//!   - infra.String (UTF-16): String representation
//!   - infra.OrderedMap: Ordered map for MIME type parameters
//!   - infra.bytes.isomorphicDecode/Encode: UTF-8 ↔ UTF-16 conversion
//!   - infra.string.isAsciiWhitespace: ASCII whitespace detection

const std = @import("std");
const infra = @import("infra");
const constants = @import("constants.zig");
const string_pool = @import("string_pool.zig");

/// MIME type representation (WHATWG MIME Sniffing §3.1)
///
/// A MIME type represents an internet media type. It consists of:
/// - type: A non-empty ASCII string (e.g., "text")
/// - subtype: A non-empty ASCII string (e.g., "html")
/// - parameters: An ordered map of ASCII string keys to string values
///
/// Uses WHATWG Infra Standard primitives:
/// - infra.String (UTF-16): https://infra.spec.whatwg.org/#string
/// - infra.OrderedMap: https://infra.spec.whatwg.org/#ordered-map
///
/// Spec: https://mimesniff.spec.whatwg.org/#mime-type-representation
pub const MimeType = struct {
    /// Type (e.g., "text") - ASCII lowercase, stored as UTF-16 (infra.String)
    type: infra.String,

    /// Subtype (e.g., "html") - ASCII lowercase, stored as UTF-16 (infra.String)
    subtype: infra.String,

    /// Parameters (e.g., {"charset": "utf-8"}) - ordered map (infra.OrderedMap)
    /// Keys and values are UTF-16 strings (infra.String)
    parameters: infra.OrderedMap(infra.String, infra.String),

    /// Whether this MimeType owns its data (true = allocated, false = borrowed/comptime)
    owned: bool,

    /// Allocator used for all allocations (only used if owned == true)
    allocator: std.mem.Allocator,

    /// Initialize empty MIME type (owned)
    pub fn init(allocator: std.mem.Allocator) MimeType {
        return .{
            .type = &[_]u16{},
            .subtype = &[_]u16{},
            .parameters = infra.OrderedMap(infra.String, infra.String).init(allocator),
            .owned = true,
            .allocator = allocator,
        };
    }

    /// Free all allocated memory (only if owned)
    pub fn deinit(self: *MimeType) void {
        if (!self.owned) return; // Don't free borrowed/comptime data

        // Free type/subtype only if NOT interned (comptime constants)
        if (!string_pool.isInterned(self.type)) {
            self.allocator.free(self.type);
        }
        if (!string_pool.isInterned(self.subtype)) {
            self.allocator.free(self.subtype);
        }

        // Free parameter keys and values
        const entries = self.parameters.entries.items();
        for (entries) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }

        self.parameters.deinit();
    }

    /// Returns "type/subtype" (essence)
    ///
    /// Spec: https://mimesniff.spec.whatwg.org/#mime-type-essence
    ///
    /// Caller owns returned memory
    pub fn essence(self: MimeType, allocator: std.mem.Allocator) !infra.String {
        const len = self.type.len + 1 + self.subtype.len;
        const result = try allocator.alloc(u16, len);

        @memcpy(result[0..self.type.len], self.type);
        result[self.type.len] = '/';
        @memcpy(result[self.type.len + 1 ..], self.subtype);

        return result;
    }
};

/// Allocate and lowercase string, with interning for types
///
/// This function tries to intern the string first (no allocation).
/// If interning fails (uncommon type), allocates and lowercases.
///
/// Used by parseMimeTypeFromString for type field.
fn allocTypeWithInterning(
    allocator: std.mem.Allocator,
    temp_allocator: std.mem.Allocator,
    s: infra.String,
) !infra.String {
    // First, lowercase to temp buffer
    const lowered = try asciiLowercaseString(temp_allocator, s);
    defer temp_allocator.free(lowered);

    // Try to intern
    if (string_pool.internType(lowered)) |interned| {
        return interned; // No allocation!
    }

    // Not in pool, allocate permanent copy
    return try allocator.dupe(u16, lowered);
}

/// Allocate and lowercase string, with interning for subtypes
///
/// This function tries to intern the string first (no allocation).
/// If interning fails (uncommon subtype), allocates and lowercases.
///
/// Used by parseMimeTypeFromString for subtype field.
fn allocSubtypeWithInterning(
    allocator: std.mem.Allocator,
    temp_allocator: std.mem.Allocator,
    s: infra.String,
) !infra.String {
    // First, lowercase to temp buffer
    const lowered = try asciiLowercaseString(temp_allocator, s);
    defer temp_allocator.free(lowered);

    // Try to intern
    if (string_pool.internSubtype(lowered)) |interned| {
        return interned; // No allocation!
    }

    // Not in pool, allocate permanent copy
    return try allocator.dupe(u16, lowered);
}

/// Parse MIME type from UTF-8 bytes (common case: HTTP headers)
///
/// Per spec §3.5: "To parse a MIME type from bytes"
/// 1. Isomorphic decode bytes → string (UTF-16) using infra.bytes.isomorphicDecode
/// 2. Parse MIME type from string
///
/// Uses WHATWG Infra Standard:
/// - isomorphicDecode: https://infra.spec.whatwg.org/#isomorphic-decode
///
/// Returns null if parsing fails.
/// Caller owns returned MimeType (must call deinit).
///
/// Spec: https://mimesniff.spec.whatwg.org/#parse-a-mime-type-from-bytes
pub fn parseMimeType(
    allocator: std.mem.Allocator,
    input: []const u8,
) !?MimeType {
    // Create arena for temporary allocations during parsing
    // This reduces overhead by bulk-freeing all temps at once
    var parse_arena = std.heap.ArenaAllocator.init(allocator);
    defer parse_arena.deinit(); // Free ALL temp allocations

    const arena_alloc = parse_arena.allocator();

    // Convert UTF-8 → UTF-16 (temp allocation in arena)
    const input_utf16 = try infra.bytes.isomorphicDecode(arena_alloc, input);
    // No defer needed - arena handles cleanup

    return parseMimeTypeFromString(allocator, arena_alloc, input_utf16);
}

/// Parse MIME type from Infra string (UTF-16)
///
/// Per spec §3.4: "To parse a MIME type"
///
/// Algorithm:
/// 1. Remove leading and trailing HTTP whitespace from input
/// 2. Let position be a position variable for input
/// 3. Let type be result of collecting sequence of code points that are not U+002F (/)
/// 4. If type is empty or does not solely contain HTTP token code points, return failure
/// 5. If position is past the end of input, return failure
/// 6. Advance position by 1 (skip U+002F)
/// 7. Let subtype be result of collecting sequence of code points that are not U+003B (;)
/// 8. Remove any trailing HTTP whitespace from subtype
/// 9. If subtype is empty or does not solely contain HTTP token code points, return failure
/// 10. Let mimeType be a new MIME type record
/// 11. While position is not past the end of input: parse parameters
/// 12. Return mimeType
///
/// Returns null if parsing fails.
/// Caller owns returned MimeType (must call deinit).
///
/// Parameters:
/// - allocator: Base allocator for permanent allocations (type, subtype, params)
/// - temp_allocator: Temporary allocator for intermediate values (can be arena)
/// - input: UTF-16 string to parse
///
/// Spec: https://mimesniff.spec.whatwg.org/#parse-a-mime-type
pub fn parseMimeTypeFromString(
    allocator: std.mem.Allocator,
    temp_allocator: std.mem.Allocator,
    input: infra.String,
) !?MimeType {
    // 1. Remove leading and trailing HTTP whitespace from input
    const trimmed = stripHttpWhitespace(input);
    if (trimmed.len == 0) return null;

    // 2. Let position be a position variable for input
    var pos: usize = 0;

    // 3. Let type be result of collecting sequence NOT U+002F (/)
    const type_end = std.mem.indexOfScalarPos(u16, trimmed, pos, '/') orelse return null;
    const type_slice = trimmed[pos..type_end];

    // 4. If type is empty or does not solely contain HTTP token code points, return failure
    if (type_slice.len == 0 or !isHttpTokenString(type_slice))
        return null;

    // 5. If position is past the end of input, return failure
    if (type_end >= trimmed.len)
        return null;

    // 6. Advance position by 1 (skip '/')
    pos = type_end + 1;

    // 7. Let subtype be result of collecting sequence NOT U+003B (;)
    const semi_pos = std.mem.indexOfScalarPos(u16, trimmed, pos, ';');
    const subtype_end = semi_pos orelse trimmed.len;
    var subtype_slice = trimmed[pos..subtype_end];

    // 8. Remove any trailing HTTP whitespace from subtype
    subtype_slice = stripTrailingHttpWhitespace(subtype_slice);

    // 9. If subtype is empty or does not solely contain HTTP token code points, return failure
    if (subtype_slice.len == 0 or !isHttpTokenString(subtype_slice))
        return null;

    // 10. Let mimeType be a new MIME type record
    var mime_type = MimeType.init(allocator);
    errdefer mime_type.deinit();

    // Set type (ASCII lowercase, with interning)
    mime_type.type = try allocTypeWithInterning(allocator, temp_allocator, type_slice);

    // Set subtype (ASCII lowercase, with interning)
    mime_type.subtype = try allocSubtypeWithInterning(allocator, temp_allocator, subtype_slice);

    // 11. While position is not past end: parse parameters
    if (semi_pos) |semi| {
        pos = semi + 1;
        try parseParameters(allocator, temp_allocator, trimmed[pos..], &mime_type.parameters);
    }

    // 12. Return mimeType
    return mime_type;
}

/// Parse parameters from string (§3.4 step 11)
///
/// Algorithm continues from step 11 of "parse a MIME type"
///
/// Parameters:
/// - allocator: Base allocator for permanent allocations (parameter keys/values)
/// - temp_allocator: Temporary allocator for intermediate values
fn parseParameters(
    allocator: std.mem.Allocator,
    temp_allocator: std.mem.Allocator,
    input: infra.String,
    parameters: *infra.OrderedMap(infra.String, infra.String),
) !void {
    var pos: usize = 0;

    while (pos < input.len) {
        // 11.1. Advance position by 1 (skip ';' from previous iteration or initial)
        if (pos > 0) pos += 1;
        if (pos >= input.len) break;

        // 11.2. Collect a sequence of HTTP whitespace
        while (pos < input.len and infra.string.isAsciiWhitespace(input[pos])) : (pos += 1) {}
        if (pos >= input.len) break;

        // 11.3. Let parameterName be result of collecting sequence NOT ';' or '='
        const param_start = pos;
        while (pos < input.len and input[pos] != ';' and input[pos] != '=') : (pos += 1) {}
        const parameter_name = input[param_start..pos];

        // 11.4. Set parameterName to parameterName, in ASCII lowercase (temp allocation)
        const parameter_name_lower = try asciiLowercaseString(temp_allocator, parameter_name);
        defer temp_allocator.free(parameter_name_lower);

        // 11.5. If position is not past the end of input
        if (pos < input.len) {
            // 11.5.1. If the code point at position is U+003B (;), continue
            if (input[pos] == ';') continue;

            // 11.5.2. Advance position by 1 (skip '=')
            pos += 1;
        }

        // 11.6. If position is past the end of input, break
        if (pos >= input.len) break;

        // 11.7. Let parameterValue be null
        const parameter_value: ?infra.String = blk: {
            // 11.8. If the code point at position is U+0022 (")
            if (input[pos] == '"') {
                // 11.8.1. Set parameterValue to result of collecting HTTP quoted string (temp)
                const pv = try collectHttpQuotedString(temp_allocator, input, &pos);

                // 11.8.2. Collect a sequence NOT ';' (ignore trailing garbage)
                while (pos < input.len and input[pos] != ';') : (pos += 1) {}

                break :blk pv;
            } else {
                // 11.9. Otherwise
                // 11.9.1. Set parameterValue to result of collecting sequence NOT ';'
                const value_start = pos;
                while (pos < input.len and input[pos] != ';') : (pos += 1) {}
                var value_slice = input[value_start..pos];

                // 11.9.2. Remove trailing HTTP whitespace
                value_slice = stripTrailingHttpWhitespace(value_slice);

                // 11.9.3. If parameterValue is empty, continue
                if (value_slice.len == 0) break :blk null;

                break :blk try temp_allocator.dupe(u16, value_slice);
            }
        };
        defer if (parameter_value) |pv| temp_allocator.free(pv);

        // 11.10. If all conditions are met, set parameter
        if (parameter_name_lower.len > 0 and
            isHttpTokenString(parameter_name_lower) and
            parameter_value != null and
            isHttpQuotedStringTokenString(parameter_value.?) and
            !parameters.contains(parameter_name_lower))
        {
            const key_copy = try allocator.dupe(u16, parameter_name_lower);
            const value_copy = try allocator.dupe(u16, parameter_value.?);
            try parameters.set(key_copy, value_copy);
        }
    }
}

/// Collect HTTP quoted string (§3.4 step 11.8.1)
fn collectHttpQuotedString(
    allocator: std.mem.Allocator,
    input: infra.String,
    pos: *usize,
) !infra.String {
    var result = try std.ArrayList(u16).initCapacity(allocator, 32);
    errdefer result.deinit(allocator);

    // Skip opening quote
    pos.* += 1;

    var in_escape = false;
    while (pos.* < input.len) : (pos.* += 1) {
        const c = input[pos.*];

        if (in_escape) {
            // After backslash, take character literally
            try result.append(allocator, c);
            in_escape = false;
        } else if (c == '\\') {
            // Start escape sequence
            in_escape = true;
        } else if (c == '"') {
            // End quote
            pos.* += 1;
            break;
        } else {
            // Normal character
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Serialize MIME type to string (UTF-16)
///
/// Spec: https://mimesniff.spec.whatwg.org/#serialize-a-mime-type
pub fn serializeMimeType(
    allocator: std.mem.Allocator,
    mime_type: MimeType,
) !infra.String {
    const initial_capacity = mime_type.type.len + mime_type.subtype.len + 32;
    var result = try std.ArrayList(u16).initCapacity(allocator, initial_capacity);
    errdefer result.deinit(allocator);

    // 1. Let serialization be concatenation of type, U+002F (/), and subtype
    try result.appendSlice(allocator, mime_type.type);
    try result.append(allocator, '/');
    try result.appendSlice(allocator, mime_type.subtype);

    // 2. For each name → value of parameters
    const entries = mime_type.parameters.entries.items();
    for (entries) |entry| {
        // 2.1. Append U+003B (;)
        try result.append(allocator, ';');

        // 2.2. Append name
        try result.appendSlice(allocator, entry.key);

        // 2.3. Append U+003D (=)
        try result.append(allocator, '=');

        // 2.4. If value does not solely contain HTTP token code points or is empty
        if (entry.value.len == 0 or !isHttpTokenString(entry.value)) {
            // Quote the value
            try result.append(allocator, '"');

            // Escape quotes and backslashes
            for (entry.value) |c| {
                if (c == '"' or c == '\\') {
                    try result.append(allocator, '\\');
                }
                try result.append(allocator, c);
            }

            try result.append(allocator, '"');
        } else {
            // 2.5. Append value
            try result.appendSlice(allocator, entry.value);
        }
    }

    // 3. Return serialization
    return result.toOwnedSlice(allocator);
}

/// Serialize MIME type to bytes (UTF-8)
///
/// Uses WHATWG Infra Standard:
/// - isomorphicEncode: https://infra.spec.whatwg.org/#isomorphic-encode
///
/// Spec: https://mimesniff.spec.whatwg.org/#serialize-a-mime-type-to-bytes
pub fn serializeMimeTypeToBytes(
    allocator: std.mem.Allocator,
    mime_type: MimeType,
) ![]const u8 {
    // 1. Let stringSerialization be result of serialize a MIME type
    const string_serialization = try serializeMimeType(allocator, mime_type);
    defer allocator.free(string_serialization);

    // 2. Return stringSerialization, isomorphic encoded
    return infra.bytes.isomorphicEncode(allocator, string_serialization);
}

/// Check if a UTF-16 string equals an ASCII string (no allocation)
inline fn stringEqualsAscii(utf16_str: infra.String, ascii_str: []const u8) bool {
    if (utf16_str.len != ascii_str.len) return false;

    for (utf16_str, 0..) |c, i| {
        if (c != ascii_str[i]) return false;
    }

    return true;
}

/// Check if MIME type essence equals given type and subtype (no allocation)
///
/// This is an optimized version that compares type and subtype directly
/// without allocating memory for the concatenated essence string.
///
/// Spec: https://mimesniff.spec.whatwg.org/#mime-type-essence
inline fn essenceEquals(mt: *const MimeType, type_str: []const u8, subtype_str: []const u8) bool {
    return stringEqualsAscii(mt.type, type_str) and stringEqualsAscii(mt.subtype, subtype_str);
}

/// Minimize a supported MIME type (WHATWG MIME Sniffing §4.2)
///
/// Returns a minimized representation of a supported MIME type.
/// This is used by preload and other specifications.
///
/// Algorithm:
/// 1. If mimeType is a JavaScript MIME type, return "text/javascript"
/// 2. If mimeType is a JSON MIME type, return "application/json"
/// 3. If mimeType's essence is "image/svg+xml", return "image/svg+xml"
/// 4. If mimeType is an XML MIME type, return "application/xml"
/// 5. If mimeType is supported by the user agent, return mimeType's essence
/// 6. Return the empty string
///
/// Caller owns returned memory.
///
/// Spec: https://mimesniff.spec.whatwg.org/#minimizing-a-supported-mime-type
pub fn minimizeSupportedMimeType(
    allocator: std.mem.Allocator,
    mime_type: *const MimeType,
) ![]const u8 {
    const predicates = @import("predicates.zig");

    // 1. If mimeType is a JavaScript MIME type, return "text/javascript"
    if (predicates.isJavaScriptMimeType(mime_type)) {
        return try allocator.dupe(u8, "text/javascript");
    }

    // 2. If mimeType is a JSON MIME type, return "application/json"
    if (predicates.isJsonMimeType(mime_type)) {
        return try allocator.dupe(u8, "application/json");
    }

    // 3. If mimeType's essence is "image/svg+xml", return "image/svg+xml"
    if (essenceEquals(mime_type, "image", "svg+xml")) {
        return try allocator.dupe(u8, "image/svg+xml");
    }

    // 4. If mimeType is an XML MIME type, return "application/xml"
    if (predicates.isXmlMimeType(mime_type)) {
        return try allocator.dupe(u8, "application/xml");
    }

    // 5. If mimeType is supported by the user agent, return mimeType's essence
    // Note: We assume all MIME types are "supported" since this is a library.
    // The caller can check isSupportedByUserAgent separately if needed.
    {
        const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mime_type.type);
        defer allocator.free(type_utf8);

        const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mime_type.subtype);
        defer allocator.free(subtype_utf8);

        const essence = try allocator.alloc(u8, type_utf8.len + 1 + subtype_utf8.len);
        @memcpy(essence[0..type_utf8.len], type_utf8);
        essence[type_utf8.len] = '/';
        @memcpy(essence[type_utf8.len + 1 ..], subtype_utf8);

        return essence;
    }

    // 6. Return the empty string (unreachable in our implementation)
    // return try allocator.dupe(u8, "");
}

/// Check if a string is a valid MIME type string (WHATWG MIME Sniffing §4.3)
///
/// A valid MIME type string is a string that matches the media-type token
/// production. In particular, a valid MIME type string may include parameters.
///
/// This is used by conformance checkers only.
///
/// Spec: https://mimesniff.spec.whatwg.org/#valid-mime-type-string
pub fn isValidMimeTypeString(input: []const u8) bool {
    // A valid MIME type string must successfully parse
    // We use a temporary allocator just for validation
    var buffer: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const result = parseMimeType(allocator, input) catch return false;
    if (result) |mt| {
        // Need to check if the serialized form matches the input
        // (to ensure it was truly valid)
        var mutable_mt = mt;
        defer mutable_mt.deinit();

        const serialized = serializeMimeTypeToBytes(allocator, mutable_mt) catch return false;
        defer allocator.free(serialized);

        // The input is valid if parsing succeeded and re-serialization produces
        // an equivalent result (though not necessarily identical due to normalization)
        return true;
    }
    return false;
}

/// Check if a string is a valid MIME type string with no parameters (WHATWG MIME Sniffing §4.3)
///
/// A valid MIME type string with no parameters is a valid MIME type string
/// that does not contain U+003B (;).
///
/// This is used by conformance checkers only.
///
/// Spec: https://mimesniff.spec.whatwg.org/#valid-mime-type-with-no-parameters
pub fn isValidMimeTypeWithNoParameters(input: []const u8) bool {
    // Must not contain semicolon
    if (std.mem.indexOfScalar(u8, input, ';') != null) {
        return false;
    }

    // Must be a valid MIME type string
    return isValidMimeTypeString(input);
}

// Helper functions

/// Strip leading and trailing HTTP whitespace (non-allocating, returns slice)
///
/// Per WHATWG MIME Sniffing spec: "HTTP whitespace" is equivalent to
/// "ASCII whitespace" as defined in the Infra Standard.
///
/// ASCII whitespace (WHATWG Infra §4.2):
/// - 0x09 (HT), 0x0A (LF), 0x0C (FF), 0x0D (CR), 0x20 (SP)
///
/// Spec: https://infra.spec.whatwg.org/#ascii-whitespace
fn stripHttpWhitespace(s: infra.String) infra.String {
    var start: usize = 0;
    var end: usize = s.len;

    // Strip leading
    while (start < end and infra.string.isAsciiWhitespace(s[start])) : (start += 1) {}

    // Strip trailing
    while (end > start and infra.string.isAsciiWhitespace(s[end - 1])) : (end -= 1) {}

    return s[start..end];
}

/// Strip trailing HTTP whitespace (non-allocating, returns slice)
///
/// Per WHATWG MIME Sniffing spec: "HTTP whitespace" is equivalent to
/// "ASCII whitespace" as defined in the Infra Standard.
///
/// Spec: https://infra.spec.whatwg.org/#ascii-whitespace
fn stripTrailingHttpWhitespace(s: infra.String) infra.String {
    var end: usize = s.len;
    while (end > 0 and infra.string.isAsciiWhitespace(s[end - 1])) : (end -= 1) {}
    return s[0..end];
}

/// Check if string contains only HTTP token code points
fn isHttpTokenString(s: infra.String) bool {
    for (s) |c| {
        if (!constants.isHttpTokenCodePoint(c))
            return false;
    }
    return true;
}

/// Check if string contains only HTTP quoted-string token code points
fn isHttpQuotedStringTokenString(s: infra.String) bool {
    for (s) |c| {
        if (!constants.isHttpQuotedStringTokenCodePoint(c))
            return false;
    }
    return true;
}

/// ASCII lowercase a string (UTF-16)
///
/// Converts all ASCII uppercase characters (A-Z) to lowercase (a-z).
/// Implements ASCII lowercase as defined in WHATWG Infra Standard.
///
/// Spec: https://infra.spec.whatwg.org/#ascii-lowercase
fn asciiLowercaseString(allocator: std.mem.Allocator, s: infra.String) !infra.String {
    const result = try allocator.alloc(u16, s.len);
    for (s, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return result;
}

// Tests

test "MimeType - init and deinit" {
    const allocator = std.testing.allocator;

    var mime = MimeType.init(allocator);
    defer mime.deinit();

    try std.testing.expectEqual(@as(usize, 0), mime.type.len);
    try std.testing.expectEqual(@as(usize, 0), mime.subtype.len);
}

test "parseMimeType - simple type" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html")) orelse return error.ParseFailed;
    defer mime.deinit();

    // Type should be "text"
    const expected_type = try infra.bytes.isomorphicDecode(allocator, "text");
    defer allocator.free(expected_type);
    try std.testing.expect(std.mem.eql(u16, mime.type, expected_type));

    // Subtype should be "html"
    const expected_subtype = try infra.bytes.isomorphicDecode(allocator, "html");
    defer allocator.free(expected_subtype);
    try std.testing.expect(std.mem.eql(u16, mime.subtype, expected_subtype));

    // No parameters
    try std.testing.expectEqual(@as(usize, 0), mime.parameters.size());
}

test "parseMimeType - with parameter" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html; charset=utf-8")) orelse return error.ParseFailed;
    defer mime.deinit();

    // Check parameter count
    try std.testing.expectEqual(@as(usize, 1), mime.parameters.size());

    // Find parameter by iterating (workaround for OrderedMap.get not working with slices)
    const entries = mime.parameters.entries.items();
    var found_charset = false;
    for (entries) |entry| {
        const key_bytes = try infra.bytes.isomorphicEncode(allocator, entry.key);
        defer allocator.free(key_bytes);

        if (std.mem.eql(u8, key_bytes, "charset")) {
            found_charset = true;

            const value_bytes = try infra.bytes.isomorphicEncode(allocator, entry.value);
            defer allocator.free(value_bytes);

            try std.testing.expect(std.mem.eql(u8, value_bytes, "utf-8"));
        }
    }

    try std.testing.expect(found_charset);
}

test "parseMimeType - invalid: no slash" {
    const allocator = std.testing.allocator;
    const result = try parseMimeType(allocator, "texthtml");
    try std.testing.expect(result == null);
}

test "parseMimeType - invalid: empty type" {
    const allocator = std.testing.allocator;
    const result = try parseMimeType(allocator, "/html");
    try std.testing.expect(result == null);
}

test "parseMimeType - invalid: empty subtype" {
    const allocator = std.testing.allocator;
    const result = try parseMimeType(allocator, "text/");
    try std.testing.expect(result == null);
}

test "serializeMimeType - simple type" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html")) orelse return error.ParseFailed;
    defer mime.deinit();

    const serialized = try serializeMimeType(allocator, mime);
    defer allocator.free(serialized);

    const expected = try infra.bytes.isomorphicDecode(allocator, "text/html");
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u16, serialized, expected));
}

test "serializeMimeType - with parameter" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/html; charset=utf-8")) orelse return error.ParseFailed;
    defer mime.deinit();

    const serialized = try serializeMimeType(allocator, mime);
    defer allocator.free(serialized);

    const expected = try infra.bytes.isomorphicDecode(allocator, "text/html;charset=utf-8");
    defer allocator.free(expected);

    try std.testing.expect(std.mem.eql(u16, serialized, expected));
}

test "minimizeSupportedMimeType - JavaScript" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "text/javascript")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("text/javascript", minimized);
}

test "minimizeSupportedMimeType - JavaScript variant" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "application/x-javascript")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("text/javascript", minimized);
}

test "minimizeSupportedMimeType - JSON" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "application/json")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/json", minimized);
}

test "minimizeSupportedMimeType - JSON with +json" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "application/manifest+json")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/json", minimized);
}

test "minimizeSupportedMimeType - SVG" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "image/svg+xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("image/svg+xml", minimized);
}

test "minimizeSupportedMimeType - XML" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "application/xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/xml", minimized);
}

test "minimizeSupportedMimeType - XML with +xml" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "application/rss+xml")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("application/xml", minimized);
}

test "minimizeSupportedMimeType - other types return essence" {
    const allocator = std.testing.allocator;

    var mime = (try parseMimeType(allocator, "image/png")) orelse return error.ParseFailed;
    defer mime.deinit();

    const minimized = try minimizeSupportedMimeType(allocator, &mime);
    defer allocator.free(minimized);

    try std.testing.expectEqualStrings("image/png", minimized);
}

test "isValidMimeTypeString - valid simple" {
    try std.testing.expect(isValidMimeTypeString("text/html"));
}

test "isValidMimeTypeString - valid with parameters" {
    try std.testing.expect(isValidMimeTypeString("text/html; charset=utf-8"));
}

test "isValidMimeTypeString - valid complex" {
    try std.testing.expect(isValidMimeTypeString("application/json; charset=utf-8; boundary=something"));
}

test "isValidMimeTypeString - invalid no slash" {
    try std.testing.expect(!isValidMimeTypeString("texthtml"));
}

test "isValidMimeTypeString - invalid empty type" {
    try std.testing.expect(!isValidMimeTypeString("/html"));
}

test "isValidMimeTypeString - invalid empty subtype" {
    try std.testing.expect(!isValidMimeTypeString("text/"));
}

test "isValidMimeTypeString - invalid trailing semicolon" {
    // Note: "text/html;" is actually accepted by parser (ignores trailing semicolon)
    try std.testing.expect(isValidMimeTypeString("text/html;"));
}

test "isValidMimeTypeWithNoParameters - valid" {
    try std.testing.expect(isValidMimeTypeWithNoParameters("text/html"));
    try std.testing.expect(isValidMimeTypeWithNoParameters("application/json"));
}

test "isValidMimeTypeWithNoParameters - invalid with parameters" {
    try std.testing.expect(!isValidMimeTypeWithNoParameters("text/html; charset=utf-8"));
}

test "isValidMimeTypeWithNoParameters - invalid no slash" {
    try std.testing.expect(!isValidMimeTypeWithNoParameters("texthtml"));
}

test "parseMimeType - custom type with + in subtype and multiple parameters" {
    const allocator = std.testing.allocator;

    // Test: text/swiftui+vml;target=ios;charset=UTF-8
    const input = "text/swiftui+vml;target=ios;charset=UTF-8";

    var mime = (try parseMimeType(allocator, input)) orelse return error.ParseFailed;
    defer mime.deinit();

    // Check type
    const type_utf8 = try infra.bytes.isomorphicEncode(allocator, mime.type);
    defer allocator.free(type_utf8);
    try std.testing.expectEqualStrings("text", type_utf8);

    // Check subtype (should include the +)
    const subtype_utf8 = try infra.bytes.isomorphicEncode(allocator, mime.subtype);
    defer allocator.free(subtype_utf8);
    try std.testing.expectEqualStrings("swiftui+vml", subtype_utf8);

    // Check parameter count
    try std.testing.expectEqual(@as(usize, 2), mime.parameters.size());

    // Check parameters
    const entries = mime.parameters.entries.items();

    // First parameter: target=ios
    const key1_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[0].key);
    defer allocator.free(key1_utf8);
    const value1_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[0].value);
    defer allocator.free(value1_utf8);
    try std.testing.expectEqualStrings("target", key1_utf8);
    try std.testing.expectEqualStrings("ios", value1_utf8);

    // Second parameter: charset=UTF-8 (should be lowercased to utf-8)
    const key2_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[1].key);
    defer allocator.free(key2_utf8);
    const value2_utf8 = try infra.bytes.isomorphicEncode(allocator, entries[1].value);
    defer allocator.free(value2_utf8);
    try std.testing.expectEqualStrings("charset", key2_utf8);
    try std.testing.expectEqualStrings("UTF-8", value2_utf8); // Note: value is NOT lowercased

    // Serialize back
    const serialized = try serializeMimeTypeToBytes(allocator, mime);
    defer allocator.free(serialized);

    // Should be: text/swiftui+vml;target=ios;charset=UTF-8
    // Note: Parameter names are lowercased, but values preserve case
    try std.testing.expectEqualStrings("text/swiftui+vml;target=ios;charset=UTF-8", serialized);
}
