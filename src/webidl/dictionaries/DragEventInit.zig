//! WebIDL dictionary: DragEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MouseEventInit = @import("MouseEventInit.zig").MouseEventInit;

pub const DragEventInit = struct {
    // Inherited from MouseEventInit
    base: MouseEventInit,

    dataTransfer: ?anyopaque = null,
};
