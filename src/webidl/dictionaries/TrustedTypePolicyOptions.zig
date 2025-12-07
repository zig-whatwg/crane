//! WebIDL dictionary: TrustedTypePolicyOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const TrustedTypePolicyOptions = struct {
    createHTML: ?callbacks.CreateHTMLCallback = null,
    createScript: ?callbacks.CreateScriptCallback = null,
    createScriptURL: ?callbacks.CreateScriptURLCallback = null,
};
