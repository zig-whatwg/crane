//! WebIDL dictionary: BasePropertyIndexedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const BasePropertyIndexedKeyframe = struct {
    offset: ?runtime.JSValue = null,
    easing: ?runtime.JSValue = null,
    composite: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"offset"};
};
