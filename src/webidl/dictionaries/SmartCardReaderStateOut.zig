//! WebIDL dictionary: SmartCardReaderStateOut
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SmartCardReaderStateOut = struct {
    readerName: runtime.DOMString,
    eventState: *const anyopaque,
    eventCount: u32,
    answerToReset: ?*const anyopaque = null,
};
