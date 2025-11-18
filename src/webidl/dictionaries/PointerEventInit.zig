//! WebIDL dictionary: PointerEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MouseEventInit = @import("MouseEventInit.zig").MouseEventInit;

pub const PointerEventInit = struct {
    // Inherited from MouseEventInit
    base: MouseEventInit,

    pointerId: ?i32 = null,
    width: ?f64 = null,
    height: ?f64 = null,
    pressure: ?f32 = null,
    tangentialPressure: ?f32 = null,
    tiltX: ?i32 = null,
    tiltY: ?i32 = null,
    twist: ?i32 = null,
    altitudeAngle: ?f64 = null,
    azimuthAngle: ?f64 = null,
    pointerType: ?runtime.DOMString = null,
    isPrimary: ?bool = null,
    persistentDeviceId: ?i32 = null,
    coalescedEvents: ?anyopaque = null,
    predictedEvents: ?anyopaque = null,
};
