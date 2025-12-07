//! WebIDL dictionary: SFrameTransformErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const SFrameTransformErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    errorType: enums.SFrameTransformErrorEventType,
    frame: v8.JSValue,
    keyID: ?typedefs.CryptoKeyID = null,
};
