//! Format Specifier Parsing
//!
//! WHATWG Console Standard lines 344-351 defines format specifiers
//! for console.log() and other console methods.
//!
//! # Supported Specifiers
//!
//! | Specifier | Purpose | Type Conversion |
//! |-----------|---------|-----------------|
//! | `%s` | String | ECMAScript ToString() |
//! | `%d`, `%i` | Integer | ECMAScript parseInt(value, 10) |
//! | `%f` | Float | ECMAScript parseFloat() |
//! | `%o` | Optimally useful | Implementation-defined formatting |
//! | `%O` | Generic object | Generic JavaScript object formatting |
//! | `%c` | CSS styling | CSS styling (browser-specific) |
//!
//! # Escaping
//!
//! Use `%%` to output a literal `%` character without specifier processing.
//!
//! # Examples
//!
//! ```zig
//! const format = @import("format");
//!
//! // Find all specifiers
//! const str = "Value: %d, Name: %s";
//! var specs = try format.findAllSpecifiers(allocator, str);
//! defer specs.deinit();
//!
//! // specs contains: [{.integer, 7}, {.string, 17}]
//! ```
//!
//! # Browser Compatibility
//!
//! This implementation matches Chrome, Firefox, and Safari console
//! format specifier behavior, ensuring consistent output across platforms.
//!
//! # Performance
//!
//! Specifier scanning is O(n) where n is string length.
//! Uses simple character scanning (could be optimized with SIMD).

const std = @import("std");
const infra = @import("infra");

/// Format specifier types per WHATWG Console Standard.
///
/// Each variant corresponds to a two-character sequence starting with %.
/// The formatter uses these to determine how to convert the next argument.
pub const FormatSpec = enum {
    string, // %s - Convert to string via ToString()
    integer, // %d or %i - Convert to integer via parseInt()
    float, // %f - Convert to float via parseFloat()
    optimal, // %o - Optimally useful formatting (implementation-defined)
    object, // %O - Generic JavaScript object formatting
    css, // %c - CSS formatting (browser-specific)

    /// Parse a format specifier character.
    ///
    /// Returns the corresponding FormatSpec if the character is valid,
    /// null otherwise.
    ///
    /// # Example
    /// ```zig
    /// const spec = FormatSpec.fromChar('s'); // Returns .string
    /// const spec = FormatSpec.fromChar('d'); // Returns .integer
    /// const spec = FormatSpec.fromChar('x'); // Returns null
    /// ```
    pub fn fromChar(c: u8) ?FormatSpec {
        return switch (c) {
            's' => .string,
            'd', 'i' => .integer,
            'f' => .float,
            'o' => .optimal,
            'O' => .object,
            'c' => .css,
            else => null,
        };
    }
};

/// A matched format specifier with its position in the string.
///
/// Used by findAllSpecifiers() to return both the specifier type
/// and where it was found in the source string.
pub const SpecifierMatch = struct {
    /// The type of format specifier found.
    spec: FormatSpec,

    /// Position of the % character in the string (0-indexed).
    index: usize,
};

/// Find all format specifiers in a string.
///
/// Scans the string from left to right, identifying all valid format
/// specifiers (%s, %d, %i, %f, %o, %O, %c) and their positions.
///
/// Handles escaped percent signs (%%) correctly - they are skipped
/// and not treated as format specifiers.
///
/// # Returns
///
/// A list of SpecifierMatch structs, each containing:
/// - `spec`: The type of specifier found
/// - `index`: Position of the % character
///
/// The list is in left-to-right order (same order as in string).
///
/// # Memory
///
/// Caller owns the returned list and must call deinit().
///
/// # Example
///
/// ```zig
/// const str = "Hello %s, you have %d messages";
/// var specs = try findAllSpecifiers(allocator, str);
/// defer specs.deinit();
///
/// // specs[0] = {.string, 6}
/// // specs[1] = {.integer, 21}
/// ```
///
/// # Performance
///
/// O(n) where n is the length of the string.
/// Single pass through the string.
pub fn findAllSpecifiers(allocator: std.mem.Allocator, str: []const u8) !infra.List(SpecifierMatch) {
    var results = infra.List(SpecifierMatch).init(allocator);
    errdefer results.deinit();

    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (str[i] == '%') {
            // Check if there's a next character
            if (i + 1 < str.len) {
                const next_char = str[i + 1];

                // Check for %% (escaped percent)
                if (next_char == '%') {
                    i += 1; // Skip the escaped %
                    continue;
                }

                // Try to match format specifier
                if (FormatSpec.fromChar(next_char)) |spec| {
                    try results.append(.{
                        .spec = spec,
                        .index = i,
                    });
                }
            }
        }
    }

    return results;
}
