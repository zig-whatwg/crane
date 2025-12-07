//! WebIDL dictionary: AnimationPlaybackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const AnimationPlaybackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    currentTime: ?typedefs.CSSNumberish = null,
    timelineTime: ?typedefs.CSSNumberish = null,
};
