//! WebIDL dictionary: DragEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const MouseEventInit = @import("MouseEventInit.zig").MouseEventInit;

pub const DragEventInit = struct {
    // Inherited from MouseEventInit
    base: MouseEventInit,

    dataTransfer: ?*runtime.Instance = null,
};
