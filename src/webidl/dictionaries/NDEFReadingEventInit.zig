//! WebIDL dictionary: NDEFReadingEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");
const NDEFMessageInit = @import("NDEFMessageInit.zig").NDEFMessageInit;
const EventInit = @import("EventInit.zig").EventInit;

pub const NDEFReadingEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    serialNumber: webidl.Opt(?runtime.DOMString) = .notPassed(),
    message: NDEFMessageInit,
};
