//! Auto-generated mixin: GetSVGDocument
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GetSVGDocumentImpl = @import("impls").GetSVGDocument;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Document = @import("interfaces").Document;

pub const impl = @import("impls").GetSVGDocument;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GetSVGDocument")) {
        if (comptime @hasDecl(impls.GetSVGDocument, "installHooks")) impls.GetSVGDocument.installHooks();
    }
}

pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try GetSVGDocumentImpl.call_getSVGDocument(instance);
}
