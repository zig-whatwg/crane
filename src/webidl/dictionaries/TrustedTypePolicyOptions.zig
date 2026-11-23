//! WebIDL dictionary: TrustedTypePolicyOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const TrustedTypePolicyOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    createHTML: ?callbacks.CreateHTMLCallback = null,
    createScript: ?callbacks.CreateScriptCallback = null,
    createScriptURL: ?callbacks.CreateScriptURLCallback = null,
    createParserOptions: ?callbacks.CreateParserOptionsCallback = null,
};
