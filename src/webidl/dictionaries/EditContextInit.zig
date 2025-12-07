//! WebIDL dictionary: EditContextInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const EditContextInit = struct {
    text: ?runtime.DOMString = null,
    selectionStart: ?u32 = null,
    selectionEnd: ?u32 = null,
};
