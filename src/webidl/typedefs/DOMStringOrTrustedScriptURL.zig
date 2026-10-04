//! WebIDL typedef: DOMStringOrTrustedScriptURL
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const DOMStringOrTrustedScriptURL = union(enum) {
    domstring: runtime.DOMString,
    trusted_script_url: *runtime.Instance,
};
