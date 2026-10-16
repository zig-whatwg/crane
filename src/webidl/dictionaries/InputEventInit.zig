//! WebIDL dictionary: InputEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const UIEventInit = @import("UIEventInit.zig").UIEventInit;

pub const InputEventInit = struct {
    // Inherited from UIEventInit
    base: UIEventInit,

    data: ?runtime.DOMString = null,
    isComposing: ?bool = null,
    inputType: ?runtime.DOMString = null,
    dataTransfer: ?*runtime.Instance = null,
    targetRanges: ?[]const *runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "data", "dataTransfer" };
};
