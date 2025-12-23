//! Auto-generated mixin: GetSVGDocument
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GetSVGDocumentImpl = @import("impls").GetSVGDocument;

// Re-export types from impl
pub const impl = @import("impls").GetSVGDocument;

pub fn call_getSVGDocument(instance: *runtime.Instance) !*runtime.Instance {
    return GetSVGDocumentImpl.call_getSVGDocument(instance);
}

