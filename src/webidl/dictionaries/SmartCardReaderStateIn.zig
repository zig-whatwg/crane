//! WebIDL dictionary: SmartCardReaderStateIn
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const SmartCardReaderStateFlagsIn = @import("SmartCardReaderStateFlagsIn.zig").SmartCardReaderStateFlagsIn;

pub const SmartCardReaderStateIn = struct {
    readerName: runtime.DOMString,
    currentState: SmartCardReaderStateFlagsIn,
    currentCount: ?u32 = null,
};
