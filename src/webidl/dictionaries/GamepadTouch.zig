//! WebIDL dictionary: GamepadTouch
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const GamepadTouch = struct {
    touchId: ?u32 = null,
    surfaceId: ?u8 = null,
    position: ?*runtime.Instance = null,
    surfaceDimensions: ?*runtime.Instance = null,
};
