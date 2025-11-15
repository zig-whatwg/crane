const std = @import("std");
const webidl = @import("webidl");

/// TextDecoderCommon interface mixin
///
/// WHATWG Encoding Standard § 5.1.1
/// https://encoding.spec.whatwg.org/#interface-mixin-textdecodercommon
///
/// IDL:
/// ```
/// interface mixin TextDecoderCommon {
///   readonly attribute DOMString encoding;
///   readonly attribute boolean fatal;
///   readonly attribute boolean ignoreBOM;
/// };
/// ```
///
/// This mixin defines the readonly attributes that are shared by TextDecoder
/// and TextDecoderStream interfaces. These attributes describe the decoder's
/// configuration and cannot be changed after construction.
///
/// ## Attributes
///
/// - `encoding`: The name of the encoding (lowercase ASCII, e.g., "utf-8", "windows-1252")
/// - `fatal`: If true, throw on decoding errors; if false, use replacement character (U+FFFD)
/// - `ignoreBOM`: If true, don't strip byte order mark (BOM); if false, strip BOM from output
///
/// ## Usage
///
/// This mixin is included by TextDecoder and TextDecoderStream:
/// ```
/// TextDecoder includes TextDecoderCommon;
/// TextDecoderStream includes TextDecoderCommon;
/// ```
///
/// The including interfaces must provide these readonly fields.
pub const TextDecoderCommon = webidl.mixin(struct {
    /// The encoding name (WHATWG canonical name, lowercase ASCII)
    ///
    /// Examples: "utf-8", "windows-1252", "iso-8859-1"
    ///
    /// This is a readonly attribute - set during construction and never changes.
    encoding: []const u8,

    /// Fatal error mode flag
    ///
    /// - `true`: Throw TypeError on invalid byte sequences
    /// - `false`: Use U+FFFD replacement character (default)
    ///
    /// This is a readonly attribute - set during construction and never changes.
    fatal: webidl.boolean,

    /// Byte Order Mark (BOM) handling flag
    ///
    /// - `true`: Keep BOM in output as U+FEFF (ZERO WIDTH NO-BREAK SPACE)
    /// - `false`: Strip BOM from output (default)
    ///
    /// This is a readonly attribute - set during construction and never changes.
    ignoreBOM: webidl.boolean,

    /// Get the encoding name
    /// WebIDL readonly attribute: encoding
    pub fn get_encoding(self: *const @This()) []const u8 {
        return self.encoding;
    }

    /// Get the fatal error mode flag
    /// WebIDL readonly attribute: fatal
    pub fn get_fatal(self: *const @This()) bool {
        return self.fatal;
    }

    /// Get the BOM handling flag
    /// WebIDL readonly attribute: ignoreBOM
    pub fn get_ignoreBOM(self: *const @This()) bool {
        return self.ignoreBOM;
    }
});
