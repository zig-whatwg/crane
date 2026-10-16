//! WebIDL dictionary: JsonLdFramingError
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const JsonLdFramingError = struct {
    code: ?enums.JsonLdFramingErrorCode = null,
    message: ?runtime.USVString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"message"};
};
