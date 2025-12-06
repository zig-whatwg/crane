//! WebIDL typedef: SanitizerAttribute
//!
//! This file is AUTO-GENERATED. Do not edit manually.
//! NOTE: Dictionary types use *runtime.Instance to avoid circular imports

const runtime = @import("runtime");

pub const SanitizerAttribute = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_attribute_namespace: *runtime.Instance,
};
