//! WebIDL typedef: TrustedScriptURLOrUSVString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("root.zig");

pub const TrustedScriptURLOrUSVString = union(enum) {
    trusted_script_url: *runtime.Instance,
    usvstring: runtime.USVString,
};
