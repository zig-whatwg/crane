//! WebIDL dictionary: DragEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MouseEventInit = @import("MouseEventInit.zig").MouseEventInit;

pub const DragEventInit = struct {
    // Inherited from MouseEventInit
    base: MouseEventInit,

    dataTransfer: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"dataTransfer"};
};
