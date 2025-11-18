//! WebIDL dictionary: AddEventListenerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventListenerOptions = @import("EventListenerOptions.zig").EventListenerOptions;

pub const AddEventListenerOptions = struct {
    // Inherited from EventListenerOptions
    base: EventListenerOptions,

    passive: ?bool = null,
    once: ?bool = null,
    signal: ?anyopaque = null,
};
