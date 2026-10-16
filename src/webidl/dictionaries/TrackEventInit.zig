//! WebIDL dictionary: TrackEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const TrackEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    track: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"track"};
};
