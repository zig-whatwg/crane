//! WebIDL typedef: SanitizerPI
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const SanitizerPI = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_processing_instruction: dictionaries.SanitizerProcessingInstruction,
};
