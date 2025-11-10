const std = @import("std");
const webidl = @import("webidl");

/// TextDecodeOptions dictionary
///
/// WHATWG Encoding Standard § 5
/// https://encoding.spec.whatwg.org/#dictdef-textdecodeoptions
///
/// IDL:
/// ```
/// dictionary TextDecodeOptions {
///   boolean stream = false;
/// };
/// ```
///
/// Used by TextDecoder.decode() to control streaming behavior.
pub const TextDecodeOptions = struct {
    /// If true, additional data is expected in subsequent calls.
    /// If false (default), end-of-queue will be pushed to the stream.
    stream: webidl.boolean = false,
};
