//! WebIDL dictionary: FunctionParameter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const FunctionParameter = struct {
    name: typedefs.CSSOMString,
    @"type": typedefs.CSSOMString,
    defaultValue: ?typedefs.CSSOMString = null,
};
