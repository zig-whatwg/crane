//! WebIDL dictionary: SFrameTransformErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const SFrameTransformErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    errorType: enums.SFrameTransformErrorEventType,
    frame: runtime.JSValue,
    keyID: ?typedefs.CryptoKeyID = null,
};
