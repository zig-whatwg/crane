//! WebIDL typedef: SanitizerElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const SanitizerElement = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_element_namespace: *runtime.Instance,
};
