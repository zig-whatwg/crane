//! WebIDL typedef: TrustedType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const TrustedType = union(enum) {
    trusted_html: *runtime.Instance,
    trusted_script: *runtime.Instance,
    trusted_script_url: *runtime.Instance,
};
