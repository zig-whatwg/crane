//! WebIDL typedef: SanitizerElementWithAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const SanitizerElementWithAttributes = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_element_namespace_with_attributes: *runtime.Instance,
};
