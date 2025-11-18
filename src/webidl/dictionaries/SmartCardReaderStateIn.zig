//! WebIDL dictionary: SmartCardReaderStateIn
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SmartCardReaderStateIn = struct {
    readerName: runtime.DOMString,
    currentState: anyopaque,
    currentCount: ?u32 = null,
};
