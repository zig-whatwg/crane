//! WebIDL typedef: AlgorithmIdentifier
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AlgorithmIdentifier = union(enum) {
    object: runtime.JSValue,
    domstring: runtime.DOMString,
};
