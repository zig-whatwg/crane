const std = @import("std");
const webidl = @import("webidl");

/// TextEncoderEncodeIntoResult dictionary
///
/// WHATWG Encoding Standard § 5.2.3
/// https://encoding.spec.whatwg.org/#dictdef-textencoderencodintoresult
///
/// Statistics returned by TextEncoder.encodeInto() operation.
///
/// ## Fields
///
/// ### read
/// Number of code units read from the source string:
/// - **Zig implementation**: UTF-8 bytes read
/// - **JavaScript bindings**: UTF-16 code units read
/// - Indicates how much of the source was consumed
///
/// ### written
/// Number of bytes written to the destination buffer:
/// - Always UTF-8 bytes
/// - May be less than source length (multibyte encoding, truncation)
/// - Indicates valid data in destination[0..written]
///
/// ## Usage
///
/// ### Basic Usage
/// ```zig
/// var encoder = TextEncoder.init(allocator);
/// var buffer: [100]u8 = undefined;
///
/// const result = try encoder.call_encodeInto("Hello", &buffer);
/// // result.read = 5 (UTF-8 bytes)
/// // result.written = 5 (bytes written)
/// // buffer[0..5] = "Hello"
/// ```
///
/// ### Handling Truncation
/// ```zig
/// var buffer: [5]u8 = undefined;
/// const result = try encoder.call_encodeInto("Hello, World!", &buffer);
/// // result.read = 5 (only "Hello" read)
/// // result.written = 5 (only 5 bytes written)
/// // buffer[0..5] = "Hello"
/// // Can resume: source[result.read..]
/// ```
///
/// ### Multibyte Characters
/// ```zig
/// var buffer: [10]u8 = undefined;
/// const result = try encoder.call_encodeInto("Hi🌍", &buffer);
/// // "Hi" = 2 bytes, "🌍" = 4 bytes, total = 6 bytes
/// // result.read = 6 (UTF-8 bytes)
/// // result.written = 6 (bytes written)
/// // buffer[0..6] = "Hi🌍"
/// ```
///
/// ### Character Boundary Handling
/// ```zig
/// var buffer: [3]u8 = undefined;
/// const result = try encoder.call_encodeInto("Hi🌍", &buffer);
/// // Emoji doesn't fit (4 bytes), stopped before it
/// // result.read = 2 ("Hi" only)
/// // result.written = 2
/// // buffer[0..2] = "Hi"
/// // No partial characters written
/// ```
///
/// ### Resuming After Partial Encode
/// ```zig
/// const text = "Hello, World!";
/// var buffer: [5]u8 = undefined;
/// var offset: usize = 0;
///
/// while (offset < text.len) {
///     const remaining = text[offset..];
///     const result = try encoder.call_encodeInto(remaining, &buffer);
///
///     // Process buffer[0..result.written]
///     // ...
///
///     offset += result.read; // Advance offset
/// }
/// ```
///
/// ## JavaScript Binding Notes
///
/// For JavaScript bindings, `read` should be converted to UTF-16 code units:
/// - ASCII characters: 1 code unit
/// - Multibyte characters: May be 1-2 code units (depending on surrogate pairs)
///
/// ## WebIDL Spec
///
/// IDL:
/// ```
/// dictionary TextEncoderEncodeIntoResult {
///   unsigned long long read;
///   unsigned long long written;
/// };
/// ```
///
/// ## See Also
///
/// - `TextEncoder.call_encodeInto()` - Returns this type
/// - `TextEncoder.call_encode()` - Alternative that allocates
pub const TextEncoderEncodeIntoResult = struct {
    /// Number of UTF-16 code units (JS) or UTF-8 bytes (Zig) read from the input string.
    read: webidl.@"unsigned long long",

    /// Number of bytes written to the output Uint8Array.
    written: webidl.@"unsigned long long",
};
