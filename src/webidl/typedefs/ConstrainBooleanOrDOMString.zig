//! WebIDL typedef: ConstrainBooleanOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ConstrainBooleanOrDOMString = union(enum) {
    boolean: bool,
    domstring: runtime.DOMString,
    constrain_boolean_or_domstring_parameters: dictionaries.ConstrainBooleanOrDOMStringParameters,
};
