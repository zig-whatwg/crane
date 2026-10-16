//! WebIDL dictionary: PointerTimelineOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const PointerTimelineOptions = struct {
    source: ?*runtime.Instance = null,
    axis: ?enums.PointerAxis = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"source"};
};
