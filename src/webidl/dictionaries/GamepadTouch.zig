//! WebIDL dictionary: GamepadTouch
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GamepadTouch = struct {
    touchId: ?u32 = null,
    surfaceId: ?u8 = null,
    position: ?*runtime.Instance = null,
    surfaceDimensions: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"surfaceDimensions"};
};
