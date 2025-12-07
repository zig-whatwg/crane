//! WebIDL dictionary: CompositionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const CompositionEventInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    data: ?runtime.DOMString = null,
};
