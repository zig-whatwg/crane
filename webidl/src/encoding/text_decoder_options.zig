const std = @import("std");
const webidl = @import("webidl");

/// TextDecoderOptions dictionary
///
/// WHATWG Encoding Standard § 5
/// https://encoding.spec.whatwg.org/#dictdef-textdecoderoptions
///
/// IDL:
/// ```
/// dictionary TextDecoderOptions {
///   boolean fatal = false;
///   boolean ignoreBOM = false;
/// };
/// ```
///
/// Used by TextDecoder constructor to configure error handling and BOM behavior.
pub const TextDecoderOptions = struct {
    /// If true, throw a TypeError for decoding errors.
    /// If false (default), substitute with U+FFFD REPLACEMENT CHARACTER.
    fatal: webidl.boolean = false,

    /// If true, ignore byte order mark if present in stream.
    /// If false (default), strip BOM from output.
    ignoreBOM: webidl.boolean = false,
};
