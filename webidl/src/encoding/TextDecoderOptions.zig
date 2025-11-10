const std = @import("std");
const webidl = @import("webidl");

/// TextDecoderOptions dictionary
///
/// WHATWG Encoding Standard § 5.1.2
/// https://encoding.spec.whatwg.org/#dictdef-textdecoderoptions
///
/// Configuration options for TextDecoder constructor.
///
/// ## Fields
///
/// ### fatal
/// Error handling mode for invalid byte sequences:
/// - `false` (default): Replace invalid sequences with U+FFFD REPLACEMENT CHARACTER
/// - `true`: Throw `error.DecodingError` (maps to WebIDL TypeError) on invalid sequences
///
/// ### ignoreBOM
/// Byte order mark (BOM) handling:
/// - `false` (default): Strip BOM from decoded output
///   - UTF-8 BOM: EF BB BF (U+FEFF)
///   - UTF-16BE BOM: FE FF
///   - UTF-16LE BOM: FF FE
/// - `true`: Keep BOM in output (as U+FEFF ZERO WIDTH NO-BREAK SPACE)
///
/// ## Examples
///
/// ### Default Options
/// ```zig
/// // Non-fatal, strip BOM
/// const opts: TextDecoderOptions = .{};
/// var decoder = try TextDecoder.init(allocator, "utf-8", opts);
/// ```
///
/// ### Fatal Mode
/// ```zig
/// // Throw on invalid sequences
/// const opts: TextDecoderOptions = .{ .fatal = true };
/// var decoder = try TextDecoder.init(allocator, "utf-8", opts);
/// // decode() will return error.DecodingError for invalid input
/// ```
///
/// ### Keep BOM
/// ```zig
/// // Don't strip BOM
/// const opts: TextDecoderOptions = .{ .ignoreBOM = true };
/// var decoder = try TextDecoder.init(allocator, "utf-8", opts);
/// // BOM (U+FEFF) will appear in decoded output
/// ```
///
/// ### Both Options
/// ```zig
/// // Fatal mode + keep BOM
/// const opts: TextDecoderOptions = .{
///     .fatal = true,
///     .ignoreBOM = true,
/// };
/// var decoder = try TextDecoder.init(allocator, "utf-8", opts);
/// ```
///
/// ## WebIDL Spec
///
/// IDL:
/// ```
/// dictionary TextDecoderOptions {
///   boolean fatal = false;
///   boolean ignoreBOM = false;
/// };
/// ```
///
/// ## See Also
///
/// - `TextDecoder` - Uses these options in constructor
/// - `TextDecodeOptions` - Options for decode() method
pub const TextDecoderOptions = struct {
    /// If true, throw a TypeError for decoding errors.
    /// If false (default), substitute with U+FFFD REPLACEMENT CHARACTER.
    fatal: webidl.boolean = false,

    /// If true, ignore byte order mark if present in stream.
    /// If false (default), strip BOM from output.
    ignoreBOM: webidl.boolean = false,
};
