//! WebIDL dictionary: SmartCardConnectionStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SmartCardConnectionStatus = struct {
    readerName: runtime.DOMString,
    state: *const anyopaque,
    answerToReset: ?*const anyopaque = null,
};
