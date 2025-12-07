//! WebIDL dictionary: SmartCardConnectionStatus
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const SmartCardConnectionStatus = struct {
    readerName: runtime.DOMString,
    state: enums.SmartCardConnectionState,
    answerToReset: ?*const anyopaque = null,
};
