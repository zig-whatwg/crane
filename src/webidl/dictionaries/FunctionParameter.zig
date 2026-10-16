//! WebIDL dictionary: FunctionParameter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const FunctionParameter = struct {
    name: typedefs.CSSOMString,
    type: typedefs.CSSOMString,
    defaultValue: ?typedefs.CSSOMString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"defaultValue"};
};
