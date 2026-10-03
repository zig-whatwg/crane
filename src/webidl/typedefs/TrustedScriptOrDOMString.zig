//! WebIDL typedef: TrustedScriptOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const TrustedScriptOrDOMString = union(enum) {
    trusted_script: *runtime.Instance,
    domstring: runtime.DOMString,
};
