const std = @import("std");
const webidl = @import("webidl");

/// TextEncoderEncodeIntoResult dictionary
///
/// WHATWG Encoding Standard § 5
/// https://encoding.spec.whatwg.org/#dictdef-textencoderencodintoresult
///
/// IDL:
/// ```
/// dictionary TextEncoderEncodeIntoResult {
///   unsigned long long read;
///   unsigned long long written;
/// };
/// ```
///
/// Returns statistics from TextEncoder.encodeInto() operation.
pub const TextEncoderEncodeIntoResult = struct {
    /// Number of UTF-16 code units read from the input string.
    read: webidl.@"unsigned long long",

    /// Number of bytes written to the output Uint8Array.
    written: webidl.@"unsigned long long",
};
