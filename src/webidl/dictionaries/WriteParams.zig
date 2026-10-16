//! WebIDL dictionary: WriteParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const WriteParams = struct {
    type: enums.WriteCommandType,
    size: ?u64 = null,
    position: ?u64 = null,
    data: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "size", "position", "data" };
};
