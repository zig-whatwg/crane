//! WebIDL typedef: ConstrainBooleanOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ConstrainBooleanOrDOMString = union(enum) {
    variant_0: bool,
    variant_1: runtime.DOMString,
    variant_2: *const anyopaque,
};
