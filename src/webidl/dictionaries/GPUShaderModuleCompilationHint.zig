//! WebIDL dictionary: GPUShaderModuleCompilationHint
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const GPUShaderModuleCompilationHint = struct {
    entryPoint: runtime.USVString,
    layout: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"layout"};
};
