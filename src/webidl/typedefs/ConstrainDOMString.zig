//! WebIDL typedef: ConstrainDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const ConstrainDOMString = union(enum) {
    domstring: runtime.DOMString,
    domstring_sequence: []const runtime.DOMString,
    constrain_domstring_parameters: dictionaries.ConstrainDOMStringParameters,
};
