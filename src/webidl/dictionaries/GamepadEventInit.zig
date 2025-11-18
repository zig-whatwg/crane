//! WebIDL dictionary: GamepadEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const GamepadEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    gamepad: anyopaque,
};
