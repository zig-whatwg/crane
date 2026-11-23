//! WebIDL dictionary: MediaKeyMessageEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const MediaKeyMessageEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from EventInit
    base: EventInit,

    messageType: enums.MediaKeyMessageType,
    message: runtime.JSValue,
};
