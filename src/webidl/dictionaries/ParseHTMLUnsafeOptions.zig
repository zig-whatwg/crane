//! WebIDL dictionary: ParseHTMLUnsafeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const ParseHTMLUnsafeOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    sanitizer: ?typedefs.SanitizerOrSanitizerConfigOrSanitizerPresets = null,
};
