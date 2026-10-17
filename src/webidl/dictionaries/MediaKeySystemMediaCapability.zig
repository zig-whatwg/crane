//! WebIDL dictionary: MediaKeySystemMediaCapability
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaKeySystemMediaCapability = struct {
    contentType: ?runtime.DOMString = null,
    encryptionScheme: ?runtime.DOMString = null,
    robustness: ?runtime.DOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"encryptionScheme"};
};
