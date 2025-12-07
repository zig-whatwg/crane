//! WebIDL dictionary: SmartCardReaderStateOut
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SmartCardReaderStateFlagsOut = @import("SmartCardReaderStateFlagsOut.zig").SmartCardReaderStateFlagsOut;

pub const SmartCardReaderStateOut = struct {
    readerName: runtime.DOMString,
    eventState: SmartCardReaderStateFlagsOut,
    eventCount: u32,
    answerToReset: ?*const anyopaque = null,
};
