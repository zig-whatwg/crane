//! WebIDL typedef: TrustedTypeOrDOMString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const TrustedTypeOrDOMString = union(enum) {
    trusted_html: *runtime.Instance,
    trusted_script: *runtime.Instance,
    trusted_script_url: *runtime.Instance,
    domstring: runtime.DOMString,
};
