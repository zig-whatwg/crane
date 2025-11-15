const std = @import("std");
const webidl = @import("webidl");

/// TextEncoderCommon interface mixin
///
/// WHATWG Encoding Standard § 5.2.1
/// https://encoding.spec.whatwg.org/#interface-mixin-textencodercommon
///
/// IDL:
/// ```
/// interface mixin TextEncoderCommon {
///   readonly attribute DOMString encoding;
/// };
/// ```
///
/// This mixin defines the readonly attribute that is shared by TextEncoder
/// and TextEncoderStream interfaces. It provides access to the encoding name,
/// which is always "utf-8" for these encoders.
///
/// ## Attributes
///
/// - `encoding`: The name of the encoding (always "utf-8" for TextEncoder/TextEncoderStream)
///
/// ## Usage
///
/// This mixin is included by TextEncoder and TextEncoderStream:
/// ```
/// TextEncoder includes TextEncoderCommon;
/// TextEncoderStream includes TextEncoderCommon;
/// ```
///
/// The including interfaces must provide this readonly field.
pub const TextEncoderCommon = webidl.mixin(struct {
    /// The encoding name (always "utf-8")
    ///
    /// TextEncoder and TextEncoderStream only support UTF-8 encoding,
    /// so this attribute always returns "utf-8".
    ///
    /// This is a readonly attribute - set during construction and never changes.
    encoding: []const u8,

    /// Get the encoding name
    /// WebIDL readonly attribute: encoding
    pub fn get_encoding(self: *const @This()) []const u8 {
        return self.encoding;
    }
});
