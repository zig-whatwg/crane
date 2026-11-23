//! WebIDL dictionary: FunctionParameter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const FunctionParameter = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    name: typedefs.CSSOMString,
    type: typedefs.CSSOMString,
    defaultValue: ?typedefs.CSSOMString = null,
};
