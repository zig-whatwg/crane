//! WebIDL dictionary: AnimationPlaybackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const AnimationPlaybackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    currentTime: ?anyopaque = null,
    timelineTime: ?anyopaque = null,
};
